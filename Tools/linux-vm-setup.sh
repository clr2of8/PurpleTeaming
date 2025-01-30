#!/bin/bash

echo "****Installing Git,pip3,curl****"
sudo apt update
sudo apt install git python3-pip curl npm nodejs ca-certificates -y

echo "****Installing GO****"
sudo apt install golang-go -y

echo "****Installing MITRE CALDERA v5.0.0****"
sudo apt install upx -y
cd ~
git clone https://github.com/mitre/caldera.git --recursive --tag 5.0.0
mv 5.0.0/ caldera
cd caldera
python3 -m venv .venv
source .venv/bin/activate
sudo .venv/bin/python3 -m pip install -r requirements.txt
.venv/bin/python3 server.py --insecure --build &

echo "****Installing VECTR****"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo mkdir -p /opt/vectr
cd /opt/vectr
sudo wget https://github.com/SecurityRiskAdvisors/VECTR/releases/download/ce-9.5.3/sra-vectr-runtime-9.5.3-ce.zip
sudo unzip sra-vectr-runtime-9.5.3-ce.zip
sed -i -r "s/VECTR_HOSTNAME\=.*$/VECTR_HOSTNAME=linux.cloudlab.lan/g" /opt/vectr/.env
cd /opt/vectr
sudo docker-compose down
sudo docker compose up -d

echo "****Done with Linux VM Setup****"
