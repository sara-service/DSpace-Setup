# How to Install DSpace-6 on your virtual machine

## Intro

This manual provides a step-by-step setup for a fully
configured instance of DSpace6 server. 
The final instance can be used as institutional repository to receive automated deposit from SARA Service via swordv2.

Contents:
* REST
* SWORDv2
* xmlui with Mirage-2 theme
* SMTP mailing functionality
* Initial configuration (Groups, Users, Communities, Collections, Permissions...)

It is based on Ubuntu Server 16.04 and was performed in a bwCloud VM. 
The main installation script can take up to 1/2hr, but it runs fully 
automated til the end, where you will be prompted to create an admin user for DSpace.
It is advised to walk through this manual without interruptions or intermediate reboots.

Further reading:
https://wiki.duraspace.org/display/DSDOC6x/DSpace+6.x+Documentation

About SARA:
https://sara-service.org

In case of questions please contact:
* Stefan Kombrink, Ulm University, Germany / e-mail: stefan.kombrink[at]uni-ulm.de
* Volodymyr Kushnarenko, Ulm University, Germany / e-mail: volodymyr.kushnarenko[at]uni-ulm.de

## Setup 

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

### Adapt dspace configuration to an alternate host name

The prepared dspace configuration files use `devel-dspace.sara-service.org` in `local.cfg`. 
Replace it:
```
sudo sed -i 's/devel-dspace.sara-service.org/your-host-name/g' /dspace/config/local.cfg
sudo service tomcat restart
``` 

### Test your instance
Please visit a web page of the DSpace server: http://demo-dspace.sara-service.org:8080/xmlui .
You should be able to login with your admin account.

## Configuration

### Create an initial configuration
Now create a bunch of default users and a community/collection structure:
```
./dspace-init.sh
```

After that, we need to configure permissions. You will need to login as admin using the DSpace UI: 
* create a group called `Submitter` and add `project-sara@uni-konstanz.de` (*)
* create a group called `SARA User` and add some users
* create a group called `Reviewer` and add just a few selected power users
* for each collection: 
  * allow submissions for `Submitter` (**)
  * if `Publikationen`: allow submissions for `SARA User`
  * if `(reviewed)`: add a role -> `Accept/Reject/Edit Metadata Step` -> add `Reviewer`

(*) `project-sara@uni-konstanz.de` is the dedicated SARA Service user and needs to have permissions to submit to any collection a SARA user has access to!
(**) you may exclude a few collections but SARA will not be able to submit to them even when a SARA user owns submit rights on them!

### Validate rest/swordv2 functionality (HTTP)

```
DSPACE_SERVER="$(hostname):8080"

curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/hierarchy | python -m json.tool
# This should dump the bibliography structure. In case of `No JSON object could be decoded` something is wrong.

SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"
USER1="stefan.kombrink@uni-ulm.de" # set existing SARA User
USER2="demo-user@sara-service.org" # set existing user without any permissions
USER3="daniel.duesentrieb@uni-entenhausen.de" # set nonexisting user

curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads TermsOfServices for all available collections
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads TermsOfServices for all collections where submissions are allowed
curl -H "on-behalf-of: $USER3" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => HTML Error Status 403: Forbidden
```

### Install apache httpd
```
sudo apt-get install apache2
sudo a2enmod ssl proxy proxy_http proxy_ajp
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

### Configure apache httpd
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

### Update DSpace local.cfg

Now you need to remove the local port 8080 and the http in the dspace config:
```
sudo sed -i 's#dspace.baseUrl = http://${dspace.hostname}:8080#dspace.baseUrl = https://${dspace.hostname}#' /dspace/config/local.cfg
sudo service tomcat restart
```

### Validate rest/swordv2 functionality (HTTPS)

```
DSPACE_SERVER="https://$(hostname)"

curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/hierarchy | python -m json.tool
# This should dump the bibliography structure. In case of `No JSON object could be decoded` something is wrong.

SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"
USER1="stefan.kombrink@uni-ulm.de" # set existing SARA User
USER2="demo-user@sara-service.org" # set existing user without any permissions
USER3="daniel.duesentrieb@uni-entenhausen.de" # set nonexisting user

curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads TermsOfServices for all available collections
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads empty service document
curl -H "on-behalf-of: $USER3" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => HTML Error Status 403: Forbidden
```

## Final steps

### Stability optimizations
Append `kernel.panic = 30` to `/etc/sysctl.conf`

```
sudo sysctl -p /etc/sysctl.conf
```

This will perform an automatic reboot 30 seconds after a kernel panic has occurred.

### Free up disk space
```
du -hs /tmp/dspace-6.?-src-release
#4,2G	dspace-6.3-src-release
sudo rm -rf /tmp/dspace-6.?-src-release
```

## Misc

### Close ports

Now you can login the bwCloud user interface and disable the tomcat ports 8080/8443 for better security!

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

### Rebuild dspace from sources (OPTIONAL) - TODO test it!
```
./dspace-checkout.sh
```
then select your desired branch
```
./dspace-rebuild.sh
```