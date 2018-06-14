#!/bin/bash

WORKDIR=$PWD
CONFIGDIR=$WORKDIR/config
SRCDIR=/tmp/DSpace-sources

echo "delete last src dump"
sudo rm -rf $SRCDIR && echo "OK"
echo "copy sources from git"
cp -r $WORKDIR/DSpace $SRCDIR 
cd $SRCDIR
echo "copy predefined configs"

# enable rest
# mail server cfg
# swordv2 cfg
# xmlui cfg

cp $CONFIGDIR/rest/web.xml               dspace-rest/src/main/webapp/WEB-INF/ && \
cp $CONFIGDIR/local.cfg                  dspace/config/ && \
cp $CONFIGDIR/swordv2/swordv2-server.cfg dspace/config/modules/ && \
cp $CONFIGDIR/dspace.cfg                 dspace/config/ && \
cp $CONFIGDIR/xmlui.xconf                dspace/config/ && \
cp $CONFIGDIR/input-forms.xml            dspace/config/ && \
cp $CONFIGDIR/item-submission.xml        dspace/config/

cd $WORKDIR
sudo chown -R dspace:dspace $SRCDIR && echo "OK"

echo "OK"

cd $SRCDIR && sudo -u dspace mvn -e package -Dmirage2.on=true && \
 sudo service tomcat stop && \
 cd /home/dspace/DSpace/dspace/target/dspace-installer/ && sudo -u dspace ant update && \
 sudo cp -R -p /dspace/webapps/* /opt/tomcat/webapps/ && \
 sudo -u dspace rm -rf /dspace/*bak*
