#!/bin/bash

WORKDIR=$PWD
CONFIGDIR=$WORKDIR/config
SRCDIR=/home/dspace/DSpace-Sources

echo "delete last src dump"
sudo -u dspace rm -rf $SRCDIR && echo "OK"
echo "copy sources from git"
sudo -u dspace cp -r $WORKDIR/DSpace $SRCDIR 
cd $SRCDIR
echo "copy predefined configs"

# enable rest
# mail server cfg
# swordv2 cfg
# xmlui cfg

sudo -u dspace sh -c "
cat $CONFIGDIR/rest/web.xml               > dspace-rest/src/main/webapp/WEB-INF/web.xml && \
cat $CONFIGDIR/local.cfg                  > dspace/config/local.cfg && \
cat $CONFIGDIR/swordv2/swordv2-server.cfg > dspace/config/modules/swordv2-server.cfg && \
cat $CONFIGDIR/dspace.cfg                 > dspace/config/dspace.cfg && \
cat $CONFIGDIR/xmlui.xconf                > dspace/config/xmlui.xconf && \
cat $CONFIGDIR/input-forms.xml            > dspace/config/input-forms.xml && \
cat $CONFIGDIR/item-submission.xml        > dspace/config/item-submission.xml
"

cd $WORKDIR

cd $SRCDIR && sudo -u dspace mvn -e package -Dmirage2.on=true && \
 sudo service tomcat stop && \
 cd /home/dspace/DSpace/dspace/target/dspace-installer/ && sudo -u dspace ant update && \
 sudo cp -R -p /dspace/webapps/* /opt/tomcat/webapps/ && \
 sudo -u dspace rm -rf /dspace/*bak*
echo "OK"
