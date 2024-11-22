import requests
import os
from datetime import datetime

TIMEOUT = 360
ASSISTANT_RESOURCES_PATH = 'assistant'

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open('log.txt', 'a') as f:
        f.write(f"[{timestamp}] {message}\n")

def load():
    log_message("Starting assistant load process")

    if 'LLM_PROXY_PROD' in os.environ:
        log_message("LLM_PROXY_PROD found in environment variables")
        # Get API key from LLM proxy
        headers = {
            'Authorization': f'Bearer {os.environ["LLM_PROXY_PROD"]}',
            'Content-Type': 'application/json'
        }
        
        try:
            proxy_response = requests.post(
                'https://llm-proxy.prod-3.eden.elastic.dev/key/generate',
                headers=headers,
                json={
                    'models': ['gpt-4o'],
                    'duration': '7d',
                    'metadata': {'user': f'instruqt-observe-ml-{os.environ.get("_SANDBOX_ID", "")}'}
                },
                timeout=TIMEOUT
            )
            log_message(f"Proxy response status: {proxy_response.status_code}")
            api_key = proxy_response.json()['key']
            log_message("Successfully obtained API key")

            # Create connector
            connector_data = {
                'name': 'openai-connector',
                'config': {
                    'apiProvider': 'Azure OpenAI',
                    'apiUrl': 'https://llm-proxy.prod-3.eden.elastic.dev/v1/chat/completions?model=gpt-4'
                },
                'secrets': {
                    'apiKey': api_key
                },
                'connector_type_id': '.gen-ai'
            }

            resp = requests.post(
                f"{os.environ['KIBANA_URL']}/api/actions/connector",
                json=connector_data,
                timeout=TIMEOUT,
                auth=(os.environ['ELASTICSEARCH_USER'], os.environ['ELASTICSEARCH_PASSWORD']),
                headers={'kbn-xsrf': 'true', 'Content-Type': 'application/json'}
            )
            log_message(f"Connector creation response status: {resp.status_code}")

            kb_resp = requests.post(
                f"{os.environ['KIBANA_URL']}/internal/observability_ai_assistant/kb/setup",
                timeout=TIMEOUT,
                auth=(os.environ['ELASTICSEARCH_USER'], os.environ['ELASTICSEARCH_PASSWORD']),
                headers={'kbn-xsrf': 'true', 'X-Elastic-Internal-Origin': 'Kibana', 'Content-Type': 'application/json'}
            )
            log_message(f"KB setup response status: {kb_resp.status_code}")

        except Exception as e:
            log_message(f"Error occurred: {str(e)}")
            raise
    else:
        log_message("LLM_PROXY_PROD not found in environment variables")

def load_elser():
    body = {
        "service": "elser",
        "service_settings": {
            "num_allocations": 1,
            "num_threads": 1
        }
    }
    resp = requests.put(f"{os.environ['ELASTICSEARCH_URL']}/_inference/sparse_embedding/elser_model_2",
                            json=body, timeout=TIMEOUT,
                            auth=(os.environ['ELASTICSEARCH_USER'], os.environ['ELASTICSEARCH_PASSWORD']), 
                            headers={"kbn-xsrf": "reporting", "Content-Type": "application/json"})
    print(resp.json())  


    sync_resp = requests.get(
        f"{os.environ['KIBANA_URL']}/api/ml/saved_objects/sync",
        timeout=TIMEOUT,
        auth=(
            os.environ['ELASTICSEARCH_USER'],
            os.environ['ELASTICSEARCH_PASSWORD']
        ),
        headers={"kbn-xsrf": "reporting"}
    )
    print(sync_resp.json())

if __name__ == "__main__":
    load()
