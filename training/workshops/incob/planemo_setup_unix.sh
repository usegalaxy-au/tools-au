#!/usr/bin/env bash

set -e

if [[ "$1" = @("-h"|"--help") ]]; then
    echo "Usage: $0"
    echo "This script will download and build Galaxy release 23.1, and configure planemo to use it."
    echo "You can edit ~/.planemo.yml to modify planemo configuration manually."
    exit 0
fi

printf "\nThis script will download and build Galaxy release 23.1, and configure planemo to use it.\n"
read -p "Continue? [y/n] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting"
    exit 1
fi

cd ~/.planemo/

if [ ! -d v23.1.1.tar.gz ] && [ ! -d galaxy-23.1.1 ]; then
    echo ""
    echo "Downloading Galaxy release 23.1.1..."
    echo ""
    wget https://github.com/galaxyproject/galaxy/archive/refs/tags/v23.1.1.tar.gz
fi

if [ ! -d galaxy-23.1.1 ]; then
    echo "Extracting archive..."
    tar -xzf v23.1.1.tar.gz
    rm v23.1.1.tar.gz
fi

echo ""
echo "Building Galaxy client..."
cd galaxy-23.1.1
make client
echo ""

if [[ "$(grep -E '^\w?galaxy_root' ~/.planemo.yml)" != "" ]]; then
    echo ""
    echo "Configuring Planemo..."
    echo "" >> ~/.planemo.yml
    echo "galaxy_root: $PWD"
    echo "galaxy_root: $PWD" >> ~/.planemo.yml
else
    echo "galaxy_root already configured in ~/.planemo.yml. Please ensure this is correct:"
    echo "$(grep -E '^\w?galaxy_root' ~/.planemo.yml)"
fi

echo ""
echo "Done"
echo ""
