#!/bin/bash
#Colors...................................................................
# Reset
Color_Off='\033[0m'       # Text Reset
# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
function CT {
	echo -e $1$2$Color_Off $3
}
#File Pathes...............................................................
DIR_BACKUP=/home/$USER/.etc_backup
mkdir $DIR_BACKUP/ 2> /dev/null
CONFIG_HOSTS="/etc/hosts"
CONFIG_PORTS="/etc/apache2/ports.conf"
DIR_AVAILABLE_SITES="/etc/apache2/sites-available/"
CONFIG_APACHE="/etc/apache2/apache2.conf"
DIR_DEFAULT_ROOT=$(grep 'DocumentRoot' /etc/apache2/sites-enabled/000-default.conf | sed 's/^.*DocumentRoot //')/
function request_subdomain_name {
    echo -e "Please enter the sub-domain's name: \c"
    read SUBDOMAIN_NAME

    #check to see if subdomain is empty..
    if [[ -n "$SUBDOMAIN_NAME" ]]; then
        #check if subdomain already exists
        if grep -q $SUBDOMAIN_NAME".localhost" "$CONFIG_HOSTS"; then
            CT $Red "The sub-domain you entered already exists. Please choose another one..."
            request_subdomain_name
            return 1
        else

            return 0
        fi
    else
        CT $Red "The name cannot/var/www/html/test5/ be empty. Please try again..."
        request_subdomain_name
        return 1
    fi
}
function request_subdomain_path {
    SUBDOMAIN_DIR="$DIR_DEFAULT_ROOT$SUBDOMAIN_NAME/"
	echo -e "Please enter the sub-domain's path [default: $SUBDOMAIN_DIR]: \c"
    read subdir

    if [[ -z "$subdir" ]]; then
    	subdir=$SUBDOMAIN_DIR
    fi
	if [ -d "$subdir" ]; then
		if [  "$(ls -A $subdir)" ]; then
			DIR_USER=$(stat -c "%U" $subdir)
			DIR_GROUP=$(stat -c "%G" $subdir)
			if [[ $DIR_USER != $USER  ]]; then
			 		CT $Red "The directory you chose is not writable, Please choose another one..."
			 		request_subdomain_path
			 		return -1
			else
				while true
				do
					CT $Yellow "The directory you chose is not empty. Continue anyway? (y/n): " "\c"
					read ans
					if [[ $ans == "y" ]]; then
						break
					elif [[ $ans == "n" ]]; then
						request_subdomain_path
						return -1
					else
                        CT $Red "Please answer with y or n."
						continue
					fi
				done
			fi
		fi
	else
		sudo mkdir -p $subdir
        sudo chown $USER":www-data" $subdir
        sudo chmod -R 755 $subdir
	fi
    if [[ ! $subdir = */ ]]; then
        subdir=$subdir/
    fi
	SUBDOMAIN_DIR=$subdir
    return 0
}
function checkIfPortInUse {
    grep -q $1 "$CONFIG_PORTS"
    if [[ $? -eq 1 ]]; then
        return 0
    fi
    return 1
}
function request_subdomain_port {
	re='^[0-9]+$'
    while true
    do
        randomPort=$((1025 + RANDOM % 65536))
        checkIfPortInUse $randomPort
        if [[ $? -eq 0 ]]; then
            break
        fi
    done
    while true
    do
        echo -e "Please enter the sub-domain's path [Leave empty to choose $randomPort]: \c"
        read port
        #if left blank, set it to 80
        if [[ -z $port ]]; then
            port=$randomPort
            break
        elif ! [[ $port =~ $re && $port -lt 65536 && $port -gt 1024 ]] ; then
            CT $Red "Invalid port number. Please enter a value between 1024 and 65536\n"
            continue
        else
            checkIfPortInUse $port
            if [[ $? -eq 0 ]]; then
                break
            fi
            CT $Red "Port $port is already in use with another subdomain! Please choose another.\n"
        fi
    done
	SUBDOMAIN_PORT=$port
}
function configure_virtualhost {

    PATH_SUB_CONFIG=$DIR_AVAILABLE_SITES$SUBDOMAIN_NAME.conf

    #Taking necessary backups
    sudo cp $CONFIG_PORTS $DIR_BACKUP"ports.conf_$(date +"%s")"
    sudo cp $CONFIG_HOSTS $DIR_BACKUP"hosts_$(date +"%s")"
    sudo cp $CONFIG_APACHE $DIR_BACKUP"apache.conf_$(date +"%s")"

    #Adding new configuration file for subdomain at available-sites
    echo -e "<Directory "$SUBDOMAIN_DIR">
    Options FollowSymLinks MultiViews
    AllowOverride All
    Order allow,deny
    allow from all
</Directory>
<VirtualHost *:80>
    ServerName $SUBDOMAIN_NAME.localhost
    ServerAlias $SUBDOMAIN_ALIAS
    DocumentRoo~/Dropbox/work/scripts/virtualdomainst "$SUBDOMAIN_DIR"
</VirtualHost>~/Dropbox/work/scripts/virtualdomains
<VirtualHost *:~/Dropbox/work/scripts/virtualdomains$SUBDOMAIN_PORT>
    ServerName ~/Dropbox/work/scripts/virtualdomainslocalhost
    ServerAlias~/Dropbox/work/scripts/virtualdomains localhost
    DocumentRoo~/Dropbox/work/scripts/virtualdomainst "$SUBDOMAIN_DIR"
</VirtualHost>~/Dropbox/work/scripts/virtualdomains
    " | sudo te~/Dropbox/work/scripts/virtualdomainse $PATH_SUB_CONFIG &> /dev/null
    #if subdoma~/Dropbox/work/scripts/virtualdomainsin dir is outside default root /var/www/html add access permission in apache configuration
    if [[ !  $3 =~ .*$DIR_DEFAULT_ROOT.* ]]; then

        echo -e "<Directory "$SUBDOMAIN_DIR">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    allow from all
    Require all granted
</Directory>" | sudo tee -a $CONFIG_APACHE &> /dev/null
    fi

    #Listening to custom port
    echo "Listen $SUBDOMAIN_PORT" | sudo tee -a $CONFIG_PORTS &> /dev/null
    #Adding host value for the server & the alias
    echo -e "127.0.0.1\t$SUBDOMAIN_ALIAS" | sudo tee -a $CONFIG_HOSTS &> /dev/null
    echo -e "127.0.0.1\t$SUBDOMAIN_NAME.localhost" |sudo tee -a $CONFIG_HOSTS &> /dev/null
    sudo a2ensite $SUBDOMAIN_NAME
    echo "Sub-Domain $SUBDOMAIN_NAME works" > $SUBDOMAIN_DIR"index.html"
    sudo service apache2 restart
    return 0
}

