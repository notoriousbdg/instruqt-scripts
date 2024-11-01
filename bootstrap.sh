#!/bin/bash 

# Wait for the Instruqt host bootstrap to finish
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]
do
    sleep 1
done

# Wait for the Kubernetes API server to become available
while ! curl --silent --fail --output /dev/null http://localhost:8001/api 
do
    sleep 1 
done

# Enable bash completion for kubectl
echo "source /usr/share/bash-completion/bash_completion" >> /root/.bashrc
echo "complete -F __start_kubectl k" >> /root/.bashrc

# Update package lists and install git and python
apt-get update
apt-get install -y git python3 python3-pip

# Verify Python installation
python3 --version
pip3 --version

git clone https://github.com/davidgeorgehope/instruqt-scripts

echo $GCSKEY_EDEN_WORKSHOP >> /root/.env
echo $LLM_PROXY_STAGING >> /root/.env
echo $LLM_PROXY_PROD >> /root/.env

cd instruqt-scripts
chmod +x setup-elastic-in-instruqt.sh
source ./setup-elastic-in-instruqt.sh
