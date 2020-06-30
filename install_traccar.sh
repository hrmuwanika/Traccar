#!/bin/bash
################################################################################
# Script for installing Traccar GPS Tracking software on Ubuntu 18.04 LTS 
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
# Make a new file:
# sudo vim install_traccar.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_traccar.sh
# Execute the script to install Odoo:
# ./install_traccar.sh
################################################################################
# Set the website name
WEBSITE_NAME="example.com"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"
##

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n============== Update Server ======================="
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

#--------------------------------------------------
# Install dependences
#--------------------------------------------------
echo -e "\n============== Install dependences ======================="
sudo apt install -y unzip default-jre
sudo apt-get install mysql-server
mysql_secure_installation
sudo systemctl enable mysql.service

ufw enable
ufw allow http
ufw allow https
ufw allow 8082/tcp
ufw allow 5055/tcp
ufw allow ssh

#execute sql commands with the user
PASS=`pwgen -s 40 1`
mysql -u root -p --execute="GRANT ALL PRIVILEGES on *.* to 'traccar_admin'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PASS'; FLUSH PRIVILEGES;"
echo "create database traccar" | mysql -u root -p

cd /usr/src
wget https://github.com/traccar/traccar/releases/download/v4.8/traccar-linux-64-4.8.zip
unzip traccar-linux-*.zip

sudo ./traccar.run

rm /opt/traccar/conf/traccar.xml
cat <<EOF > /opt/traccar/conf/traccar.xml

<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>

<properties>
  <entry key="config.default">./conf/default.xml</entry>

  <!-- DataBase MariaDB  -->
  <entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
  <entry key='database.url'>jdbc:mysql://localhost:3306/traccar?allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
  <entry key='database.user'>traccar_admin</entry>
  <entry key='database.password'>$PASS</entry>
  <entry key='server.timeout'>120</entry>
	
  <!-- Mail Service - Amazon SES -->
  <entry key='mail.smtp.host'>email-smtp.us-east-1.amazonaws.com</entry>
  <entry key='mail.smtp.port'>25</entry>
  <entry key='mail.smtp.starttls.enable'>true</entry>
  <entry key='mail.smtp.ssl.enable'>false</entry>
  <entry key='mail.smtp.from'>mail@domain.com</entry>
  <entry key='mail.smtp.auth'>true</entry>
  <entry key='mail.smtp.username'>[AccessKeyID]</entry>
  <entry key='mail.smtp.password'>[SecretAccessKey]</entry>
		
</properties>
EOF

sudo systemctl enable traccar.service
sudo systemctl start traccar.service

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
echo -e "\n======== Installing nginx ============="
  sudo apt install -y nginx
  sudo systemctl enable nginx
  
cat <<EOF > /etc/nginx/sites-available/traccar/etc/nginx/sites-available/traccar
#traccar server
upstream traccar_server {
    server 127.0.0.1:8082;
}
upstream traccar_client {
    server 127.0.0.1:5055;
}
# http to https redirection
server {
    listen 80;
    listen [::]:80;
    server_name example.com;
   
    # Proxy settings
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
   
    # Add Headers for traccar proxy mode
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
   
    # log
    access_log /var/log/nginx/traccar-access.log;
    error_log /var/log/nginx/traccar-error.log;
   
    # Request for root domain
    location / {
    proxy_redirect off;
    proxy_pass http://traccar_server;
    }
   
    location /client {
    proxy_pass http://traccar_client;
    }
   
    # Cache static files.
    location ~* /[0-9a-zA-Z_]*/static/ {
                proxy_cache_valid 200 90m;
                proxy_buffering on;
                expires 864000;
                proxy_pass http://traccar_server;
    }
   
    # Gzip Compression
    gzip_types text/css text/scss text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
EOF

  sudo ln -s /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/traccar
  sudo rm /etc/nginx/sites-enabled/default
  sudo systemctl reload nginx
  

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "admin@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo apt-get install software-properties-common
  sudo add-apt-repository universe
  sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  sudo apt-get install python-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo systemctl reload nginx
  echo "\n============ SSL/HTTPS is enabled! ========================"
else
  echo "\n==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

echo "\n========================================================================="
echo "Done! The traccar server is up and running. Specifications:"
echo "Start Odoo service: sudo systemctl start traccar.service"
echo "Stop Odoo service: sudo systemctl stop traccar.service"
echo "Restart Odoo service: sudo systemctl restart traccar.service"
echo "\n========================================================================="

