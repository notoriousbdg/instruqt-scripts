#!/bin/bash 

source /root/.env

DEMO_TYPE=${1:-nginx_demo}  # Default to nginx if no argument provided
echo "Setting up demo type: $DEMO_TYPE" >> log.txt


# finish elastic install (this needs to be done here because _SANDBOX_ID is not available outside of the setup script)
export _SANDBOX_ID=$_SANDBOX_ID
/usr/local/bin/elastic-start.sh

# setup openai (this needs to be done here because secrets are not available outside of the setup script)
export LLM_PROXY_PROD=$LLM_PROXY_PROD
export ELASTICSEARCH_PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n default -o go-template='{{.data.elastic | base64decode}}')

export $(cat /root/.env | xargs)
BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)

output=$(curl 'https://llm-proxy.prod-3.eden.elastic.dev/key/generate' \
--header 'Authorization: Bearer '"$LLM_PROXY_PROD"'' \
--header 'Content-Type: application/json' \
--data-raw '{"models": ["gpt-4"],"duration": "7d", "metadata": {"user": "instruqt-observe-ml-'"$_SANDBOX_ID"'"}}')

key=$(echo $output | jq -r '.key')

echo "OPENAI_API_KEY=$key" >> /root/.env

export $(cat /root/.env | xargs)
BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)
echo "updating settings"

cat > settings.json << EOF
{
   "attributes":{
      "buildNum":70088,
      "defaultIndex":"dccd1810-2016-11eb-8016-cf9f9e5961e9",
      "isDefaultIndexMigrated":true,
      "notifications:banner":null,
      "notifications:lifetime:banner":null,
      "timepicker:quickRanges":"[\n{\n    \"from\": \"2022-06-07T08:20:00+02:00\",\n    \"to\": \"2022-06-07T10:00:00+02:00\",\n    \"display\": \"Database\"\n  },\n    {\n    \"from\": \"now/d\",\n    \"to\": \"now/d\",\n    \"display\": \"Today\"\n  },\n  {\n    \"from\": \"now/w\",\n    \"to\": \"now/w\",\n    \"display\": \"This week\"\n  },\n  {\n    \"from\": \"now-15m\",\n    \"to\": \"now\",\n    \"display\": \"Last 15 minutes\"\n  },\n  {\n    \"from\": \"now-30m\",\n    \"to\": \"now\",\n    \"display\": \"Last 30 minutes\"\n  },\n  {\n    \"from\": \"now-1h\",\n    \"to\": \"now\",\n    \"display\": \"Last 1 hour\"\n  },\n  {\n    \"from\": \"now-24h/h\",\n    \"to\": \"now\",\n    \"display\": \"Last 24 hours\"\n  },\n  {\n    \"from\": \"now-7d/d\",\n    \"to\": \"now\",\n    \"display\": \"Last 7 days\"\n  },\n  {\n    \"from\": \"now-30d/d\",\n    \"to\": \"now\",\n    \"display\": \"Last 30 days\"\n  },\n  {\n    \"from\": \"now-90d/d\",\n    \"to\": \"now\",\n    \"display\": \"Last 90 days\"\n  },\n  {\n    \"from\": \"now-1y/d\",\n    \"to\": \"now\",\n    \"display\": \"Last 1 year\"\n  }\n]"
   },
   "coreMigrationVersion":"8.8.0",
   "created_at":"2024-01-17T15:00:18.968Z",
   "id":"8.12.0",
   "managed":false,
   "references":[
   ],
   "type":"config",
   "typeMigrationVersion":"8.9.0",
   "updated_at":"2024-01-17T15:00:18.968Z",
   "version":"Wzg3NDUyMyw4XQ=="
}
EOF
cat settings.json | jq -c > settings.ndjson

mkdir /home/env/

export $(cat /root/.env | xargs)
# write OPENAI_API_KEY to .env
echo "OPENAI_API_KEY=$OPENAI_API_KEY" >> /home/env/.env

# remove OPENAI_API_KEY from .env
sed -i '/OPENAI_API_KEY/d' /root/.env

curl -s -X POST --header "Authorization: Basic $BASE64"  -H "kbn-xsrf: true" \
"http://localhost:30002/api/saved_objects/_import?overwrite=true" --form file=@settings.ndjson

export ELASTICSEARCH_USER=elastic
export KIBANA_URL=http://localhost:30002
export FLEET_URL=https://localhost:30822
export PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n default -o go-template='{{.data.elastic | base64decode}}')


curl -s -X POST --header "Authorization: Basic $BASE64" "$ELASTICSEARCH_URL/_license/start_trial?acknowledge=true"

sleep 15

cd resources
pip3 install -r requirements.txt
python3 ${DEMO_TYPE}.py
