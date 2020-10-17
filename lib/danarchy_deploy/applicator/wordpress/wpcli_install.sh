#!/bin/bash

datetime=$(date +%F\ %T)
log='/danarchy/deploy/wpcli_install.log'
working_dir='/var/tmp'

echo "WP-CLI Install: ${datetime}" > ${log}
echo "Grabbing most recent wp-cli..." 2>&1 >> ${log}
curl -sk https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o ${working_dir}/wp-cli.phar 2>&1 >> ${log}

success=''
if [[ -f "${working_dir}/wp-cli.phar" ]]; then
    echo "WP-CLI downloaded."
    chmod +x ${working_dir}/wp-cli.phar

    if [[ -x '/usr/bin/php' ]]; then
	/usr/bin/php ${working_dir}/wp-cli.phar --info --allow-root && success='true'
	mv -v ${working_dir}/wp-cli.phar /usr/local/bin/wp
    else
	echo 'PHP is not installed!'
	rm -v ${working_dir}/wp-cli.phar
	success='false'
    fi
else
    echo "WP-CLI failed to download."
    success='false'
fi 2>&1 >> ${log}

if [[ "${success}" = 'false' ]];then
    echo -e "\nFailed to install WP-CLI!" 2>&1 >> ${log}
    cat ${log} >&2
    exit 1
else
    echo -e "WP-CLI successfully installed!" 2>&1 >> ${log}
    cat ${log}
fi
