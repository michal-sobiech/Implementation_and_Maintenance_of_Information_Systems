#!/bin/bash

function install_mysql() {
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y mysql-server
}


function download_sql_scripts() {
  for url in "$@"; 
  do
    wget "$url"
  done
}

function make_database_dir() {
    cd ~ || exit
    mkdir database
    cd database || exit 1
}

function setup_option() {
    sed -i "s/^[[:space:]]*\($1[[:space:]]*=[[:space:]]*\).*/\1$2/g" "$3"
}

function setup_db_address() {
    setup_option bind-address "$1" "$2"
}

function setup_db_id() {
    setup_option server-id "$1" "$2"
}

function setup_db_log() {
    # Open the DB on a different address
    setup_option log_bin "$1" "$2"
}



function create_user() {
    # TODO change the IP and password and username
    sudo mysql -e "CREATE USER '$1'@'%' IDENTIFIED BY '$2';"
    sudo mysql -e "CREATE USER '$1'@'localhost' IDENTIFIED BY '$2';"
}


function remove_faulty_command() {
    FAULTY_COMMAND="GRANT ALL PRIVILEGES ON petclinic\.\* TO $1@localhost IDENTIFIED BY '$1';"
    # VALID_COMMAND="GRANT ALL PRIVILEGES ON petclinic.* TO 'pc'@'%';"
    sed -i "s/$FAULTY_COMMAND//g" ./initDB.sql
}

function grant_privileges_to() {
    echo "GRANT ALL PRIVILEGES ON petclinic.* TO '$1'@'%';" >>./initDB.sql
    echo "GRANT ALL PRIVILEGES ON petclinic.* TO $1@localhost;" >>./initDB.sql
}


set -e

SLAVE_DB_ADDR=$1
MASTER_DB_ADDR=$2
MASTER_DB_PORT=$3


echo "MASTER_DB_ADDR=$MASTER_DB_ADDR"

# DB setup script locations
MYSQL_INIT_URL="https://raw.githubusercontent.com/spring-petclinic/spring-petclinic-rest/master/src/main/resources/db/mysql/initDB.sql"
MYSQL_POPULATE_URL="https://raw.githubusercontent.com/spring-petclinic/spring-petclinic-rest/master/src/main/resources/db/mysql/populateDB.sql"

MYSQL_CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

install_mysql

make_database_dir

download_sql_scripts $MYSQL_INIT_URL $MYSQL_POPULATE_URL

setup_db_address "$SLAVE_DB_ADDR" $MYSQL_CONFIG_FILE
setup_db_id 2 $MYSQL_CONFIG_FILE
# setup_db_log "$MASTER_DB_ADDR" $MYSQL_CONFIG_FILE

sudo service mysql start

# Create user "pc" (as defined in frontend)
create_user pc petclinic
create_user slave slave
remove_faulty_command pc

grant_privileges_to pc 
grant_privileges_to slave

sudo cat "./initDB.sql" | sudo mysql
echo "initDB.sql finished"

sudo mysql -e "CHANGE MASTER TO MASTER_HOST='$MASTER_DB_ADDR', MASTER_USER='replica', MASTER_PASSWORD='replica', MASTER_PORT=$MASTER_DB_PORT;"
sudo mysql -e "FLUSH PRIVILEGES;"

sudo cat "./populateDB.sql" | sudo mysql -D "petclinic"
echo "populateDB.sql finished"

sudo service mysql restart
sudo mysql -e "start slave"
echo "Master mysql server started"
