#!/bin/bash

/usr/bin/emerge --sync &> /var/log/emerge-sync.log
/usr/bin/eclean-dist
/usr/bin/eclean-pkg
