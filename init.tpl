#!/bin/bash
sudo apt-get install -y nginx
sudo apt-get install unzip
systemctl start nginx
mkdir /home/ubuntu/demo
sudo npm install -g pm2
 
rm /etc/nginx/nginx.conf
sudo /etc/init.d/nginx start
sudo echo 'user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
 
events {
 worker_connections 768;
 # multi_accept on;
}
 
http {
 server {
 listen 8080;
 server_name *.*;
 root /home/ubuntu/webapp/ui/dist/ui;
 #index index.html;
 location / {
 try_files $uri /index.html;
 }
}
 
 sendfile on;
 tcp_nopush on;
 tcp_nodelay on;
 keepalive_timeout 65;
 types_hash_max_size 2048;
 
 include /etc/nginx/mime.types;
 default_type application/octet-stream;
 
 ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
 ssl_prefer_server_ciphers on;


 
 access_log /var/log/nginx/access.log;
 error_log /var/log/nginx/error.log;
 
 gzip on;
 
 include /etc/nginx/conf.d/*.conf;
 include /etc/nginx/sites-enabled/*;
}
 
' > /etc/nginx/nginx.conf
 
sudo /etc/init.d/nginx start
sudo /etc/init.d/nginx restart
echo 'APPLICATION_ENV=prod' | tee -a /etc/environment
echo 'AWS_BUCKET_NAME=webapp.jayesh.raghuwanshi' | tee -a /etc/environment
echo 'RDS_DATABASE=csye6225' | tee -a /etc/environment
echo '' | tee -a /etc/environment
echo 'RDS_USERNAME=csye6225su2020' |  tee -a /etc/environment
echo 'RDS_PASSWORD=jayesh2207' |  tee -a /etc/environment