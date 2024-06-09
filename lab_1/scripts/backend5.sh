#!/bin/bash

function setup_option() {
    sed -i "s|^[[:space:]]*\($1[[:space:]]*=[[:space:]]*\).*/|1$2|g" "$3"
}

set -e

BE_PORT=$1
MASTER_DB_ADDR=$2
MASTER_DB_PORT=$3
SLAVE_DB_ADDR=$4
SLAVE_DB_PORT=$5

echo "BE_PORT=$BE_PORT"
echo "MASTER_DB_ADDR=$MASTER_DB_ADDR"
echo "MASTER_DB_PORT=$MASTER_DB_PORT"

cd "$HOME"
mkdir app
cd app

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-19-jdk

git clone https://github.com/spring-petclinic/spring-petclinic-rest
cd spring-petclinic-rest

# mysql database config

APP_MYSQL_CONFIG="src/main/resources/application-mysql.properties"

# TODO pierwszy exec chyba powinien byc inny
find "./src" -type f -name "application.properties" \
    -exec sed -i 's/hsqldb/mysql/g' {} \; \
    -exec sed -i "s/9966/$BE_PORT/" {} \;
sed -i "/spring\.datasource\.url/d" $APP_MYSQL_CONFIG
CONNECTION_URL="jdbc:mysql:replication://$MASTER_DB_ADDR:$MASTER_DB_PORT,$SLAVE_DB_ADDR:$SLAVE_DB_PORT/petclinic?useSSL=false&useUnicode=true&allowSourceDownConnections=true"
echo "spring.datasource.url=$CONNECTION_URL" >> $APP_MYSQL_CONFIG

./mvnw spring-boot:run &
