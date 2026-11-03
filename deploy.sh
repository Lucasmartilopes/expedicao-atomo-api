
#!/bin/bash

set -e

# Configuracoes da Azure
RESOURCE_GROUP="rg-expedicao-atomo-automacao"
LOCATION="chilecentral"
VM_NAME="vm-expedicao-atomo-demo"
VM_SIZE="Standard_D2_v4"
ADMIN_USER="azureuser"

echo "=================================="
echo " INICIANDO DEPLOY DA API"
echo "=================================="

# 1. Criar Resource Group
echo "Criando Resource Group..."

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# 2. Criar maquina virtual
echo "Criando maquina virtual..."

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --location "$LOCATION" \
  --size "$VM_SIZE" \
  --image Ubuntu2404 \
  --admin-username "$ADMIN_USER" \
  --generate-ssh-keys \
  --public-ip-sku Standard

# 3. Liberar porta 8080
echo "Liberando porta 8080..."

az vm open-port \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --port 8080

# 4. Instalar Docker e implantar a API
echo "Instalando Docker e implantando a API..."

REMOTE_SCRIPT=$(cat <<'REMOTE'
#!/bin/bash
set -e

apt-get update
apt-get install -y docker.io git

systemctl enable --now docker

git clone https://github.com/Lucasmartilopes/expedicao-atomo-api.git /opt/expedicao-atomo-api

cd /opt/expedicao-atomo-api

docker build -t expedicao-atomo-api .

docker run -d \
  --restart unless-stopped \
  --name expedicao-atomo-api \
  -p 8080:8080 \
  expedicao-atomo-api
REMOTE
)

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "$REMOTE_SCRIPT"

# 5. Obter IP publico
PUBLIC_IP=$(az vm list-ip-addresses \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  --output tsv)

echo "=================================="
echo " API IMPLANTADA!"
echo "=================================="
echo "Swagger: http://$PUBLIC_IP:8080/swagger-ui.html"

# 6. Confirmar exclusao dos recursos
echo ""
echo "Apos testar a API, digite EXCLUIR para remover a infraestrutura."
read -r -p "Confirmacao: " CONFIRMACAO

if [ "$CONFIRMACAO" = "EXCLUIR" ]; then
  echo "Excluindo Resource Group..."

  az group delete \
    --name "$RESOURCE_GROUP" \
    --yes

  echo "Recursos excluidos!"
  az group list --output table
else
  echo "Exclusao cancelada. O Resource Group foi mantido."
fi
