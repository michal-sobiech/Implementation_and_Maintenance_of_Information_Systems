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

FRONTEND_IP=$(get_virtual_machine_public_IP "$FRONTEND_VM_NAME")
BACKEND_PRIVATE_IP=$(get_virtual_machine_private_IP "$BACKEND_VM_NAME")
DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$DATABASE_VM_NAME")

# Parameters need to be passed this way due to a known Azure CLI bug
az vm run-command invoke \
    --name "$FRONTEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/frontend.sh \
    --parameters "$BACKEND_PRIVATE_IP" "$BACKEND_PORT" \
    "$FRONTEND_IP" | jq -r '.value[].message' >frontend.log
echo "Frontend initiated."

az vm run-command invoke \
    --name "$BACKEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend.sh \
    --parameters "$BACKEND_PORT" "$DATABASE_PRIVATE_IP" "$DB_PORT" | jq -r '.value[].message' >backend.log
echo "Backend initiated."

az vm run-command invoke \
    --name "$DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database.sh \
    --parameters "$DATABASE_PRIVATE_IP" | jq -r '.value[].message' >database.log
echo "Database initiated."
