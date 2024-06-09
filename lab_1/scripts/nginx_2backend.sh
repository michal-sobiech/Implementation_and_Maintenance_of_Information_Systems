#!/bin/bash

# 4 arguments
NGINX_PORT = ${NGINX_PORT}
FIRST_BACKEND = ${FIRST_BACKEND}
SECOND_BACKEND = ${SECOND_BACKEND}

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