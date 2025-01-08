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
    namespace_file = 'three-tier-java-app/namespace.yaml'


    try:
        # Apply the configurations
        subprocess.run(['kubectl', 'apply', '-f', namespace_file], check=True)
        subprocess.run(['kubectl', 'apply', '-f', service_file], check=True)
        subprocess.run(['kubectl', 'apply', '-f', deployment_file], check=True)
        
        print("Java favorite application deployed successfully with OpenTelemetry instrumentation.")
        
    except Exception as e:
        print(f"Error deploying Java favorite application: {e}")
        raise

init()
deploy_three_tiered_java()

