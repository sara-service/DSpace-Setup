# How to Install DSpace-6 on your virtual machine

This manual provides some steps, after that you can have installed and already
configured instance of the DSpace-6 server. The configuration includes:
* REST
* SWORD
* SWORDv2
* xmlui with Mirage-2 theme
* mailing functionality via "bwfdm.dspacetest@gmail.com"
 
This manual was tested with Ubuntu Server 16.04, the image was 
provided by bwCloud. The installation process can take up to 20 min, 
it works fully automatically up to the finishing part, where you will be 
prompted to create an admin user for DSpace.

Further DSpace-configuration can be done according the documentation:
https://wiki.duraspace.org/display/DSDOC6x/DSpace+6.x+Documentation

In case of questions please contact:
* Volodymyr Kushnarenko, Ulm University, Germany / e-mail: volodymyr.kushnarenko[at]uni-ulm.de
* Stefan Kombrink, Ulm University, Germany / e-mail: stefan.kombrink[at]uni-ulm.de

### Create a virtual machine (e.g. an instance on the bwCloud):

  * https://bwcloud.ruf.uni-freiburg.de
  * Compute -> Instances -> Start new insatance
  * Use "Ubuntu Server 16.04" image from the image
  * RAM be at least 4GB, better 8GB+
  * A default hard-drive capacity 10 GB is enough at least for the installation.

### In case you have an running instance already which you would like to replace

 * https://bwcloud.ruf.uni-freiburg.de
 * Compute -> Instances -> "dspace-6.2" -> [Rebuild Instance]
 * Use "Ubuntu Server 16.04" image from the image, Partitioning "Automatic"
 * The IP address will be unchanged!
   remove the host key from SSH known hosts:
   ssh-keygen -f "/home/stefan/.ssh/known_hosts" -R <BWCLOUD_IP>

### Setup subdomain
 * Point your subdomain to the <BWCLOUD_IP>. Here, we use: 

     demo-dspace.sara-service.org

### Clone this setup from git
```
ssh -A ubuntu@demo-dspace.sara-service.org
git clone git@git.uni-konstanz.de:sara/DSpace-Setup.git
```

### Start the installation script "dspace-install.sh". 
*FIXME this throws errors when not executed as root... for now use sudo*

```
cd ~/DSpace-Setup
sudo hostname demo-dspace.sara-service.org
sudo dpkg-reconfigure locales # generate en_EN@UTF8 and de_DE@UTF8, set en_EN as default
sudo ./dspace-install.sh
```

At the end of the installation you will be asked to create an admin user. 
Please type the mail address, name, surname and password.
It will send no email as the admin user is written to the DB directly.

When installation is finished, please visit a web page of the DSpace server:

`firefox http://demo-dspace.sara-service.org:8080/xmlui`

Login as the admin user and create a user using an email address where you have access to.
Equip this user with submit permissions. I used my gmail address...

### Rebuild dspace from sources (OPTIONAL)
`./dspace-checkout.sh`

then select your desired branch

`./dspace-rebuild.sh`

### Install letsencrypt, create and configure SSL cert
```
sudo apt-get install letsencrypt
mkdir -p /var/www/html
sudo letsencrypt certonly --webroot -w /var/www/html -d bwcloud-vm65.rz.uni-ulm.de
sudo ls /etc/letsencrypt/live/bwcloud-vm65.rz.uni-ulm.de
# cert.pem  chain.pem  fullchain.pem  privkey.pem
# as root:
openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out fullchain_and_key.p12 -name tomcat
keytool -importkeystore -deststorepass dspace -destkeypass dspace -destkeystore /dspace/config/dspace.jks -srckeystore fullchain_and_key.p12 -srcstoretype PKCS12 -srcstorepass dspace -alias tomcat

sudo vim /opt/tomcat/conf/server.xml # disable http Connector on 8080
# insert https connector on 8080 instead like so:
<Connector port="8080" protocol="org.apache.coyote.http11.Http11Protocol" URIEncoding="UTF-8" maxThreads="150" SSLEnabled="true" scheme="https" secure="true" clientAuth="false" sslProtocol="TLS" keystoreFile="/dspace/config/dspace.jks" keystorePass="dspace" keyAlias="tomcat" keyPass="dspace"/>

sudo vim /dspace/config/modules/swordv2-server.cfg # fix swordv2-server.url, swordv2-server.{servicedocument,collection}.url to match the host name of the SSL certificate

sudo service tomcat restart
```

### TODO: setup automatic renewal script...http -> httpd redirect...
`sudo sh -c 'echo "15 3 * * * root /usr/bin/letsencrypt renew && service apache2 reload" > /etc/cron.d/letsencrypt'`

prepend also:
```
#<VirtualHost *:80>
#    RewriteEngine On
#    RewriteCond %{HTTPS} off
#    RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}
#</VirtualHost>
```
