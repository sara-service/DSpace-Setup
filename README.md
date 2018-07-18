# How to Install DSpace-6 on bwCloud Scope

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

It is based on the "Ubuntu Server 18.04 minimal image" and was performed in a bwCloud SCOPE VM. 
The main installation script can take up to 1/2hr, but it runs fully 
automated until the end, where you will be prompted to create an admin user for DSpace.
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

  * https://portal.bwcloud.org
  * Compute -> Instances -> Start new instance
  * Use "Ubuntu Server 18.04 Minimal" image
  * Use flavor "m1.medium" with 12GB disk space and 4GB RAM
  * Enable port 8080 egress/ingress by creating and enabling a new Security Group 'tomcat'

### In case you have an running instance already which you would like to replace

 * https://bwcloud.ruf.uni-freiburg.de
 * Compute -> Instances -> "dspace-6.2" -> [Rebuild Instance]
 * You might need to remove your old SSH key from ~/.ssh/known_hosts

### Setup subdomain
Point your subdomain to the IP of the bwCloud VM. Here, we use: 

     vm-152-020.bwcloud.uni-ulm.de

```
ssh -A ubuntu@demo-dspace.sara-service.org
```

## Prerequisites
```
# Enable history search (pgdn/pgup)
sudo sed -i.orig '41,+1s/^# //' /etc/inputrc

# Adapt host name
sudo hostname demo-dspace.sara-service.org

# Fetch latest updates
sudo apt update
sudo apt upgrade

# Install some packages
sudo apt install vim git locales

# Fix locales
sudo locale-gen de_DE.UTF-8 en_US.UTF-8
sudo localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Fix timezone
sudo apt-get install tzdata (8, 7 for /Europe/Berlin)

# Clone this setup from git
git clone git@git.uni-konstanz.de:sara/DSpace-Setup.git
```

## Installation

### Postgres

```
sudo apt-mark hold openjdk-11-jre-headless
sudo apt-get -y install python openjdk-8-jdk maven ant postgresql postgresql-contrib curl wget

systemctl start postgresql
sudo groupadd dspace
sudo useradd -m -g dspace dspace
sudo -u postgres createuser --no-superuser dspace
sudo -u postgres psql -c "ALTER USER dspace WITH PASSWORD 'dspace';"
sudo -u postgres createdb --owner=dspace --encoding=UNICODE dspace
sudo -u postgres psql dspace -c "CREATE EXTENSION pgcrypto;"
```

### Tomcat

```
wget http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.32/bin/apache-tomcat-8.5.32.tar.gz -O /tmp/tomcat.tgz
sudo mkdir /opt/tomcat
sudo tar xzvf /tmp/tomcat.tgz -C /opt/tomcat --strip-components=1
sudo chown -R dspace.dspace /opt/tomcat
sudo cp /home/ubuntu/DSpace-Setup/config/tomcat/tomcat.service /etc/systemd/system/tomcat.service
sudo cp /home/ubuntu/DSpace-Setup/config/tomcat/server.xml /opt/tomcat/conf/server.xml
sudo systemctl daemon-reload
sudo systemctl start tomcat
```

Now you should be able to find your tomcat running at http://vm-152-020.bwcloud.uni-ulm.de:8080

### DSpace

```
wget https://github.com/DSpace/DSpace/releases/download/dspace-6.3/dspace-6.3-src-release.tar.gz -O /tmp/dspace.tgz
sudo -u dspace tar -xzvf /tmp/dspace.tgz -C /tmp

sudo mkdir /dspace
sudo chown dspace /dspace
sudo chgrp dspace /dspace

cd /tmp/dspace-6.3-src-release
sudo -u dspace mvn -e package -Dmirage2.on=true
# FIXME build error in mirage2 module, log is in: /tmp/dspace-6.3-src-release/dspace/modules/xmlui-mirage2/target/themes/Mirage2/npm-debug.log
sudo -i -u dspace -- sh -c 'cd /tmp/dspace-6.3-src-release/dspace/target/dspace-installer; ant fresh_install'

# Create dspace admin (non-interactive)
sudo -u dspace /dspace/bin/dspace create-administrator
```

At the end of the installation you will be asked to create an admin user. 
Please type the mail address, name, surname and password.
It will send no email as the admin user is written to the DB directly.

### Apply presets

