#!/usr/bin/env bash

set -e

if [[ "$1" = @("-h"|"--help") ]]; then
    echo "Usage: $0"
    echo "This script will download and build Galaxy release 23.1, and configure planemo to use it."
    echo "You can edit ~/.planemo.yml to modify planemo configuration manually."
    exit 0
fi

cd ~/.planemo/

echo ""
echo "Downloading Galaxy release 23.1.1..."
echo ""
wget https://github.com/galaxyproject/galaxy/archive/refs/tags/v23.1.1.tar.gz
echo "Extracting archive..."
tar -xzf v23.1.1.tar.gz
rm v23.1.1.tar.gz

echo ""
echo "Building Galaxy client..."
cd galaxy-23.1.1
make client
echo ""

echo ""
echo "Configuring Planemo..."
echo "" >> ~/.planemo.yml
echo "galaxy_root: $PWD/galaxy-23.1.1" >> ~/.planemo.yml

echo ""
echo "Done"
echo ""
