#!/bin/bash
set -e

RESOURCE_GROUP_NAME="WUS_LAB1_CFG1"
RESOURCE_GROUP_LOCATION="polandcentral"
TEMPLATE_NAME="WUS_LAB1_GR1_CONFIG1"
TEMPLATE_FILE="./templates/config1.json"

BACKEND_PORT=9966
DB_PORT=3306

DOES_RG_EXIST="$(az group exists --resource-group "$RESOURCE_GROUP_NAME")"

# Cleanup in case the resource group still exists
if [ "$DOES_RG_EXIST" != "false" ]; then
    az group delete \
        --name $RESOURCE_GROUP_NAME \
        --yes
fi

# Deploy
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $RESOURCE_GROUP_LOCATION >/dev/null

DEPLOY_OUTPUT=$(az deployment group create \
    --name $TEMPLATE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file $TEMPLATE_FILE)
echo "$DEPLOY_OUTPUT" >deploy.log
echo "VMs deployed."

get_virtual_machine_public_IP() {
    VIRTUAL_MACHINE_NAME=$1
    az vm show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VIRTUAL_MACHINE_NAME" \
        --show-details \
        --query 'publicIps' \
        --output tsv
}

get_virtual_machine_private_IP() {
    VIRTUAL_MACHINE_NAME=$1
    az vm show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VIRTUAL_MACHINE_NAME" \
        --show-details \
        --query 'privateIps' \
        --output tsv
}

FRONTEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.frontendVMName.value')
BACKEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName.value')
DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.databaseVMName.value')

FRONTEND_PUBLIC_IP=$(get_virtual_machine_public_IP "$FRONTEND_VM_NAME")
BACKEND_PRIVATE_IP=$(get_virtual_machine_private_IP "$BACKEND_VM_NAME")
DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$DATABASE_VM_NAME")

# Setup ssh keys
./ssh_config.sh $FRONTEND_PUBLIC_IP

# Run ansible
