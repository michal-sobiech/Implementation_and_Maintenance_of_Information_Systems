#!/bin/bash

# 4 arguments
NGINX_PORT=$1
FIRST_BACKEND=$2
SECOND_BACKEND=$3
THIRD_BACKEND=$4

NGINX_CONFIG_FILE="/etc/nginx/conf.d/loadbalancer.conf"

# installing nginx
sudo su
sudo apt update -y
sudo apt install -y nginx
cd ~

BALANCER_CONFIG=" \
upstream backend { \
    server $FIRST_BACKEND; \
    server $SECOND_BACKEND; \
    server $THIRD_BACKEND; \
} \
server { \
    listen $NGINX_PORT; \
    location /petclinic/api { \
        proxy_pass http://backend; \
    } \
}"

echo "$BALANCER_CONFIG" | sudo tee "$NGINX_CONFIG_FILE" >/dev/null

# reload nginx
sudo systemctl restart nginx
