#!/bin/bash

touch testowy_plik.txt


# set -e

# BE_ADDR=$1
# BE_PORT=$2
# FE_ADDR=$3

# echo "BE_ADDR=$BE_ADDR"
# echo "BE_PORT=$BE_PORT"

# NGINX_CONFIG_FILE="/etc/nginx/sites-available/default"
# APP_SHARED_FILES_DIR="/var/www/app/dist"

# cd ~

# echo "$BE_ADDR" >temp.txt

# mkdir app
# cd app

# sudo snap refresh
# sudo snap install node --channel 18/stable --classic

# echo "NODE VERSION"
# node -v

# echo NPM_VERSION
# npm -v

# git clone https://github.com/spring-petclinic/spring-petclinic-angular
# cd spring-petclinic-angular

# # Replace the backend IP (default is localhost)
# find ~/app/spring-petclinic-angular/src -type f -exec sed -i "s/localhost/$FE_ADDR/g" {} \;
# find ~/app/spring-petclinic-angular/src -type f -exec sed -i "s/9966/80/g" {} \;

# npm install
# npm install -g @angular/cli

# echo "NG VERSION"
# ng --help

# yes | ng build --configuration=production

# mkdir -p $APP_SHARED_FILES_DIR
# cp -r ./dist/* $APP_SHARED_FILES_DIR

# sudo apt install -y nginx
# NGINX_HTTP_SERVER_CONFIG="\
# server { \
#     listen 80; \
#     index index.html; \
#     location / { \
#         root /var/www/app/dist; \
#         try_files \$uri \$uri/ /index.html; \
#     } \
#     location /petclinic/api/ { \
#         proxy_pass http://${BE_ADDR}:${BE_PORT}; \
#         include proxy_params; \
#     } \
# }"

# echo "$NGINX_HTTP_SERVER_CONFIG" | sudo tee "$NGINX_CONFIG_FILE" >/dev/null

# sudo systemctl restart nginx
