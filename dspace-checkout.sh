#!/bin/bash

WORKDIR=$PWD
CONFIGDIR=$WORKDIR/config

if [ -e $WORKDIR/DSpace ]; then
    cd $WORKDIR/DSpace && git pull;
else
    git clone git@github.com:54r4/DSpace.git;
    git fetch -a;
    cd $WORKDIR/DSpace;
fi

echo "checkout / pull complete, now select branch: e.g. ``git checkout -b origin/dspace-6.3_OboFixVariant1``"
