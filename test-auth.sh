#!/bin/bash

echo -n "Testing REST and SWORD access..."

### dspace 6 instance: 
#DSPACE_SERVER="http://bib-test.rz.uni-ulm.de"
DSPACE_SERVER="http://134.60.51.65:8080"

#SARA_USER="kiz.oparu-testuser01@uni-ulm.de"
SARA_USER="project-sara@uni-konstanz.de"
SARA_PWD="SaraTest"

# set one user that exists and one that doesnt
USER1="stefan.kombrink@uni-ulm.de"
USER2="daniel.duesentrieb@uni-entenhausen.de"
USER3="kiz.oparu-testuser02@uni-ulm.de"


echo "using $SARA_USER:$SARA_PWD on $DSPACE_SERVER"


echo "user existence check $USER1"
curl -H "on-behalf-of: $USER1" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD"  # => downloads TermsOfServices for all available collections
echo "user existence check $USER2"
curl -H "on-behalf-of: $USER2" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD" # HTML 403
echo "user existence check $USER3"
curl -H "on-behalf-of: $USER3" -i $DSPACE_SERVER/swordv2/servicedocument --user "$SARA_USER:$SARA_PWD" # ==> downloads ToS for all available collections


# submit item with SARA submit user, on-behalf user (Nachweis, no bitstreams attached!)
cat << 'EOF' > entry.xml
<?xml version='1.0' encoding='UTF-8'?> 
<entry xmlns="http://www.w3.org/2005/Atom"
           xmlns:dc="http://purl.org/dc/elements/1.1/"
           xmlns:dcterms="http://purl.org/dc/terms/"       
           xmlns:uulm="http://oparu.uni-ulm.de/namespace/metadataschema-uulm"
           xmlns:dummy="http://oparu.uni-ulm.de/namespace/metadataschema-dummy"
           xmlns:source="http://oparu.uni-ulm.de/namespace/metadataschema-source">


    <title>CURL</title>
    <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
    <updated>2005-10-07T17:17:08Z</updated>
    <author><name>Author kk</name></author>
    <summary type="text">The abstract summery</summary>
        <creator><name>>creator kk name</name></creator>
        <subject type="text">subject 11</subject>
        <bemerkung type="text">bemerkung text</bemerkung>

    <!-- some embedded metadata -->
    <dcterms:abstract>The abstract</dcterms:abstract>
    <dcterms:type>Type Atom</dcterms:type>
        <dc:type>Type Atom dc</dc:type>
        <dcterms:type>Type Atom dcterms</dcterms:type>
        <dcterms:alternative>alternative</dcterms:alternative>
        <dcterms:creator>Creator Test dcterms</dcterms:creator>
        <dcterms:subject>subject Test dcterms</dcterms:subject>
        <dcterms:bemerkung>UULM bemerkung</dcterms:bemerkung>

</entry>
EOF

# no access rights :(
curl -i $DSPACE_SERVER/swordv2/collection/123456789/33 --data-binary "@entry.xml" -H "Content-Type: application/atom+xml" -H "In-Progress: true" -H "on-behalf-of: stefan.kombrink@uni-ulm.de" --user "$SARA_USER:$SARA_PWD"

# no access rights - not authorised to submit to collection!
curl -i $DSPACE_SERVER/swordv2/collection/123456789/36 --data-binary "@entry.xml" -H "Content-Type: application/atom+xml" -H "In-Progress: true" -H "on-behalf-of: $USER3" --user "$SARA_USER:$SARA_PWD"

# access succeeds!
curl -i $DSPACE_SERVER/swordv2/collection/123456789/39 --data-binary "@entry.xml" -H "Content-Type: application/atom+xml" -H "In-Progress: true" -H "on-behalf-of: $USER3" --user "$SARA_USER:$SARA_PWD"

# TODO protection for on-behalf-of (works in dspace5/dspace6)
### 0) configure access to swordv2 interface in apache for SARA service only
### 1) Patch https://github.com/DSpace/DSpace/compare/dspace-6_x...c1t4r:dspace-6.2_OboFixVariant1
### 2) Patch https://github.com/DSpace/DSpace/compare/dspace-6_x...c1t4r:dspace-6.2_OboFixVariant2
