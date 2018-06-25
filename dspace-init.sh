#!/bin/sh

echo "creating users..."

# sara submit user
sudo /dspace/bin/dspace user --add --email project-sara@uni-konstanz.de --password SaraTest --givenname Project --surname Sara
# SARA test user
sudo /dspace/bin/dspace user --add --email stefan.kombrink@uni-ulm.de --password SaraTest --givenname Stefan --surname Kombrink
sudo /dspace/bin/dspace user --add --email volodymyr.kushnarenko@uni-ulm.de --password SaraTest --givenname Vladimir --surname Kushnarenko
sudo /dspace/bin/dspace user --add --email franziska.rapp@uni-ulm.de --password SaraTest --givenname Franziska --surname Rapp
sudo /dspace/bin/dspace user --add --email matthias.fratz@uni-konstanz.de --password SaraTest --givenname Matthias --surname Fratz
sudo /dspace/bin/dspace user --add --email daniel.scharon@uni-konstanz.de --password SaraTest --givenname Daniel --surname Scharon
sudo /dspace/bin/dspace user --add --email kosmas.kaifel@uni-ulm.de --password SaraTest --givenname Kosmas --surname Kaifel
sudo /dspace/bin/dspace user --add --email uli.hahn@uni-ulm.de --password SaraTest --givenname Uli --surname Hahn
# generic SARA test user
sudo /dspace/bin/dspace user --add --email demo-user@sara-service.org --password SaraTest --givenname Demo --surname User
# generic SARA test user, no submit rights
sudo /dspace/bin/dspace user --add --email demo-user-noaccess@sara-service.org --password SaraTest --givenname Demo --surname Loser

echo "done"
