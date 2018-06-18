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
   ssh-keygen -f "/home/stefan/.ssh/known_hosts" -R BWCLOUD_IP

### Setup subdomain
 * Point your subdomain to the `BWCLOUD_IP`. Here, we use: 

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
sudo apt update
sudo apt upgrade
sudo ./dspace-install.sh
```

At the end of the installation you will be asked to create an admin user. 
Please type the mail address, name, surname and password.
It will send no email as the admin user is written to the DB directly.

When installation is finished, please visit a web page of the DSpace server: http://demo-dspace.sara-service.org:8080/xmlui

Login as the admin user and create a user using an email address where you have access to.
Equip this user with submit permissions. I used my gmail address...

### Performance optimizations
Append
```
CATALINA_OPTS="-Xmx2048M -Xms2048M  -XX:MaxPermSize=512m -XX:+UseG1GC -Dfile.encoding=UTF-8"
```
in
```
/opt/tomcat/bin/catalina.sh
```

Restart TomCat
```
sudo service tomcat restart
```

### Free up disk space
```
du -hs /tmp/dspace-6.2-src-release
#4,2G	dspace-6.2-src-release
sudo rm -rf /tmp/dspace-6.2-src-release
```

### Rebuild dspace from sources (OPTIONAL) - TODO test it!
```
./dspace-checkout.sh
```
then select your desired branch
```
./dspace-rebuild.sh
```
### Install and configure apache httpd
```
sudo apt-get install apache2
sudo a2enmod ssl proxy_http
sudo service apache2 restart
```

Now you will see the standard apache index page: http://demo-dspace.sara-service.org

### Install letsencrypt, create and configure SSL cert
```
sudo apt-get install letsencrypt python-letsencrypt-apache
sudo service apache2 stop
sudo letsencrypt --authenticator standalone --installer apache --domains demo-dspace.sara-service.org
```
Choose `secure redirect` . Now you should be able to access via https only: http://demo-dspace.sara-service.org

### Adapt dspace config
Append the following section to your virtual server config under `/etc/apache2/sites-enabled/000-default-le-ssl.conf` :
```
        ProxyPass /xmlui http://localhost:8080/xmlui
        ProxyPassReverse /xmlui http://localhost:8080/xmlui

        ProxyPass /oai http://localhost:8080/oai
        ProxyPassReverse /oai http://localhost:8080/oai
        ProxyPass /rest http://localhost:8080/rest
        ProxyPassReverse /rest http://localhost:8080/rest
        ProxyPass /solr http://localhost:8080/solr
        ProxyPassReverse /solr http://localhost:8080/solr
        ProxyPass /swordv2 http://localhost:8080/swordv2

        #ProxyPass /oai !
        #ProxyPass /rest !
        #ProxyPass /swordv2 !
        #ProxyPass /solr !
        #ProxyPass /robots.txt !

        #RewriteRule /oai - [L]
        #RewriteRule /rest - [L]
        #RewriteRule /swordv2 - [L]
        #RewriteRule /solr - [L]
        #RewriteRule /query - [L]

        RewriteCond %{SERVER_NAME}  !^demo-dspace.sara-service.org [NC]
        RewriteRule ^(.*)$        https://demo-dspace.sara-service.org [last,redirect=301]

        ProxyPass / http://localhost:8080/xmlui
        ProxyPassReverse / http://localhost:8080/xmlui
```
Restart apache:
```
sudo service apache2 restart
```

Now you need to remove the local ports in the dspace config. Replace 
```
http://demo-dspace.sara-service.org:8080
``` 
by 
```
http://demo-dspace.sara-service.org
``` 
in
```
/dspace/config/{local.cfg,dspace.cfg,modules/swordv2-server.cfg}
```
this should be 6 occurences altogether.
```
sudo service tomcat restart
```

### Close ports

Now you can login the bwCloud user interface and disable the port settings for 8080/8443 for better security!
