# How to Install DSpace5 on bwCloud Scope

## Intro

This manual provides a step-by-step setup for a fully configured instance of DSpace5 server. 
The final instance can be used as institutional repository to receive automated deposit from SARA Service via swordv2.

Contents:
* SWORDv2
* xmlui with Atmire Mirage theme
* SMTP mailing functionality
* Initial configuration (Groups, Users, Communities, Collections, Permissions...)

It is based on the "Ubuntu Server 18.04 image" and was performed in a bwCloud SCOPE VM. 
It is advised to walk through this manual without interruptions or intermediate reboots.

Further reading:
https://wiki.duraspace.org/display/DSDOC5x/DSpace+5.x+Documentation

About SARA:
https://sara-service.org

In case of questions please contact:
* Stefan Kombrink, Ulm University, Germany / e-mail: stefan.kombrink[at]uni-ulm.de
* Volodymyr Kushnarenko, Ulm University, Germany / e-mail: volodymyr.kushnarenko[at]uni-ulm.de
* Franziska Rapp, Ulm University, Germany / e-mail: franziska.rapp[at]uni-ulm.de

## Setup 

### Create a virtual machine (e.g. an instance on the bwCloud):

  * https://portal.bw-cloud.org
  * Compute -> Instances -> Start new instance
  * Use "Ubuntu Server 18.04" image
  * Use flavor "m1.medium" with 12GB disk space and 4GB RAM
  * Enable port 8080 egress/ingress by creating and enabling a new Security Group 'tomcat'
  * Enable port 80/443 egress/ingress by creating and enabling a new Security Group 'apache'

### In case you have an running instance already which you would like to replace

 * https://portal.bw-cloud.org
 * Compute -> Instances -> "dspace5" -> [Rebuild Instance]
 * You might need to remove your old SSH key from ~/.ssh/known_hosts

### Connect to the machine
```bash
ssh ubuntu@dspace5-test.sara-service.org
```

## Fix hostname
```bash
# Enable history search (pgdn/pgup)
sudo sed -i.orig '41,+1s/^# //' /etc/inputrc

# Adapt host name
sudo hostname dspace5-test.sara-service.org

# Log off to apply new host name
exit
```

## Prerequisites
```bash
ssh ubuntu@dspace5-test.sara-service.org

# Fetch latest updates
sudo apt-get update

# Install some important dependencies
sudo apt-get -y install vim git locales rsync

# Fix locales
sudo locale-gen de_DE.UTF-8 en_US.UTF-8
sudo localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Fix timezone
sudo sh -c 'echo "Europe/Berlin" > /etc/timezone'
sudo DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get install tzdata

# Upgrade all packages
sudo apt-get -y upgrade
```
```bash
# Clone this setup from git
git clone -b Tuebingen https://git.uni-konstanz.de/sara/DSpace-Setup.git
sudo cp ~/DSpace-Setup/config/vimrc.local /etc/vim/vimrc.local
```

## Installation

```bash
sudo apt-mark hold openjdk-11-jre-headless
sudo apt-get -y install python openjdk-8-jdk maven ant postgresql postgresql-contrib curl wget haveged ruby-compass ruby-sass
```
### Postgres
```bash
sudo systemctl start postgresql
sudo -u postgres createuser --no-superuser dspace
sudo -u postgres psql -c "ALTER USER dspace WITH PASSWORD 'dspace';"
sudo -u postgres createdb --owner=dspace --encoding=UNICODE dspace
sudo -u postgres psql dspace -c "CREATE EXTENSION pgcrypto;"
```

### Tomcat
```bash
sudo groupadd dspace
sudo useradd -m -g dspace dspace
wget http://archive.apache.org/dist/tomcat/tomcat-9/v9.0.16/bin/apache-tomcat-9.0.16.tar.gz -O /tmp/tomcat.tgz
sudo mkdir /opt/tomcat
sudo tar -xzvf /tmp/tomcat.tgz -C /opt/tomcat --strip-components=1
sudo cp /home/ubuntu/DSpace-Setup/config/tomcat/tomcat.service /etc/systemd/system/tomcat.service
sudo cp /home/ubuntu/DSpace-Setup/config/tomcat/server.xml /opt/tomcat/conf/server.xml
sudo chown -R dspace.dspace /opt/tomcat
sudo systemctl daemon-reload
sudo systemctl start tomcat
```

Now you should be able to find your tomcat running at http://dspace5-test.sara-service.org:8080

### DSpace

```bash
wget https://github.com/DSpace/DSpace/releases/download/dspace-5.10/dspace-5.10-src-release.tar.gz -O /tmp/dspace-src.tgz
mkdir -p /tmp/dspace-src
tar -xzvf /tmp/dspace-src.tgz -C /tmp/dspace-src --strip-components=1
sudo chown -R dspace:dspace /tmp/dspace-src 
```

