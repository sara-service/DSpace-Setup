#!/bin/bash

WORKDIR=$PWD
CONFIGDIR=$WORKDIR/config

echo "delete last src dump"
sudo rm -rf /home/dspace/DSpace && echo "OK"
echo "copy sources from git"
sudo cp -r $WORKDIR/DSpace /home/dspace/DSpace && sudo chown -R dspace:dspace /home/dspace/DSpace && echo "OK"
echo "copy modified configs"

# enable rest
# mail server cfg
# swordv2 cfg
# xmlui cfg
sudo -u dspace cp $CONFIGDIR/rest/web.xml               /home/dspace/DSpace/dspace-rest/src/main/webapp/WEB-INF/web.xml && \
sudo -u dspace cp $CONFIGDIR/local.cfg                  /home/dspace/DSpace/dspace/config/local.cfg && \
sudo -u dspace cp $CONFIGDIR/swordv2/swordv2-server.cfg /home/dspace/DSpace/dspace/config/modules/swordv2-server.cfg && \
sudo -u dspace cp $CONFIGDIR/dspace.cfg                 /home/dspace/DSpace/dspace/config/dspace.cfg && \
sudo -u dspace cp $CONFIGDIR/xmlui.xconf                /home/dspace/DSpace/dspace/config/xmlui.xconf && \
echo "OK"

cd /home/dspace/DSpace && sudo -u dspace mvn -e package -Dmirage2.on=true && \
 sudo service tomcat stop && \
 cd /home/dspace/DSpace/dspace/target/dspace-installer/ && sudo -u dspace ant update && \
 sudo cp -R -p /dspace/webapps/* /opt/tomcat/webapps/ && \
 sudo -u dspace rm -rf /dspace/*bak* && \
 sudo service tomcat start
