#!/bin/bash
# wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/linux-vm-setup.sh -O linux-vm-setup.sh; chmod +x linux-vm-setup.sh; ./linux-vm-setup.sh

echo "****Installing Git,pip3,curl****"
sudo apt update
sudo apt install git python3-pip curl npm nodejs ca-certificates -y

echo "****Installing GO****"
sudo apt install golang-go -y

echo "****Installing MITRE CALDERA v5.0.0****"
sudo apt install upx python3.12-venv -y
cd ~
git clone https://github.com/mitre/caldera.git --recursive --tag 5.0.0
mv 5.0.0/ caldera
cd caldera
python3 -m venv .venv
source .venv/bin/activate
sudo .venv/bin/python3 -m pip install -r requirements.txt
cp conf/default.yml conf/local.yml
sed -i -r "s/: admin.*$/: AtomicRedTeam1\!/g" conf/local.yml
sed -i -r "s/admin: /art: /g" conf/local.yml
# fix remote login bug https://github.com/mitre/caldera/issues/2901
sudo kill -9 $(sudo lsof -t -i :8888)
sed -i -r "s/app.frontend.api_base_url: .*$/app.frontend.api_base_url: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
sed -i -r "s/app.contact.http: .*$/app.contact.http: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
.venv/bin/python3 server.py --build &

echo "****Installing VECTR****"
echo '127.0.0.1 linux.cloudlab.lan' | sudo tee -a /etc/hosts
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
sudo wget https://github.com/SecurityRiskAdvisors/VECTR/releases/download/ce-9.6.5/sra-vectr-runtime-9.6.5-ce.zip -nc
sudo unzip sra-vectr-runtime-9.5.3-ce.zip
sudo sed -i -r "s/VECTR_HOSTNAME\=.*$/VECTR_HOSTNAME=linux.cloudlab.lan/g" /opt/vectr/.env
cd /opt/vectr
sudo docker compose down
sudo docker compose up -d
croncmd="sleep 30 && docker compose up -d"
cronjob="@reboot $croncmd"
( crontab -l -u ubuntu | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -u ubuntu -


echo "****Done with Linux VM Setup****"
