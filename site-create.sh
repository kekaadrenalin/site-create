#!/bin/bash

if [ ! -n "$BASH" ]; then echo Please run this script $0 with bash; exit 1; fi

function create_site()
{
    site_name=$HOST
    site_alias=$ALIAS
	site_addr=$IP

	if [ -d /home/${site_name} ]; then
	    echo "Site folder already created."
	else
	    mkdir /home/${site_name}
		mkdir /home/${site_name}/logs
		mkdir /home/${site_name}/httpdocs
		mkdir /home/${site_name}/httpdocs/web

		useradd -d /home/${site_name} -s /bin/bash ${site_name}
		usermod -G www-data ${site_name}

		mkdir /home/${site_name}/.ssh
		chmod 0700 /home/${site_name}/.ssh

		ssh-keygen -b 4096 -t rsa -N "${site_name}" -f /home/${site_name}/.ssh/id_rsa
		chmod 0600 /home/${site_name}/.ssh/id_rsa

		ssh-keygen -b 4096 -t dsa -N "${site_name}" -f /home/${site_name}/.ssh/id_dsa
		chmod 0600 /home/${site_name}/.ssh/id_dsa

		echo  "<?php phpinfo();" > /home/${site_name}/httpdocs/web/index.php
		chown ${site_name}:www-data -R /home/${site_name}
	fi

	echo "
<VirtualHost 127.0.1.1:8080>
    ServerName ${site_name}
    ServerAlias www.${site_name}
    ServerAdmin info@${site_name}
    DocumentRoot /home/${site_name}/httpdocs/web
    <Directory /home/${site_name}/httpdocs/web>
        Options Indexes FollowSymLinks MultiViews
        Options FollowSymLinks
        AllowOverride All
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Order allow,deny
        Allow from all
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${site_name}-error.log
    # Possible values include: debug, info, notice, warn, error, crit, alert, emerg.
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/${site_name}-access.log combined
</VirtualHost>
" > /etc/apache2/sites-enabled/${site_name}.conf

main="
# Apache back-end
location / {
    proxy_pass  http://127.0.1.1:8080;
    proxy_ignore_headers   Expires Cache-Control;
    proxy_set_header        Host            \$host;
    proxy_set_header        X-Real-IP       \$remote_addr;
    proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
}
location ~* \.(js|css|png|jpg|jpeg|gif|ico|swf)\$ {
    expires 1y;
    log_not_found off;
    proxy_pass  http://127.0.1.1:8080;
    proxy_ignore_headers   Expires Cache-Control;
    proxy_set_header        Host            \$host;
    proxy_set_header        X-Real-IP       \$remote_addr;
    proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
}
location ~* \.(html|htm)\$ {
    expires 1h;
    proxy_pass  http://127.0.1.1:8080;
    proxy_ignore_headers   Expires Cache-Control;
    proxy_set_header        Host            \$host;
    proxy_set_header        X-Real-IP       \$remote_addr;
    proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
}
"

if [ $REDIRECT = 'site-www' ]; then
    redirect="
# Rerirect ${site_name}
server {
    listen ${site_addr};
    server_name ${site_name};
    return 301 http://www.${site_name}\$request_uri;
}
"
    server_name="www.${site_name}"
fi

if [ $REDIRECT = 'www-site' ]; then
    redirect="
# Rerirect www.${site_name}
server {
    listen ${site_addr};
    server_name www.${site_name};
    return 301 http://${site_name}\$request_uri;
}
"
        server_name="${site_name}"
fi

if [ $REDIRECT = 'off' ]; then
    redirect=''
    server_name="${site_name}"
fi

echo "
${redirect}
# Site ${server_name}
server {
    listen ${site_addr};
    server_name ${server_name} ${site_alias};
    root /home/${site_name}/httpdocs/web;
    index index.php;
    access_log /home/${site_name}/logs/access.log;
    error_log  /home/${site_name}/logs/error.log error;
    charset utf-8;
    location = /favicon.ico {
        log_not_found off;
        access_log off;
        break;
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    ${main}
    location ~ /(protected|themes/\w+/views)/ {
        access_log off;
        log_not_found off;
        return 404;
    }
    #
    location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)\$ {
        expires 24h;
        #log_not_found off;
        #try_files \$uri =404;
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    #
    location  ~ /\. {
        deny  all;
        access_log off;
        log_not_found off;
    }
}
" > /etc/nginx/conf.d/${site_name}.conf

    service apache2 reload
    service nginx reload

    echo ""
    echo "--------------------------------------------------------"
    echo "User: ${site_name}"
    echo "Login: ${site_name}"
    echo "Path: /home/${site_name}/"
    echo "SSH Private file: /home/${site_name}/.ssh/id_rsa"
    echo "SSH Public file: /home/${site_name}/.ssh/id_rsa.pub"
    echo "Servers:"
    echo "Site name: ${site_name} (${IP})"

    if [ ! -z $site_alias ]; then
        echo "Site alias: ${site_alias}"
    fi

    if [ $REDIRECT = 'site-www' ]; then
        echo "Use redirect from ${site_name} to ${server_name}"
    fi
    if [ $REDIRECT = 'www-site' ]; then
        echo "Use redirect from ${site_name} to ${server_name}"
    fi
    if [ $REDIRECT = 'off' ]; then
        echo "Redirect disabled. use only ${server_name}"
    fi

    echo "Site root: /home/${site_name}/httpdocs/web"
    echo "Site logs path: /home/${site_name}/logs"

    echo "Back-end server: Apache 2"
    echo "NGINX: /etc/nginx/conf.d/${site_name}.conf"
    echo "APACHE: /etc/apache2/sites-enabled/${site_name}.conf"

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
   --ip=                    IP address, default usage port 80 (Example: --ip=127.0.0.1:8080)
   --redirect=              WWW redirect add, default www-site (Example: --redirect=www-site or --redirect=site-www or disable redirect --redirect=off)
   --alias=                 Set Nginx alias (Example: --alias="alias1 alias2 etc")
   -h | --help              Usage
EXAMPLES:
   bash site-create.sh --host="myhost.com" --ip="192.168.1.1:8080"
   bash site-create.sh --host="myhost.com" --alias="c1.myhost.com c2.myhost.com"
EOF
}

REDIRECT='www-site'
HOST=''
ALIAS=''
IP=$(trim $(hostname -I)):80

for i in "$@"
do
    case $i in
        --host=*)
            HOST=( "${i#*=}" )
            shift
        ;;
        --alias=*)
            ALIAS=( "${i#*=}" )
            shift
        ;;
        --ip=*)
            IP=( "${i#*=}" )
            shift
        ;;
        --redirect=*)
            REDIRECT=( "${i#*=}" )
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
  create_site
else
  usage
fi