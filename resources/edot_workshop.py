from flask import Flask

import context
import assistant
import subprocess  # Import subprocess to run shell commands

app = Flask(__name__)

def init():
    assistant.load()

def deploy_java_favorite():
    """
    Deploys the Java favorite application using kubectl.
    """
    import os
    yaml_file = os.path.join('java-favorite', 'combined.yml')
    try:
        # Apply the Kubernetes configuration using kubectl
        subprocess.run(['kubectl', 'apply', '-f', yaml_file], check=True)
        print("Java favorite application deployed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error deploying Java favorite application: {e}")

init()
deploy_java_favorite()
