#!/bin/bash

echo "Testing REST and SWORD access without authorization"

DSPACE_SERVER="http://134.60.51.65:8080"

echo "ITEMS"
curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/items | python -m json.tool
echo "COMMUNITIES"
curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/communities | python -m json.tool
echo "COLLECTIONS"
curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/collections | python -m json.tool
echo "HIERARCHY"
curl -s -H "Accept: application/json" $DSPACE_SERVER/rest/hierarchy | python -m json.tool

