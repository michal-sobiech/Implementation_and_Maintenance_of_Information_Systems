#!/bin/bash
set -e

RESOURCE_GROUP_NAME="WUS_LAB1_CFG5"
RESOURCE_GROUP_LOCATION="polandcentral"
TEMPLATE_NAME="WUS_LAB1_GR1_CONFIG5"
TEMPLATE_FILE="./templates/config5.json"

FIRST_BE_PORT=8080
SECOND_BE_PORT=8081
NGINX_PORT=8082
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
FIRST_BE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName1.value')
SECOND_BE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.backendVMName2.value')
NGINX_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.nginxVMName.value')

MASTER_DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.masterDatabaseVMName.value')
SLAVE_DATABASE_VM_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.parameters.slaveDatabaseVMName.value')

# FRONTEND_IP=$(get_virtual_machine_public_IP "$FRONTEND_VM_NAME")
# BACKEND_PUBLIC_IP=$(get_virtual_machine_public_IP "$BE_VM_NAME")
NGINX_PRIVATE_IP=$(get_virtual_machine_private_IP "$NGINX_VM_NAME")

FIRST_BE_IP=$(get_virtual_machine_private_IP "$FIRST_BE_VM_NAME")
SECOND_BE_IP=$(get_virtual_machine_private_IP "$SECOND_BE_VM_NAME")

MASTER_DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$MASTER_DATABASE_VM_NAME")
SLAVE_DATABASE_PRIVATE_IP=$(get_virtual_machine_private_IP "$SLAVE_DATABASE_VM_NAME")


# Parameters need to be passed this way due to a known Azure CLI bug
az vm run-command invoke \
    --name "$FRONTEND_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/frontend.sh \
    --parameters "$NGINX_PRIVATE_IP" "$NGINX_PORT" | jq -r '.value[].message' >frontend.log
echo "Frontend initiated."

az vm run-command invoke \
    --name "$FIRST_BE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend5.sh \
    --parameters "$FIRST_BE_PORT" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" "$SLAVE_DATABASE_PRIVATE_IP" "$SLAVE_DATABASE_PORT" | jq -r '.value[].message' >backend.log
    # --parameters "$BE_PORT" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" | jq -r '.value[].message' >backend.log
echo "First backend initiated."

az vm run-command invoke \
    --name "$SECOND_BE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/backend5.sh \
    --parameters "$SECOND_BE_PORT" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" "$SLAVE_DATABASE_PRIVATE_IP" "$SLAVE_DATABASE_PORT" | jq -r '.value[].message' >backend.log
    # --parameters "$BE_PORT" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" | jq -r '.value[].message' >backend.log
echo "Second backend initiated."

az vm run-command invoke \
    --name "$NGINX_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/nginx.sh \
    --parameters "$NGINX_PORT" \
    "$FIRST_BE_IP:$FIRST_BE_PORT" \
    "$SECOND_BE_IP:$SECOND_BE_PORT" | jq -r '.value[].message' > balancer.log
echo "Nginx initiated."


az vm run-command invoke \
    --name "$MASTER_DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database_master.sh \
    --parameters "$MASTER_DATABASE_PRIVATE_IP" | jq -r '.value[].message' >master_database.log
echo "Database initiated."

az vm run-command invoke \
    --name "$SLAVE_DATABASE_VM_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --command-id "RunShellScript" \
    --scripts @scripts/database_slave.sh \
    --parameters "$SLAVE_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PRIVATE_IP" "$MASTER_DATABASE_PORT" | jq -r '.value[].message' >slave_database.log
echo "Database initiated."