```
# Enable REST
sudo cat /home/ubuntu/DSpace-Setup/config/rest/web.xml | sudo -u dspace tee /dspace/webapps/rest/WEB-INF/web.xml
# Enable Mirage2 Themes
sudo cat /home/ubuntu/DSpace-Setup/config/xmlui.xconf | sudo -u dspace tee /dspace/config/xmlui.xconf
# Enable customized item submission form
sudo cat /home/ubuntu/DSpace-Setup/config/item-submission.xml | sudo -u dspace tee /dspace/config/item-submission.xml
sudo cat /home/ubuntu/DSpace-Setup/config/input-forms.xml | sudo -u dspace tee /dspace/config/input-forms.xml
# Copy email templates
sudo cp /home/ubuntu/DSpace-Setup/config/emails/* /dspace/config/emails/
sudo chown -R dspace /dspace/config/emails
sudo chgrp -R dspace /dspace/config/emails

# Copy all webapps from dspace to tomcat
sudo cp -R -p /dspace/webapps/* /opt/tomcat/webapps/

# Apply custom local configurations
sudo cat /home/ubuntu/DSpace-Setup/config/local.cfg | sed 's/devel-dspace.sara-service.org/'$(hostname)'/g' | sudo -u dspace tee /dspace/config/local.cfg

sudo systemctl restart tomcat
sudo systemctl enable postgresql
sudo systemctl enable tomcat
```

### Test your instance
Please visit a web page of the DSpace server: http://$(hostname):8080/xmlui
You should be able to login with your admin account.

## Configuration

### Create an initial configuration
Now create a bunch of default users and a community/collection structure:
```
./dspace-init.sh
```

After that, we need to configure permissions. You will need to login as admin using the DSpace UI: 
* create a group called `Submitter` and add `project-sara@uni-konstanz.de`<sup>1</sup>
* create a group called `SARA User` and add some users. Exclude `demo-user-noaccess@sara-service.org`.
* create a group called `Reviewer` and add just a few selected power users
* for each collection: 
  * allow submissions for `Submitter` <sup>2</sup>
  * if `Publikationen`: allow submissions for `SARA User`
  * if `(reviewed)`: add a role -> `Accept/Reject/Edit Metadata Step` -> add `Reviewer`

<sup>1</sup>this is the dedicated SARA Service user and needs to have permissions to submit to any collection a SARA user has access to!

<sup>2</sup>you may exclude a few collections but SARA will not be able to submit to them even when a SARA user owns submit rights on them!

### Validate rest/swordv2 functionality (HTTP)

```
DSPACE_SERVER="$(hostname):8080"

curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/hierarchy | python -m json.tool
# This should dump the bibliography structure. In case of `No JSON object could be decoded` something is wrong.

SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"
USER1="stefan.kombrink@uni-ulm.de" # set existing SARA User
USER2="demo-user-noaccess@sara-service.org" # set existing user without any permissions
USER3="daniel.duesentrieb@uni-entenhausen.de" # set nonexisting user

curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads TermsOfServices for all available collections
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads empty service document
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
USER2="demo-user-noaccess@sara-service.org" # set existing user without any permissions
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

### Securing SwordV2 Interface
Here we use DSpace with SwordV2 and on-behalf-of enabled. Without further configuration the following scenarios are possible:
* A registered user can submit items on-behalf-of others users if he knows their email addresses used for registration. Items can be submitted to collections where both users have submit rights to.
* In case the SARA Service users name and password get leaked even no registration is needed.
* The interface can be flooded with automated requests leading to high server load.

We propose two solutions to prevent these scenarios:

1) Block requests except for SARA Service in Apache

Do `a2enmod authn_anon` and replace `ProxyPass /swordv2 ajp://localhost:8009/swordv2` by

```apache
<Location /swordv2>
    ProxyPass ajp://localhost:8009/swordv2
    # allow only whitelisted usernames
    AuthType Basic
    AuthName "SWORD v2 endpoint"
    Require user project-sara@uni-konstanz.de
    # but don't actually check the password:
    # DSpace does that anyway, and storing passwords twice is silly
    AuthBasicProvider anon
    Anonymous *
</Location>
```

This has Apache do authZ (the username whitelisting) only, and lets DSpace do authN (checking the password)
so the password doesn't have to be kept in sync between Apache and DSpace config.

If you need to whitelist extra users, add them to the end of the `Require user` line.
To whitelist entire hosts (not recommended except for 127.0.0.1), add something like
`Require host 127.0.0.1` to the `<Location>` block
(`Require` rules are implicitly ORed unless they are in a `<RequireAll>` block).

2) Patch Source for DSpace & rebuild
We provide two patches that restrict the on-Behalf-of submission on a list of well-defined users.

https://github.com/54r4/DSpace/tree/dspace-6.3_OboFixVariant1
https://github.com/54r4/DSpace/tree/dspace-6.3_OboFixVariant2

*TODO Source build and install*

It is preferrable to adapt 1) or 1) and 2).

### Free up disk space
```
du -hs /tmp/dspace-6.?-src-release
#4,2G	dspace-6.3-src-release
sudo rm -rf /tmp/dspace-6.?-src-release
```

### Close ports

Now you can login the bwCloud user interface and disable the tomcat ports 8080/8443 for better security!
Also, in Tomcat's `server.xml`, change all `<Connector>`s to add `address="127.0.0.1"`. Better save than sorry.
