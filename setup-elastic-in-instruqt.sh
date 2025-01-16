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

export $(cat /root/.env | xargs)
BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)
echo "updating settings"


export ELASTICSEARCH_USER=elastic
export KIBANA_URL=http://localhost:30002
export FLEET_URL=https://localhost:30822
export PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n default -o go-template='{{.data.elastic | base64decode}}')


curl -s -X POST --header "Authorization: Basic $BASE64" "$ELASTICSEARCH_URL/_license/start_trial?acknowledge=true"

sleep 15

cd resources
pip3 install -r requirements.txt
python3 ${DEMO_TYPE}.py
