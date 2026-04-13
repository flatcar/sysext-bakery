#!/bin/bash

# clone scripts with a custom branch and set up symlinks,
# where the run_sdk_container normally mounts stuff
git -C /tmp clone --depth=1 https://github.com/flatcar/scripts.git -b danzatt/sign-sysexts-nopatch
sudo rm -rf /mnt/host/source
sudo mkdir -p /tmp/scripts/__build__/images
sudo ln -s /tmp/scripts/sdk_container /mnt/host/source
sudo ln -s /tmp/scripts/__build__/images /mnt/host/source/src/build
sudo ln -s /tmp/scripts/ /mnt/host/source/src/scripts

# reinstall packages changed in the branch
sudo emerge systemd azure-keyvault-pkcs11
sudo touch /etc/pkcs11/pkcs11.conf
echo "module: /usr/lib64/pkcs11/azure-keyvault-pkcs11.so" | sudo tee /etc/pkcs11/modules/azure-keyvault-pkcs11.module
