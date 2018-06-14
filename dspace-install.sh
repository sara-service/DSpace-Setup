#!/bin/bash
## 
## Full installation of DSpace-6.1 on empty Ubuntu Server 16.04 (via bwCloud)
##
## Author: Volodymyr Kushnarenko, Ulm University, Germany
## Changes for 6.2: Stefan Kombrink, Ulm University, Germany
## 
## Last update: 22.02.2018
##
## E-mail: volodymyr.kushnarenko[at]uni-ulm.de
## E-mail: stefan.kombrink[at]uni-ulm.de
## 
## DSpace installation manual: 
## - https://wiki.duraspace.org/display/DSDOC6x/Installing+DSpace
##
## Some examples/ideas are used from:
## - https://github.com/1science/docker-dspace
## - https://github.com/QuantumObject/docker-dspace
## - https://github.com/docker-library/postgres/blob/69bc540ecfffecce72d49fa7e4a46680350037f9/9.6/Dockerfile#L21-L24
## - https://github.com/docker-library/ruby/blob/74ee8aec9c17ea2134db8a8ef199cf092c829576/2.2/slim/Dockerfile#L26
## - Skripts of Kosmas Kaifel, Ulm University, Germany
##
## For INFO:
##
## see logs of tomcat: 
##        sudo -u dspace tail -f /opt/tomcat/logs/catalina.out | less
##

# DSpace version
DSVERSION="6.2"

echo "[DSpace-Install] Set local variables."

# Get directory where this script is running
CURDIR=$(/bin/pwd)
BASEDIR=$(dirname $0)
ABSPATH=$(readlink -f $0)
ABSDIR=$(dirname $ABSPATH)
CONFIGDIR=$ABSDIR/config 

ADMIN_EMAIL="katakombi@gmail.com"

echo "CONFIGDIR = $CONFIGDIR"

# Replace original IP-address in all configuraution files 
# to the real IP of the host
IP_ADDR_PLACEHOLDER="DSPACE_SERVER_IP_ADDRESS" 
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "IP_ADDR = $IP_ADDR"
find $CONFIGDIR -type f -exec sed -i -e "s/$IP_ADDR_PLACEHOLDER/$IP_ADDR/g" {} +

# Add HOSTNAME to "/etc/hosts" if still not presented there
echo "[DSpace-Install] Update /etc/hosts with a HOSTNAME."
CURR_HOSTNAME=$(/bin/hostname)
echo $CURR_HOSTNAME
if ! grep -q $CURR_HOSTNAME "/etc/hosts" ; then
   sudo sed -i -e "s/^127\.0\.0\.1 localhost.*$/& $CURR_HOSTNAME/" /etc/hosts
fi

# Configure Ubuntu

# Install needed programms
echo "[DSpace-Install] Install vim, curl, python."
sudo apt-get update
sudo apt-get install -y vim curl python

# Install locales, configure language 
apt-get install -y locales
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# JDK
echo "[DSpace-Install] Install JDK."
sudo apt-get install -y openjdk-8-jdk
echo "### JAVA info"; java -version; echo "### ---"

# maven
echo "[DSpace-Install] Install maven + ant."
sudo apt-get install -y maven
echo "### MAVEN info"; mvn -version; echo "###"

# git (for Mirage 2 theme)
echo "[DSpace-Install] Install git."
sudo apt-get install -y git
# Config git, extra for DSpace "Mirage-2" theme
sudo git config --global url."https://github.com/".insteadOf git://github.com/

# PostgreSQL
# Info: 
# "postrgesql-contrib" is included automatically (is needed for the
# 'pgcrypto' extension), but install int anyway
echo "[DSpace-Install] Install PostgreSQL."
sudo apt-get install -y postgresql
sudo apt-get install -y postgresql-contrib
sudo cp -p /etc/postgresql/9.5/main/pg_hba.conf /etc/postgresql/9.5/main/pg_hba.conf.orig
cat $CONFIGDIR/postgresql/pg_hba.conf | sudo tee /etc/postgresql/9.5/main/pg_hba.conf
sudo cp -p /etc/postgresql/9.5/main/postgresql.conf /etc/postgresql/9.5/main/postgresql.conf.orig
sudo sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/9.5/main/postgresql.conf
sudo /etc/init.d/postgresql restart
sleep 10

