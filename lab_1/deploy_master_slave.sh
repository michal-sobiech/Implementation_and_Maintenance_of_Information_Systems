#!/bin/bash
set -e

RESOURCE_GROUP_NAME="WUS_LAB1_GR1"
RESOURCE_GROUP_LOCATION="polandcentral"
TEMPLATE_NAME="WUS_LAB1_GR1_CONFIG1"
TEMPLATE_FILE="./templates/config1.json"

BACKEND_PORT=9966
MASTER_DATABASE_PORT=3306
SLAVE_DATABASE_PORT=3306

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
        --resource-group WUS_LAB1_GR1 \
        --name "$VIRTUAL_MACHINE_NAME" \
        --show-details \
        --query 'publicIps' \
        --output tsv
}

get_virtual_machine_private_IP() {
    VIRTUAL_MACHINE_NAME=$1
    az vm show \
        --resource-group WUS_LAB1_GR1 \
        --name "$VIRTUAL_MACHINE_NAME" \
        --show-details \
        --query 'privateIps' \
        --output tsv
}

FRONTEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.frontendVMName.value')
BACKEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName.value')
MASTER_DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.masterDatabaseVMName.value')
SLAVE_DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.slaveDatabaseVMName.value')

# FRONTEND_IP=$(get_virtual_machine_public_IP "$FRONTEND_VM_NAME")
BACKEND_PUBLIC_IP=$(get_virtual_machine_public_IP "$BACKEND_VM_NAME")
MASTER_DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$MASTER_DATABASE_VM_NAME")

# Parameters need to be passed this way due to a known Azure CLI bug
az vm run-command invoke \
    --name "$FRONTEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/frontend.sh \
    --parameters "$BACKEND_PUBLIC_IP" "$BACKEND_PORT" | jq -r '.value[].message' >frontend.log
echo "Frontend initiated."

az vm run-command invoke \
    --name "$BACKEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend.sh \
    --parameters "$BACKEND_PORT" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" | jq -r '.value[].message' >backend.log
echo "Backend initiated."

az vm run-command invoke \
    --name "$DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database_master.sh \
    --parameters "$MASTER_DATABASE_PRIVATE_IP" | jq -r '.value[].message' >database.log
echo "Database initiated."

az vm run-command invoke \
    --name "$DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database_slave.sh \
    --parameters "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" | jq -r '.value[].message' >database.log
echo "Database initiated."
