#!/bin/bash
set -e

LOG_DIR="./logs/config2"

[ -e $LOG_DIR ] || mkdir -p $LOG_DIR

RESOURCE_GROUP_NAME="WUS_LAB1_CFG2"
RESOURCE_GROUP_LOCATION="polandcentral"
TEMPLATE_NAME="WUS_LAB1_GR1_CONFIG2"
TEMPLATE_FILE="./templates/config2.json"

FIRST_BE_PORT=8080
SECOND_BE_PORT=8081
THIRD_BE_PORT=8082
NGINX_PORT=8083
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
echo "$DEPLOY_OUTPUT" >$LOG_DIR/deploy.log
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

NGINX_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.nginxVMName.value')

FIRST_BACKEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName1.value')
SECOND_BACKEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName2.value')
THIRD_BACKEND_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName3.value')

DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.databaseVMName.value')

FRONTEND_IP=$(get_virtual_machine_public_IP "$FRONTEND_VM_NAME")

NGINX_PRIVATE_IP=$(get_virtual_machine_private_IP "$NGINX_VM_NAME")

FIRST_BE_IP=$(get_virtual_machine_private_IP "$FIRST_BACKEND_VM_NAME")
SECOND_BE_IP=$(get_virtual_machine_private_IP "$SECOND_BACKEND_VM_NAME")
THIRD_BE_IP=$(get_virtual_machine_private_IP "$THIRD_BACKEND_VM_NAME")

DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$DATABASE_VM_NAME")

az vm run-command invoke \
    --name "$FRONTEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/frontend.sh \
    --parameters "$NGINX_PRIVATE_IP" "$NGINX_PORT" \
    "$FRONTEND_IP" | jq -r '.value[].message' >"$LOG_DIR/frontend.log"
echo "Frontend initiated."

az vm run-command invoke \
    --name "$FIRST_BACKEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend.sh \
    --parameters "$FIRST_BE_PORT" "$DATABASE_PRIVATE_IP" \
    "$DB_PORT" | jq -r '.value[].message' >"$LOG_DIR/backend1.log"
echo "First backend initiated."

az vm run-command invoke \
    --name "$SECOND_BACKEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend.sh \
    --parameters "$SECOND_BE_PORT" "$DATABASE_PRIVATE_IP" \
    "$DB_PORT" | jq -r '.value[].message' >"$LOG_DIR/backend2.log"
echo "Second backend initiated."

az vm run-command invoke \
    --name "$THIRD_BACKEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend.sh \
    --parameters "$THIRD_BE_PORT" "$DATABASE_PRIVATE_IP" \
    "$DB_PORT" | jq -r '.value[].message' >"$LOG_DIR/backend3.log"
echo "Third backend initiated."

az vm run-command invoke \
    --name "$NGINX_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/nginx.sh \
    --parameters "$NGINX_PORT" \
    "$FIRST_BE_IP:$FIRST_BE_PORT" \
    "$SECOND_BE_IP:$SECOND_BE_PORT" \
    "$THIRD_BE_IP:$THIRD_BE_PORT" | jq -r '.value[].message' >"$LOG_DIR/balancer.log"
echo "Nginx initiated."

az vm run-command invoke \
    --name "$DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database.sh \
    --parameters "$DATABASE_PRIVATE_IP" | jq -r '.value[].message' >"$LOG_DIR/database.log"
echo "Database initiated."
