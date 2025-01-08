from flask import Flask

import context
import assistant
import kubernetes_flow
import subprocess  # Import subprocess to run shell commands
import yaml

app = Flask(__name__)

def init():
    assistant.load()
    kubernetes_flow.main()

def deploy_three_tiered_java():
    """
    Deploys the Java favorite application using kubectl.
    """
    import os

    # Paths to your YAML files
    deployment_file = 'three-tier-java-app/deployment.yaml'
    service_file = 'three-tier-java-app/services.yaml'

    try:
        # Read and modify deployment file to add OpenTelemetry annotations
        with open(deployment_file, 'r') as f:
            deployments = list(yaml.safe_load_all(f))

        # Add OpenTelemetry annotations to each deployment (except load-generator)
        for deployment in deployments:
            if deployment['metadata']['name'] != 'load-generator':
                if 'annotations' not in deployment['spec']['template']['metadata']:
                    deployment['spec']['template']['metadata']['annotations'] = {}
                deployment['spec']['template']['metadata']['annotations'].update({
                    'instrumentation.opentelemetry.io/inject-java': 'opentelemetry-operator-system/elastic-instrumentation'
                })

        # Write modified deployments to a temporary file
        modified_deployment_file = 'resources/three-tier-java-app/modified-deployment.yaml'
        with open(modified_deployment_file, 'w') as f:
            yaml.safe_dump_all(deployments, f)

        # Apply the configurations
        subprocess.run(['kubectl', 'apply', '-f', modified_deployment_file], check=True)
        subprocess.run(['kubectl', 'apply', '-f', service_file], check=True)
        
        print("Java favorite application deployed successfully with OpenTelemetry instrumentation.")
        
    except Exception as e:
        print(f"Error deploying Java favorite application: {e}")
        raise

init()
deploy_three_tiered_java()

