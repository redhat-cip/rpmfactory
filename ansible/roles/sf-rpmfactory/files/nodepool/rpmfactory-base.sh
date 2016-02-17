#!/bin/bash

# /!\ This is the base preparation script of RPMFactory
# to interact with a koji server. Please do not modify it /!\

# You can include it in another preparation script if you need
# to add more components to your slave

. base.sh

# Install minimum for RPM factory jobs
sudo yum install -y koji wget rpmdevtools rpm-build redhat-rpm-config mock rsync createrepo

# Add jenkins to the mock group
sudo usermod -a -G mock jenkins

# Prepare jenkins user config for koji
sudo mkdir /home/jenkins/.koji
sudo chown -R jenkins /home/jenkins/.koji

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync

echo "Setup finished. Creating snapshot now, this will take a few minutes"
