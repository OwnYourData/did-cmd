#!/usr/bin/env bash

set -e

if ! hash wget > /dev/null 2>&1; then
    echo "wget is required for download. Install wget and try again."
    exit 1
fi

if ! hash ruby > /dev/null 2>&1; then
    echo "wget is required for download. Install wget and try again."
    exit 1
fi

mkdir -p ~/bin
wget https://raw.githubusercontent.com/OwnYourData/did-cmd/master/oydid.rb -O ~/bin
mv ~/bin/oydid.rb ~/bin/oydid
chmod +x ~/bin/oydid

# sh -c "curl -fsSL https://raw.githubusercontent.com/OwnYourData/did-cmd/master/install.sh | sh"