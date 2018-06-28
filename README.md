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
* Stefan Kombrink, Ulm University, Germany / e-mail: stefan.kombrink[at]uni-ulm.de
* Volodymyr Kushnarenko, Ulm University, Germany / e-mail: volodymyr.kushnarenko[at]uni-ulm.de

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
Point your subdomain to the IP of the bwCloud VM. Here, we use: 

     demo-dspace.sara-service.org

### Clone this setup from git
```
ssh -A ubuntu@demo-dspace.sara-service.org
git clone git@git.uni-konstanz.de:sara/DSpace-Setup.git
```

### Enable history search (pgup,pgdn)
```
sudo sed -i.orig '41,+1s/^# //' /etc/inputrc
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

### Adapt dspace configuration to alternate host name

The prepared dspace configuration files use `devel-dspace.sara-service.org` in `local.cfg`. 
Replace it:
```
sudo sed -i 's/devel-dspace.sara-service.org/your-host-name/g' /dspace/config/local.cfg
sudo service tomcat restart
``` 

### Test your instance
Please visit a web page of the DSpace server: http://demo-dspace.sara-service.org:8080/xmlui .
You should be able to login with your admin account.

### Create an initial configuration
Now create a bunch of default users and a community/collection structure:
```
./dspace-init.sh
```

After that, we need to configure permissions. You will need to login as admin using the DSpace UI: 
* create a group called `Submitter`
* create a group called `SARA User`
* add `project-sara@uni-konstanz.de` to `Submitter` 
* add some users to `SARA User`
* for all collections: 
  * allow submissions for `Submitter`
  * if `Publikationen`: allow submissions for `SARA User`
  * if `(Workflow)`: add a role -> `Accept/Reject/Edit Metadata Step` -> add `SARA User`

`project-sara@uni-konstanz.de` is the dedicated SARA Service user and needs to have permissions to submit to any collection!

### Dump your active config
This is useful for debugging. DSpace has a `read` command to perform a sequence of commands in a single call but it does not work. Hence this solution which is very slow:
```
for prop in `cat ~/DSpace-Setup/config/local.cfg | awk '/^\S\S*\s*=/{if (split($0,a,"=")>0) {print a[1]}}'`; do 
    echo "$prop = "; sudo /dspace/bin/dspace dsprop -p $prop; echo; 
done
```

### Performance optimizations
Prepend
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

### Stability optimizations
Append `kernel.panic = 30` to `/etc/sysctl.conf`

```
sudo sysctl -p /etc/sysctl.conf
```

This will perform an automatic reboot 30 seconds after a kernel panic has occurred.

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
sudo a2enmod ssl proxy_ajp
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
        ProxyPass /xmlui ajp://localhost:8009/xmlui
        ProxyPassReverse /xmlui ajp://localhost:8009/xmlui

        ProxyPass /oai ajp://localhost:8009/oai
        ProxyPassReverse /oai ajp://localhost:8009/oai
        ProxyPass /rest ajp://localhost:8009/rest
        ProxyPassReverse /rest ajp://localhost:8009/rest
        ProxyPass /solr ajp://localhost:8009/solr
        ProxyPassReverse /solr ajp://localhost:8009/solr
        ProxyPass /swordv2 ajp://localhost:8009/swordv2

        ProxyPass / ajp://localhost:8009/xmlui
        ProxyPassReverse / ajp://localhost:8009/xmlui
```
Restart apache:
```
sudo service apache2 restart
```

Now you need to remove the local port 8080 and the http in the dspace config:
```
sudo sed -i 's#dspace.baseUrl = http://${dspace.hostname}:8080#dspace.baseUrl = https://${dspace.hostname}#' /dspace/config/local.cfg
sudo service tomcat restart
```

### Close ports

Now you can login the bwCloud user interface and disable the tomcat ports 8080/8443 for better security!