# Create user "dspace", with home directory and login (per default "-s /bin/bash" is activated),
# but without password
echo "[DSpace-Install] Create user 'dspace'"
sudo groupadd dspace
sudo useradd -m -g dspace dspace

# Configure PostgreSQL: add a 'dspace' user with a password 'dspace'
echo "[DSpace-Install] Configure PostgreSQL: add 'dspace' user to database, password is 'dspace'."
sudo createuser --username=postgres --no-superuser dspace
sudo psql --username=postgres -c "ALTER USER dspace WITH PASSWORD 'dspace';"
sudo createdb --username=postgres --owner=dspace --encoding=UNICODE dspace
sudo psql --username=postgres dspace -c "CREATE EXTENSION pgcrypto;"

# Tomcat
# IMPORTANT. tomcat 8.0.32 has a bug. Please install the upper version
# check the available version: apt-cache showpkg tomcat8
# 
# see: https://www.digitalocean.com/community/tutorials/how-to-install-apache-tomcat-8-on-ubuntu-16-04
#
# If you want extra ssl-encryption: https://www.digitalocean.com/community/tutorials/how-to-encrypt-tomcat-8-connections-with-apache-or-nginx-on-ubuntu-16-04
#
# ATTENTION: 
# - configure "/opt/tomcat/conf/server.xml" accordind to your JDK-version

echo "[DSpace-Install] Install Tomcat."
cd /tmp
wget http://archive.apache.org/dist/tomcat/tomcat-8/v8.0.44/bin/apache-tomcat-8.0.44.tar.gz
#wget http://www.gutscheine.org/mirror/apache/tomcat/tomcat-8/v8.0.44/bin/apache-tomcat-8.0.44.tar.gz
sudo mkdir /opt/tomcat
sudo tar xzvf apache-tomcat-8*tar.gz -C /opt/tomcat --strip-components=1
cd /opt/tomcat
sudo chgrp -R dspace /opt/tomcat
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R dspace webapps/ work/ temp/ logs/
sudo cp -p /etc/systemd/system/tomcat.service /etc/systemd/system/tomcat.service.orig
sudo cat $CONFIGDIR/tomcat/tomcat.service | sudo tee /etc/systemd/system/tomcat.service
sudo ufw allow 8080
sudo cp -p /opt/tomcat/conf/server.xml /opt/tomcat/conf/server.xml.orig
sudo cat $CONFIGDIR/tomcat/server.xml | sudo -u dspace tee /opt/tomcat/conf/server.xml
sudo systemctl daemon-reload
sleep 5
sudo systemctl start tomcat
sleep 10

# Download DSpace

echo "[DSpace-Install] Download DSpace."
cd /tmp
wget https://github.com/DSpace/DSpace/releases/download/dspace-$DSVERSION/dspace-$DSVERSION-src-release.tar.gz
sudo -u dspace tar -xzvf /tmp/dspace-$DSVERSION-src-release.tar.gz

# Create a local DSpace config file (before BUILD!!!)
# Please check 
# -> mail-configuration (per default: bwfdm.dspacetest@gmail.com)
#
sudo cat $CONFIGDIR/local.cfg | sudo -u dspace tee /tmp/dspace-$DSVERSION-src-release/dspace/config/local.cfg

# Create dspace directory
echo "[DSpace-Install] Create /dspace directory."
sudo mkdir /dspace
sudo chown dspace /dspace
sudo chgrp dspace /dspace

# Build dspace via maven as a "dspace" user
echo "[DSpace-Install] Build DSpace, with Mirage-2 theme."
sudo CONFIGDIR=$CONFIGDIR DSVERSION=$DSVERSION -i -u dspace -- sh -c 'cd /tmp/dspace-$DSVERSION-src-release; mvn -e -gs $CONFIGDIR/maven-settings.xml package -Dmirage2.on=true'
#sudo -u dspace mvn -e -gs $CONFIGDIR/maven-settings.xml package -Dmirage2.on=true

# Install DSpace (as a "dspace" user)
echo "[DSpace-Install] Install DSpace."
sudo DSVERSION=$DSVERSION -i -u dspace -- sh -c 'cd /tmp/dspace-$DSVERSION-src-release/dspace/target/dspace-installer; ant fresh_install'

