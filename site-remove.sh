#!/bin/bash

if [ ! -n "$BASH" ]; then echo Please run this script $0 with bash; exit 1; fi

function remove_site()
{
    site_name=$HOST

	if [ -d /home/${site_name} ]; then
	    rm -rf /home/${site_name}

		userdel -rf ${site_name}
	fi

	rm -rf /etc/apache2/sites-enabled/${site_name}.conf
    rm -rf /etc/nginx/conf.d/${site_name}.conf

    service apache2 reload
    service nginx reload

    clear

    echo ""
    echo "--------------------------------------------------------"
    echo "User: ${site_name}"
    echo "Path: /home/${site_name}/"
    echo ""
    echo "REMOVE is completed!"
    echo "--------------------------------------------------------"
    echo ""
}

usage()
{
cat << EOF
usage: $0 options
This script create settings files for apache2 + nginx.
OPTIONS:
   --host=                  Host name without www (Example: --host=myhost.com)
   -h | --help              Usage
EXAMPLES:
   sudo bash site-remove.sh --host="myhost.com"
EOF
}

HOST=''

for i in "$@"
do
    case $i in
        --host=*)
            HOST=( "${i#*=}" )
            shift
        ;;
        -h | --help)
            usage
            exit
        ;;
        *)
        # unknown option
        ;;
    esac
done

if [ ! -z "$HOST" ]; then
  remove_site
else
  usage
fi