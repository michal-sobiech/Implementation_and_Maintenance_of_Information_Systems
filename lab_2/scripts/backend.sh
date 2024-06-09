#!/bin/bash

set -e

BE_PORT=$1
DB_ADDR=$2
DB_PORT=$3

echo "BE_PORT=$BE_PORT"
echo "DB_ADDR=$DB_ADDR"
echo "DB_PORT=$DB_PORT"

cd "$HOME"
mkdir app
cd app

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-19-jdk

git clone https://github.com/spring-petclinic/spring-petclinic-rest
cd spring-petclinic-rest

# mysql database config

find "./src" -type f -name "application.properties" \
    -exec sed -i 's/hsqldb/mysql/g' {} \; \
    -exec sed -i "s/9966/$BE_PORT/" {} \;
sed -i "s/localhost:3306/$DB_ADDR:$DB_PORT/" "src/main/resources/application-mysql.properties"

./mvnw spring-boot:run &
