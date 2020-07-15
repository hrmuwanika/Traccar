#!/bin/bash
################################################################################
# Script for installing Traccar GPS Tracking server on Ubuntu 18.04 LTS 
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
# Make a new file:
# sudo vim install_traccar.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_traccar.sh
# Execute the script to install Odoo:
# ./install_traccar.sh
################################################################################

#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

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
sudo apt install -y mysql-server
#sudo systemctl enable mysql.service

ufw enable
ufw allow http
ufw allow https
ufw allow 8082/tcp
ufw allow 5055/tcp
ufw allow ssh

#execute sql commands with the user
mysql_secure_installation

mysql -u root -p<<MYSQL_SCRIPT
CREATE DATABASE traccar;
GRANT ALL PRIVILEGES on *.* to 'traccar_admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'abc1234!';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

cd /usr/src
wget https://github.com/traccar/traccar/releases/download/v4.9/traccar-linux-64-4.9.zip
unzip traccar-linux-*.zip

sudo ./traccar.run

cd /usr/src
sudo wget https://raw.githubusercontent.com/hrmuwanika/Traccar/master/traccar.xml 
sudo cp traccar.xml /opt/traccar/conf/traccar.xml

sudo systemctl enable traccar.service
sudo systemctl start traccar.service
sudo systemctl status traccar.service

