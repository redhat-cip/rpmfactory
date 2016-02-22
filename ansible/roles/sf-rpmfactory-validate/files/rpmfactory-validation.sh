#!/bin/bash

. rpmfactory-base.sh

# TODO Put that in a template
echo "46.231.133.137 rpmfactory.sftests.com" | sudo tee -a /etc/hosts
echo "46.231.133.138 koji.rpmfactory.sftests.com" | sudo tee -a /etc/hosts