# Make copy of the original config files of DSpace
#
# ATTENTION: look at first here in case of errors if the DSVERSION was changed from 6.1, 
#            especially compare "vimdiff /dspace/config/dspace.cfg /dspace/config/dspace.cfg.orig"
#            -> with new dspace-release (DSVERSION) could be used different variables/values in the config files
echo "[DSpace-Install] Create reserv copy of some DSpace-config files."
sudo cp -p /dspace/webapps/rest/WEB-INF/web.xml /dspace/webapps/rest/WEB-INF/web.xml.orig
sudo cp -p /dspace/config/modules/swordv2-server.cfg /dspace/config/modules/swordv2-server.cfg.orig
sudo cp -p /dspace/config/modules/sword-server.cfg /dspace/config/modules/sword-server.cfg.orig
sudo cp -p /dspace/config/dspace.cfg /dspace/config/dspace.cfg.orig
sudo cp -p /dspace/config/xmlui.xconf /dspace/config/xmlui.xconf.orig
sudo cp -p /dspace/config/item-submission.xml /dspace/config/item-submission.xml.orig
sudo cp -p /dspace/config/input-forms.xml /dspace/config/input-forms.xml.orig

# Replace config files
echo "[DSpace-Install] Replace DSpace-config files."
sudo cat $CONFIGDIR/rest/web.xml | sudo -u dspace tee /dspace/webapps/rest/WEB-INF/web.xml
sudo cat $CONFIGDIR/swordv2/swordv2-server.cfg | sudo -u dspace tee /dspace/config/modules/swordv2-server.cfg
sudo cat $CONFIGDIR/sword/sword-server.cfg | sudo -u dspace tee /dspace/config/modules/sword-server.cfg
sudo cat $CONFIGDIR/dspace.cfg | sudo -u dspace tee /dspace/config/dspace.cfg
sudo cat $CONFIGDIR/xmlui.xconf | sudo -u dspace tee /dspace/config/xmlui.xconf
sudo cat $CONFIGDIR/item-submission.xml | sudo -u dspace tee /dspace/config/item-submission.xml
sudo cat $CONFIGDIR/input-forms.xml | sudo -u dspace tee /dspace/config/input-forms.xml

# Replace email templates
echo "[DSpace-Install] Replace email-files."
sudo cp $CONFIGDIR/emails/* /dspace/config/emails/
sudo chown dspace /dspace/config/emails/*
sudo chgrp dspace /dspace/config/emails/*

# Copy all webapps from dspace to tomcat
echo "[DSpace-Install] Copy all webapps from /dspace/webapps to /tomcat/webapps"
sudo cp -R -p /dspace/webapps/* /opt/tomcat/webapps/

# Create DSpace administrator (interactive)
echo "[DSpace-Install] Create DSpace admininistrator user (use $ADMIN_EMAIL)."
sleep 5
sudo -u dspace /dspace/bin/dspace create-administrator

# Create DSpace initial communities/collections structure
sudo -u dspace /dspace/bin/dspace structure-builder -f $CONFIGDIR/DSpace_Import_Structure.xml -o /tmp/DSpace_Export_Structure.xml -e "$ADMIN_EMAIL"

# Configure dspace to show the last submittion
# see here: https://www.google.de/url?sa=t&rct=j&q=&esrc=s&source=web&cd=2&ved=0ahUKEwjm5sP-hfDUAhVBnBQKHUdODI0QFggvMAE&url=https%3A%2F%2Fjira.duraspace.org%2Fsecure%2Fattachment%2F10776%2Fconfigure.html&usg=AFQjCNECZU0fIxiEU41zfXWkzfZP6NirdQ&cad=rja

# Restart tomcat, to start the DSpace.
echo "[DSpace-Install] Restart Tomcat. Please wait a bit."
sudo systemctl restart tomcat
sleep 30
echo "######################################################"
echo "##"
echo "## DSpace is ready to work. Please use a web address:"
echo "##"
echo "## http://$IP_ADDR:8080/xmlui"
echo "##"
echo "######################################################"

### Enable services across reboots
sudo systemctl enable tomcat
sudo systemctl enable postgresql

### To give full access to DB and DSpace open ports 8080 (for http/https), IMCP (for ping) and 5432 for postgres