```bash
sudo mkdir /dspace
sudo chown dspace:dspace /dspace
```
```bash
# fix abdera dependency or else swordv2 will be broken
cd /tmp/dspace-src && sed -i.orig 's/1.1.1/1.1.3/' dspace-swordv2/pom.xml
sudo -H -u dspace sh -c 'cd /tmp/dspace-src && mvn -e clean package'
sudo -H -u dspace -- sh -c 'cd /tmp/dspace-src/dspace/target/dspace-installer; ant fresh_install'
```
```bash
# export admins email = it is used by the script to create the bibliography, too
export ADMIN_EMAIL="katakombi@gmail.com"
# Create dspace admin
sudo -u dspace /dspace/bin/dspace create-administrator -e $ADMIN_EMAIL -f "kata" -l "kombi" -p "secret" -c en
```

### Configure SWordV2

```bash
# Customized dspace.cfg / swordv2-server.cgf
cat /home/ubuntu/DSpace-Setup/config/dspace.cfg | sed 's/DSPACE_HOSTNAME/'$(hostname)':8080/' | sudo -u dspace tee /dspace/config/dspace.cfg
cat /home/ubuntu/DSpace-Setup/config/swordv2/swordv2-server.cfg  | sed 's/DSPACE_HOSTNAME/'$(hostname)':8080/' | sudo -u dspace tee /dspace/config/modules/swordv2-server.cfg

# Copy all webapps from dspace to tomcat
sudo rsync -a -v -z --delete --force /dspace/webapps/ /opt/tomcat/webapps

# Restart tomcat and enable services
sudo service tomcat restart
sudo systemctl enable postgresql
sudo systemctl enable tomcat
```

### Test your instance
You should be able to login with your admin account: http://dspace5-test.sara-service.org:8080/xmlui 

## Configuration

### Create an initial configuration
Now create a bunch of default users and a community/collection structure:
```bash
cd /home/ubuntu/DSpace-Setup && ./dspace-init.sh
```
**TODO: automate this!**

After that, we need to configure permissions. You will need to login as admin using the DSpace UI: 
* create a group called `SARA User` and add `project-sara@uni-konstanz.de`<sup>1</sup>
* create a group called `DSpace User` and add some users. Exclude `demo-user-noaccess@sara-service.org`.
* create a group called `Reviewer` and add just a few selected power users
* for each collection: 
  * allow submissions for `DSpace User`
  * if `Research Data`: allow submissions for `SARA User`
  * Add a role -> `Accept/Reject/Edit Metadata Step` -> add `Reviewer`

<sup>1</sup>this is the dedicated SARA Service user and needs to have permissions to submit to any collection a SARA user has access to!

### Validate Swordv2 functionality (HTTP)

```bash
DSPACE_SERVER="$(hostname):8080"

SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"
USER1="stefan.kombrink@uni-ulm.de" # set existing SARA User
USER2="demo-user-noaccess@sara-service.org" # set existing user without any permissions
USER3="daniel.duesentrieb@uni-entenhausen.de" # set nonexisting user

curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads first level of bibliography
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads first level of bibliography
curl -H "on-behalf-of: $USER3" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => HTML Error Status 403: Forbidden
```

### Apply presets

```bash
# Stop tomcat
sudo systemctl stop tomcat

# Apply customized item submission form
cat /home/ubuntu/DSpace-Setup/config/item-submission.xml     | sudo -u dspace sh -c 'cat > /dspace/config/item-submission.xml'
cat /home/ubuntu/DSpace-Setup/config/input-forms.xml         | sudo -u dspace sh -c 'cat > /dspace/config/input-forms.xml'
# Custom item view
cat /home/ubuntu/DSpace-Setup/config/xmlui/item-view.xsl     | sudo -u dspace sh -c 'cat > /dspace/webapps/xmlui/themes/Mirage/lib/xsl/aspect/artifactbrowser/item-view.xsl'
# Custom messages
cat /home/ubuntu/DSpace-Setup/config/xmlui/messages.xml      | sudo -u dspace sh -c 'cat > /dspace/webapps/xmlui/i18n/messages.xml'
cat /home/ubuntu/DSpace-Setup/config/xmlui/messages_de.xml   | sudo -u dspace sh -c 'cat > /dspace/webapps/xmlui/i18n/messages_de.xml'
# Custom landing page
cat /home/ubuntu/DSpace-Setup/config/xmlui/news-xmlui.xml    | sudo -u dspace sh -c 'cat > /dspace/config/news-xmlui.xml'
# Custom thumbnails
cat /home/ubuntu/DSpace-Setup/config/xmlui/Logo_SARA_RGB.png | sudo -u dspace sh -c 'cat > /dspace/webapps/xmlui/themes/Mirage/images/Logo_SARA_RGB.png'
# Custom icons
cat /home/ubuntu/DSpace-Setup/config/xmlui/arrow.png         | sudo -u dspace sh -c 'cat > /dspace/webapps/xmlui/themes/Mirage/images/arrow.png'
# Copy email templates
sudo cp /home/ubuntu/DSpace-Setup/config/emails/* /dspace/config/emails/
sudo chown -R dspace /dspace/config/emails
sudo chgrp -R dspace /dspace/config/emails
# Apply default deposit license
cat /home/ubuntu/DSpace-Setup/config/default.license | sudo -u dspace tee /dspace/config/default.license

# Copy all webapps from dspace to tomcat
sudo rsync -a -v -z --delete --force /dspace/webapps/ /opt/tomcat/webapps

sudo systemctl start tomcat
```

