#!/bin/bash

if [[ ${UID} != 0 ]]; then
    echo 'Run this script as root!'
    exit 1
fi

postfix upgrade-configuration
postfix check

newaliases

if [[ $(which rc-service) ]]; then
    rc-service postfix restart
elif [[ $(which systemctl) ]]; then
     systemctl restart postfix
else
    echo 'Unable to determine init system! Restart postfix manually.'
fi
