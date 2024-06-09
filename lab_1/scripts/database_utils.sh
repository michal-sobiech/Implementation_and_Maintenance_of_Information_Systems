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
    # Open the DB on a different address
    sed -i "s/^[[:space:]]*\($1[[:space:]]*=[[:space:]]*\).*/\1$2/g" "$3"
}

function setup_db_address() {
    # Open the DB on a different address
    setup_option bind-address "$1" "$2"
}

function setup_db_id() {
    setup_option server-id "$1" "$2"
}

function setup_db_log() {
    # Open the DB on a different address
    setup_option lob_bin "$1" "$2"
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

