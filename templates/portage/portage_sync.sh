#!/bin/bash

/usr/bin/emerge --sync &>  /var/log/emerge-sync.log
/usr/bin/eclean-dist   &>  /var/log/emerge-clean.log
/usr/bin/eclean-pkg    &>> /var/log/emerge-clean.log
