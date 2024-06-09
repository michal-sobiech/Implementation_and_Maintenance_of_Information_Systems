SCRIPT_DIR=$(dirname $0)

INIT_DB_SCRIPT_PATH="$SCRIPT_DIR/initDB.sql"
POPULATE_DB_SCRIPT_PATH="$SCRIPT_DIR/populateDB.sql"

sudo mysql -e "CREATE USER 'pc'@'%' IDENTIFIED BY 'petclinic';"
sudo mysql -e "CREATE USER 'pc'@'0.0.0.0' IDENTIFIED BY 'petclinic';"

FAULTY_COMMAND="GRANT ALL PRIVILEGES ON petclinic\.\* TO pc@localhost IDENTIFIED BY 'pc';"
sed -i "s/$FAULTY_COMMAND//g" $INIT_DB_SCRIPT_PATH

echo "GRANT ALL PRIVILEGES ON petclinic.* TO 'pc'@'%';" >>$INIT_DB_SCRIPT_PATH
echo "GRANT ALL PRIVILEGES ON petclinic.* TO pc@0.0.0.0;" >>$INIT_DB_SCRIPT_PATH

sudo cat $INIT_DB_SCRIPT_PATH | sudo mysql
sudo mysql -e "FLUSH PRIVILEGES;"

echo "initDB.sql finished"

sudo cat $POPULATE_DB_SCRIPT_PATH | sudo mysql -D "petclinic"

sudo service mysql restart
