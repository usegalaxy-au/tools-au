#!/usr/bin/env bash

set -e

PLANEMO_CONFIG_DIR=~/.planemo/

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

mkdir -p "${PLANEMO_CONFIG_DIR}"
cd "${PLANEMO_CONFIG_DIR}"

if [ ! -f galaxy-23.1.1.tar.gz ] && [ ! -d galaxy-23.1.1 ]; then
    echo ""
    echo "Downloading Galaxy v23.1.1..."
    echo ""
    wget https://dev-site.gvl.org.au/media/galaxy-23.1.1.tar.gz
fi

if [ ! -d galaxy-23.1.1 ]; then
    echo "Extracting archive..."
    tar -xzf galaxy-23.1.1.tar.gz
    rm galaxy-23.1.1.tar.gz
fi

if [[ "$(grep -E '^\w?galaxy_root' ~/.planemo.yml)" != "" ]]; then
    echo ""
    echo "Configuring Planemo..."
    echo "" >> ~/.planemo.yml
    echo "galaxy_root: $PWD/galaxy-23.1.1"
    echo "galaxy_root: $PWD/galaxy-23.1.1" >> ~/.planemo.yml
else
    echo "galaxy_root already configured in ~/.planemo.yml. Please ensure the galaxy root is correct:"
    echo "$(grep -E '^\w?galaxy_root' ~/.planemo.yml)"
fi

echo ""
echo "Done"
echo ""