### Install apache httpd
```bash
sudo apt-get -y install apache2
sudo a2enmod ssl proxy proxy_http proxy_ajp
sudo systemctl restart apache2
```

Now you will see the standard apache index page: http://dspace5-test.sara-service.org/

### Install letsencrypt, create and configure SSL cert
```bash
sudo apt -y install python3-certbot-apache
sudo systemctl stop apache2
sudo letsencrypt --authenticator standalone --installer apache --domains $(hostname)
```
Choose `secure redirect` . Now you should be redirected to access via https only: http://dspace5-test.sara-service.org/

### Configure apache httpd
First stop tomcat:
```bash
sudo systemctl stop tomcat
```
Then append the following section to your virtual server config under `/etc/apache2/sites-enabled/000-default-le-ssl.conf` :
```bash
sudo vim /etc/apache2/sites-enabled/000-default-le-ssl.conf
```
```apache
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
```bash
sudo systemctl restart apache2
```

### Update DSpace local.cfg

Now you need to remove the local port 8080 and the http in the dspace config:
```bash
sudo sed -i 's/http:\/\/'"$(hostname):8080"'/https:\/\/'$(hostname)'/' /dspace/config/dspace.cfg /dspace/config/modules/swordv2-server.cfg
sudo systemctl restart tomcat
```

### Validate Swordv2 functionality (HTTPS)

```bash
DSPACE_SERVER="https://$(hostname)"

SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"
USER1="stefan.kombrink@uni-ulm.de" # set existing SARA User
USER2="demo-user-noaccess@sara-service.org" # set existing user without any permissions
USER3="daniel.duesentrieb@uni-entenhausen.de" # set nonexisting user

curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads first level of bibliography
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads first level of bibliography
curl -H "on-behalf-of: $USER3" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => HTML Error Status 403: Forbidden
```

## Final steps

### Cron job for cert renewal
*untested*
```
sudo cat << EOF > /etc/cron.d/letsencrypt
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && /etc/init.d/apache2 stop && letsencrypt renew && /etc/init.d/apache2 start
EOF
```

### Stability optimizations
Append `kernel.panic = 30` to `/etc/sysctl.conf`

```bash
sudo vim /etc/sysctl.conf
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

Do `sudo a2enmod authn_anon` and replace `ProxyPass /swordv2 ajp://localhost:8009/swordv2` by the following code snippet:

```bash
sudo vim /etc/apache2/sites-enabled/000-default-le-ssl.conf
```

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

**IMPORTANT: double check that the ProxyPass and ProxyPassReverse with `/xmlui` occur at the very end or else the `/swordv2` rule is not going to be applied!**
**Best thing is to re-test SwordV2 using the curl commands from the previous sections!**

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

It is preferrable to adapt 1) or 1) and 2).

## TODO
* add REST
* fix order of tomcat / apache2 service starts
* add mirage2 build fix

### Free up disk space
```bash
du -hs /tmp/dspace-src
#4,2G	dspace-src
sudo rm -rf /tmp/dspace-src
```

### Close ports

Now you can login the bwCloud user interface and disable the tomcat ports 8080/8443 for better security!
Also, in Tomcat's `server.xml`, change all `<Connector>`s to add `address="127.0.0.1"`. Better save than sorry.

### Troubleshooting 

* TomCat8 needs Java 1.8 and JDK8
* DSpace 5.9 and 5.10 have broken RESTv2, you need to apply a fix to pull abdera version 1.1.3 instead of 1.1.1 in the pom.xml. See https://github.com/DSpace/DSpace/pull/2271
