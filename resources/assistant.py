import requests
import os

TIMEOUT = 180

ASSISTANT_RESOURCES_PATH  = 'assistant'

def load():
    print(os.environ["LLM_PROXY_PROD"])

    if 'LLM_PROXY_PROD' in os.environ:
        # Get API key from LLM proxy
        headers = {
            'Authorization': f'Bearer {os.environ["LLM_PROXY_PROD"]}',
            'Content-Type': 'application/json'
        }
        proxy_response = requests.post(
            'https://llm-proxy.prod-3.eden.elastic.dev/key/generate',
            headers=headers,
            json={
                'models': ['gpt-4'],
                'duration': '7d',
                'metadata': {'user': f'instruqt-observe-ml-{os.environ.get("_SANDBOX_ID", "")}'}
            },
            timeout=TIMEOUT
        )
        api_key = proxy_response.json()['key']

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
        print(resp.json())

        # Setup KB for O11y Assistant
        kb_resp = requests.post(
            f"{os.environ['KIBANA_URL']}/internal/observability_ai_assistant/kb/setup",
            timeout=TIMEOUT,
            auth=(os.environ['ELASTICSEARCH_USER'], os.environ['ELASTICSEARCH_PASSWORD']),
            headers={'kbn-xsrf': 'true', 'X-Elastic-Internal-Origin': 'Kibana', 'Content-Type': 'application/json'}
        )
        print(kb_resp.json())

if __name__ == "__main__":
    load()
