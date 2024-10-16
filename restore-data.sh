#!/bin/bash

# Load environment variables
source /root/.env
source /home/env/.env

# Set up authentication
BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)

# Function to make API calls
call_api() {
    curl -s -X $1 "$ELASTICSEARCH_URL$2" \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $BASE64" \
        ${4:+-d "$4"}
}

# Download saved object file from S3
echo "Downloading saved object file from S3..."
aws s3 cp s3://your-bucket/saved-objects.ndjson ./saved-objects.ndjson

# Add S3 access and secret keys to Elasticsearch keystore
echo "Adding S3 keys to Elasticsearch keystore..."
echo "YOUR_S3_ACCESS_KEY" | /usr/share/elasticsearch/bin/elasticsearch-keystore add --stdin s3.client.default.access_key
echo "YOUR_S3_SECRET_KEY" | /usr/share/elasticsearch/bin/elasticsearch-keystore add --stdin s3.client.default.secret_key

# Reload secure settings
echo "Reloading secure settings..."
call_api POST "/_nodes/reload_secure_settings"

# Create snapshot repository
echo "Creating snapshot repository..."
repo_config='{
  "type": "s3",
  "settings": {
    "bucket": "your-s3-bucket",
    "base_path": "elasticsearch-snapshots",
    "client": "default"
  }
}'
call_api PUT "/_snapshot/my_s3_repository" "" "$repo_config"

# Download snapshot from S3 (if needed)
echo "Downloading snapshot from S3..."
# Uncomment the next line if you need to download the snapshot file
# aws s3 cp s3://your-bucket/your-snapshot.zip ./snapshot.zip

# Restore snapshot
echo "Restoring snapshot..."
call_api POST "/_snapshot/my_s3_repository/my_snapshot/_restore" \
    -d '{"indices": ["*"], "include_global_state": true}'

# Restore saved object file
echo "Restoring saved object file..."
curl -X POST "$KIBANA_URL/api/saved_objects/_import" \
    -H "kbn-xsrf: true" \
    -H "Authorization: Basic $BASE64" \
    --form file=@./saved-objects.ndjson

# Install Nginx and MySQL plugins
echo "Installing Nginx plugin..."
call_api POST "/_plugins/_integrations/packages/nginx/install"

echo "Installing MySQL plugin..."
call_api POST "/_plugins/_integrations/packages/mysql/install"

# Download and run Java app
echo "Downloading and running Java app..."
wget -O app.jar https://example.com/your-java-app.jar
nohup java -jar app.jar > app.log 2>&1 &

# Edit pipeline
echo "Editing pipeline 'logs-nginx.access-*'..."
pipeline_script='
{
  "description" : "Update pipeline for logs-nginx.access-*",
  "processors" : [
    {
      "script": {
        "lang": "painless",
        "source": "
          ctx.debug = [];

          if (ctx.url?.query == null) {
              ctx.debug.add(\"Query is null\");
              ctx.revenue = 0.0;
              return;
          }

          String query = ctx.url.query;
          ctx.debug.add(\"Query: \" + query);

          double amount = 0.0;
          def amountPattern = /amount=([^&]+)/;
          def matcher = amountPattern.matcher(query);
          if (matcher.find()) {
              try {
                  amount = Double.parseDouble(matcher.group(1));
                  ctx.debug.add(\"Parsed amount: \" + amount);
              } catch (Exception e) {
                  ctx.debug.add(\"Failed to parse amount: \" + e.getMessage());
                  amount = 0.0;
              }
          } else {
              ctx.debug.add(\"No amount found in query\");
          }

          boolean is500Error = ctx.http?.response?.status_code == 500;
          ctx.debug.add(\"Is 500 error: \" + is500Error);

          double revenue = is500Error ? -amount : amount;
          ctx.debug.add(\"Calculated revenue: \" + revenue);

          // Set the revenue field
          ctx.revenue = revenue;
          ctx.debug.add(\"Set revenue field to: \" + ctx.revenue);
        "
      }
    }
  ]
}'

call_api PUT "/_ingest/pipeline/logs-nginx.access-*" "" "$pipeline_script"

echo "Setup complete!"
