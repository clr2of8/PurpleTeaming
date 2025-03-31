#!/bin/bash
# wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/linux-vm-setup.sh -O linux-vm-setup.sh; chmod +x linux-vm-setup.sh; ./linux-vm-setup.sh

echo "********"
sudo apt update
sudo apt install git curl gedit -y

mkdir ~/.ssh
chmod 700 ~/.ssh
wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/art -O ~/.ssh/art
chmod 600 ~/.ssh/art
wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/art.pub -O ~/.ssh/art.pub
chmod 644 ~/.ssh/art.pub
wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/authorized_keys -O ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys


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
sudo unzip sra-vectr-runtime-9.6.5-ce.zip
sudo sed -i -r "s/VECTR_HOSTNAME\=.*$/VECTR_HOSTNAME=linux.cloudlab.lan/g" /opt/vectr/.env
cd /opt/vectr
sudo docker compose down
sudo docker compose up -d

echo "****Installing MITRE CALDERA v5.1.0****"
cd ~
git clone https://github.com/mitre/caldera.git --recursive --tag 5.1.0
mv 5.1.0/ caldera
cd caldera
# Pin CALDERA version to specific GitHub commit
git checkout 6d3d853b89f4d5d5ce204eb86acf0e1d5d6cedb9
cp conf/default.yml conf/local.yml
sed -i -r "s/: admin.*$/: AtomicRedTeam1\!/g" conf/local.yml
sed -i -r "s/admin: /art: /g" conf/local.yml
# fix remote login bug https://github.com/mitre/caldera/issues/2901
sed -i -r "s/app.frontend.api_base_url: .*$/app.frontend.api_base_url: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
sed -i -r "s/app.contact.http: .*$/app.contact.http: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
sed -i -r "s/caldera:latest/caldera:5.1.0/g" docker-compose.yml
echo VITE_CALDERA_URL=http://linux.cloudlab.lan:8888 > plugins/magma/.env
sed -i -r "s/    volumes://g" docker-compose.yml
sed -i -r "s/      - .\/:\/usr\/src\/app/    restart: always/g" docker-compose.yml
sed -i -r "s/version: '3'//g" docker-compose.yml
sed -i -r "s/\- atomic/\- atomicNot/g" Dockerfile
sudo docker compose build
sudo docker compose up -d

echo "****Install OpenBAS***"
mkdir ~/openbas
cd ~/openbas
git clone https://github.com/OpenBAS-Platform/docker.git
cd docker
# Pin openBAS version to specific GitHub commit
git checkout 55131c9129b2eefe730df3e7a69e03800c932fc0
mv .env.sample .env
sed -i -r "s/OPENBAS_ADMIN_EMAIL=ChangeMe@domain.com/OPENBAS_ADMIN_EMAIL=art@art.com/g" .env
sed -i -r "s/OPENBAS_ADMIN_PASSWORD=ChangeMe/OPENBAS_ADMIN_PASSWORD=AtomicRedTeam1\!/g" .env
echo RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.8 >> .env
sed -i -r "s/OPENBAS_MAIL_IMAP_ENABLED=true/OPENBAS_MAIL_IMAP_ENABLED=false/g" .env
sed -i -r "s/00000000-0000-0000-0000-000000000000/38da7e67-112c-4d53-bb9b-9d25fbc96371/g" .env
sed -i -r "s/OPENBAS_ADMIN_TOKEN=ChangeMe # Should be a valid UUID/OPENBAS_ADMIN_TOKEN=38da7e67-112c-4d53-bb9b-9d25fbc96371/g" .env
sed -i -r "s/localhost:8080/linux.cloudlab.lan:8080/g" docker-compose.yml
sudo docker compose -f docker-compose.yml -f docker-compose.atomic-red-team.yml up -d
# sudo docker compose down -v
# sudo docker container ls
# sudo docker logs docker-collector-atomic-red-team-1

echo "****Done with Linux VM Setup****"
echo "You need to manually install the art user in VECTR and create an Attack Simulation assessment"
