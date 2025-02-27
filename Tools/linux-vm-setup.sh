#!/bin/bash
# wget https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/linux-vm-setup.sh -O linux-vm-setup.sh; chmod +x linux-vm-setup.sh; ./linux-vm-setup.sh

echo "********"
sudo apt update
sudo apt install git curl -y

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

echo "****Installing MITRE CALDERA v5.0.0****"
cd ~
git clone https://github.com/mitre/caldera.git --recursive --tag 5.0.0
mv 5.0.0/ caldera
cd caldera
cp conf/default.yml conf/local.yml
sed -i -r "s/: admin.*$/: AtomicRedTeam1\!/g" conf/local.yml
sed -i -r "s/admin: /art: /g" conf/local.yml
# fix remote login bug https://github.com/mitre/caldera/issues/2901
sudo kill -9 $(sudo lsof -t -i :8888)
sed -i -r "s/app.frontend.api_base_url: .*$/app.frontend.api_base_url: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
sed -i -r "s/app.contact.http: .*$/app.contact.http: http:\/\/linux.cloudlab.lan:8888/g" conf/local.yml
cp plugins/magma/.env.template plugins/magma/.env
sed -i -r "s/VITE_CALDERA_URL=http:\/\/localhost:8888/VITE_CALDERA_URL=http:\/\/linux.cloudlab.lan:8888/g" plugins/magma/.env
sudo docker build . --build-arg WIN_BUILD=true -t caldera:5.0.0
sudo docker run -p 8888:8888 caldera:5.0.0

echo "****Install OpenBAS***"
mkdir ~/openbas
cd ~/openbas
git clone https://github.com/OpenBAS-Platform/docker.git
cd docker
mv .env.sample .env
sed -i -r "s/OPENBAS_ADMIN_EMAIL=ChangeMe@domain.com/OPENBAS_ADMIN_EMAIL=art@art.com/g" .env
sed -i -r "s/OPENBAS_ADMIN_PASSWORD=ChangeMe/OPENBAS_ADMIN_PASSWORD=AtomicRedTeam1\!/g" .env
echo RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.8 >> .env
sed -i -r "s/OPENBAS_MAIL_IMAP_ENABLED=true/OPENBAS_MAIL_IMAP_ENABLED=false/g" .env
sed -i -r "s/00000000-0000-0000-0000-000000000000/38da7e67-112c-4d53-bb9b-9d25fbc96371/g" .env
sed -i -r "s/OPENBAS_ADMIN_TOKEN=ChangeMe # Should be a valid UUID/OPENBAS_ADMIN_TOKEN=38da7e67-112c-4d53-bb9b-9d25fbc96371/g" .env
sudo docker compose -f docker-compose.yml -f docker-compose.atomic-red-team.yml up -d

echo "****Install OpenCTI***"
mkdir ~/opencti
cd ~/opencti
git clone https://github.com/OpenCTI-Platform/docker.git
cd docker
mv .env.sample .env
sed -i -r "s/OPENCTI_ADMIN_EMAIL=admin@opencti.io/OPENCTI_ADMIN_EMAIL=art@art.com/g" .env
sed -i -r "s/OPENCTI_ADMIN_PASSWORD=changeme/OPENCTI_ADMIN_PASSWORD=AtomicRedTeam1\!/g" .env
sed -i -r "s/OPENCTI_ADMIN_TOKEN=ChangeMe_UUIDv4/OPENCTI_ADMIN_TOKEN=38da7e67-112c-4d53-bb9b-9d25fbc96371/g" .env
sed -i -r "s/MINIO_ROOT_USER=opencti/MINIO_ROOT_USER=ChangeMeAccess/g" .env
sed -i -r "s/MINIO_ROOT_PASSWORD=changeme/MINIO_ROOT_PASSWORD=ChangeMeKey/g" .env
sed -i -r "s/RABBITMQ_DEFAULT_USER=opencti/RABBITMQ_DEFAULT_USER=ChangeMe/g" .env
sed -i -r "s/RABBITMQ_DEFAULT_PASS=ChangeMe/RABBITMQ_DEFAULT_PASS=ChangeMe/g" .env
sed -i -r "s/localhost:8080/localhost:7080/g" .env
sed -i -r "s/8080/7080/g" docker-compose.yml
echo RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.8 >> .env
sudo docker compose up -d
# sudo docker compose down -v

echo "****Done with Linux VM Setup****"
echo "You need to manually install the art user in VECTR and create an Attack Simulation assessment"
