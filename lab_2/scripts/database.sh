#!/bin/bash

set -e

DB_ADDR=$1

echo "DB_ADDR=$DB_ADDR"

# DB setup script locations
MYSQL_INIT_URL="https://raw.githubusercontent.com/spring-petclinic/spring-petclinic-rest/master/src/main/resources/db/mysql/initDB.sql"
MYSQL_POPULATE_URL="https://raw.githubusercontent.com/spring-petclinic/spring-petclinic-rest/master/src/main/resources/db/mysql/populateDB.sql"

MYSQL_CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

sudo apt update
sudo apt upgrade -y
sudo apt install -y mysql-server

cd ~
mkdir database
cd database || exit 1

wget $MYSQL_INIT_URL
wget $MYSQL_POPULATE_URL

# Open the DB on a different address
# sed -i "s/^\(bind-address[[:space:]]*=[[:space:]]*\).*/\1$DB_ADDR/g" $MYSQL_CONFIG_FILE
sed -i "s/127.0.0.1/0.0.0.0/g" $MYSQL_CONFIG_FILE

sudo service mysql start

# Create user "pc" (as defined in frontend)
# TODO change the IP and password and username
sudo mysql -e "CREATE USER 'pc'@'%' IDENTIFIED BY 'petclinic';"
sudo mysql -e "CREATE USER 'pc'@'0.0.0.0' IDENTIFIED BY 'petclinic';"
FAULTY_COMMAND="GRANT ALL PRIVILEGES ON petclinic\.\* TO pc@localhost IDENTIFIED BY 'pc';"
# VALID_COMMAND="GRANT ALL PRIVILEGES ON petclinic.* TO 'pc'@'%';"
sed -i "s/$FAULTY_COMMAND//g" ./initDB.sql

echo "GRANT ALL PRIVILEGES ON petclinic.* TO 'pc'@'%';" >>./initDB.sql
echo "GRANT ALL PRIVILEGES ON petclinic.* TO pc@0.0.0.0;" >>./initDB.sql

sudo cat "./initDB.sql" | sudo mysql
sudo mysql -e "FLUSH PRIVILEGES;"

echo "initDB.sql finished"

sudo cat "./populateDB.sql" | sudo mysql -D "petclinic"

sudo service mysql restart