function request_alias {

    while true
    do
        echo -e "Please provide a non-valid TLD domain as an alias for your subdomain [Default is $SUBDOMAIN_NAME]: \c"
        read SUBDOMAIN_ALIAS

        #Any string contains chars.. without any dots.. [VALID]
        #if [[ $SUBDOMAIN_ALIAS =~ ^[0-9A-Za-z]*[a-zA-Z]+[0-9a-zA-Z]*$ ]]; then
        if [[ -z $SUBDOMAIN_ALIAS ]]; then
            SUBDOMAIN_ALIAS=$SUBDOMAIN_NAME
            break
        elif [[ $SUBDOMAIN_ALIAS =~ \.[a-zA-Z]*\.([a-zA-Z]+([0-9]*[a-zA-Z]+)*)+$|^[0-9A-Za-z]*[a-zA-Z]+[0-9a-zA-Z]*$ ]]; then
            break
        #Any string contains one dot.. and only characters a-z after the dot (check for valid tld)
        elif [[ $SUBDOMAIN_ALIAS =~ ^[a-zA-Z0-9]*\.([a-zA-Z]+[0-9]*)+$ ]]; then
            tld=$(echo $SUBDOMAIN_ALIAS | cut -d'.' -f 2)
            grep -qwi $tld $(pwd)/tlds
            if [[ $? -eq 0  ]]; then
                CT $Red "You should NOT use Top-Level-Domain .$tld as an alias"
            fi
            continue
        else
            CT $Red "Invalid alias name! Please only use charachters a-z."
            continue
        fi

    done
}



#request subdomain name from user
request_subdomain_name
#request alias
request_alias
#request subdomain path from user
request_subdomain_path
#request subdomain port from user
CT $Purple "Please choose a port nubmer other than 80 to access the sub-domain from your IPv4 directly through LAN."
request_subdomain_port

#prepare configuration
if [[ -z $SUBDOMAIN_NAME || -z $SUBDOMAIN_PORT || -z $SUBDOMAIN_DIR || -z $SUBDOMAIN_ALIAS ]]; then
    exit 1
fi
configure_virtualhost
CT $Green "Subdomain is installed successfully!"
exit 0
