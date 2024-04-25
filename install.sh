#!/bin/bash

clear
echo ""
echo "======================================================================="
echo "|                                                                     |"
echo "|     full-stack-nginx-moodle-for-everyone-with-docker-compose        |"
echo "|                         by Erdal ALTIN                              |"
echo "|                                                                     |"
echo "======================================================================="
sleep 2

# the "lpms" is an abbreviation of Linux Package Management System
lpms=""
for i in apk dnf yum apt zypper
do
	if [ -x "$(command -v $i)" ]; then
		if [ "$i" == "apk" ]
		then
			lpms=$i
			break
		elif [ "$i" == "dnf" ] && ([[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') == "fedora" ]] || (([[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') != "centos" ]] && [[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"fedora"* ]]) || ([[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"rhel"* ]] && [ $(sudo uname -m) == "s390x" ])))
		then
			lpms=$i
			break
		elif [ "$i" == "yum" ] && ([[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') == "centos" ]] || (([[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') != "fedora" ]] && [[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"fedora"* ]]) || ([[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"rhel"* ]] && [ $(sudo uname -m) == "s390x" ])))
		then
			lpms=$i
			break
		elif [ "$i" == "apt" ] && ([[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') == *"ubuntu"* ]] || [[ $(grep -Pow 'ID=\K[^;]*' /etc/os-release | tr -d '"') == *"debian"* ]] || [[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"ubuntu"* ]] || [[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release | tr -d '"') == *"debian"* ]])
		then
			lpms=$i
			break
		elif [[ $(grep -Pow 'ID_LIKE=\K[^;]*' /etc/os-release) == *"suse"* ]]
		then
			lpms=$i
			break
		fi
	fi
done

if [ -z $lpms ]; then
	echo ""
	echo "could not be detected package management system"
	echo ""
	exit 0
fi

##########
# Setup project variables
##########
echo ""
echo ""
echo "======================================================================="
echo "| Please enter project related variables..."
echo "======================================================================="
echo ""
sleep 2

# set your domain name
domain_name=""
read -p 'Enter Domain Name(e.g. : example.com): ' domain_name
[ -z $domain_name ] && domain_name="NULL"
host -N 0 $domain_name 2>&1 > /dev/null
while [ $? -ne 0 ]
do
	echo "Try again"
	read -p 'Enter Domain Name(e.g. : example.com): ' domain_name
	[ -z $domain_name ] && domain_name="NULL"
	host -N 0 $domain_name 2>&1 > /dev/null
done
echo "Ok."

# set parameters in env.example file
email=""
regex="^[a-zA-Z0-9\._-]+\@[a-zA-Z0-9._-]+\.[a-zA-Z]+\$"
read -p 'Enter Email Address for letsencrypt ssl(e.g. : email@domain.com): ' email
while [ -z $email ] || [[ ! $email =~ $regex ]]
do
	echo "Try again"
	read -p 'Enter Email Address for letsencrypt ssl(e.g. : email@domain.com): ' email
	sleep 1
done
echo "Ok."

db_username=""
db_regex="^[0-9a-zA-Z\$_]{6,}$"
read -p 'Enter Database Username(at least 6 characters): ' db_username
while [[ ! $db_username =~ $db_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, dollar sign and underscore)"
	read -p 'Enter Database Username(at least 6 characters): ' db_username
	sleep 1
done
echo "Ok."

db_password=""
password_regex="^[a-zA-Z0-9\._-]{6,}$"
read -p 'Enter Database Password(at least 6 characters): ' db_password
while [[ ! $db_password =~ $password_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, dot, underscore and minus sign)"
	read -p 'Enter Database Password(at least 6 characters): ' db_password
	sleep 1
done
echo "Ok."

db_name=""
read -p 'Enter Database Name(at least 6 characters): ' db_name
while [[ ! $db_name =~ $db_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, dollar sign and underscore)"
	read -p 'Enter Database Name(at least 6 characters): ' db_name
	sleep 1
done
echo "Ok."

db_table_prefix_regex="^[0-9a-zA-Z\$_]{3,}$"
read -p 'Enter Database Table Prefix(at least 3 characters, default : mdl_): ' db_table_prefix
: ${db_table_prefix:=mdl_}
while [[ ! $db_table_prefix =~ $db_table_prefix_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, dollar sign and underscore)"
	read -p 'Enter Database Table Prefix(at least 3 characters, default : mdl_): ' db_table_prefix
	: ${db_table_prefix:=mdl_}
	sleep 1
done
echo "Ok."

mysql_root_password=""
read -p 'Enter MariaDb/Mysql Root Password(at least 6 characters): ' mysql_root_password
while [[ ! $mysql_root_password =~ $password_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, dot, underscore and minus sign)"
	read -p 'Enter MariaDb/Mysql Root Password(at least 6 characters): ' mysql_root_password
	sleep 1
done
echo "Ok."

which_db=""
db_authentication_plugin="mysql_native_password"
db_package_manager="apt-get update \&\& apt-get install -y gettext-base"
db_admin_commandline="mariadb-admin"
db_connect_extension="mariadb"
PS3="Select the database: "
select db in mariadb mysql
do
	which_db=$db
	if [ $REPLY -eq 2 ]
	then
		db_authentication_plugin="caching_sha2_password"
		db_package_manager="microdnf install -y gettext"
		db_admin_commandline="mysqladmin"
		db_connect_extension="mysqli"
	fi
	if [ $REPLY -eq 1 ] || [ $REPLY -eq 2 ]
	then
		break
	else
		PS3="Select the database: "
	fi
done
echo "Ok."

local_timezone_regex="^[a-zA-Z0-9/+_-]{1,}$"
read -p 'Enter container local Timezone(default : Asia/Jakarta, to see the other timezones, https://docs.diladele.com/docker/timezones.html): ' local_timezone
: ${local_timezone:=Asia/Jakarta}
while [[ ! $local_timezone =~ $local_timezone_regex ]]
do
	echo "Try again (can only contain numerals 0-9, basic Latin letters, both lowercase and uppercase, positive, minus sign and underscore)"
	read -p 'Enter container local Timezone(default : Asia/Jakarta, to see the other local timezones, https://docs.diladele.com/docker/timezones.html): ' local_timezone
	sleep 1
	: ${local_timezone:=Asia/Jakarta}
done
local_timezone=${local_timezone//[\/]/\\\/}
echo "Ok."

read -p "Apply changes (y/n)? " choice
case "$choice" in
  y|Y ) echo "Yes! Proceeding now...";;
  n|N ) echo "No! Aborting now..."; exit 0;;
  * ) echo "Invalid input! Aborting now..."; exit 0;;
esac

cp env.example .env

sed -i 's/db_authentication_plugin/'$db_authentication_plugin'/' .env
sed -i "s|db_package_manager|${db_package_manager}|" .env
sed -i 's/db_admin_commandline/'$db_admin_commandline'/' .env
sed -i 's/db_connect_extension/'$db_connect_extension'/' .env
sed -i 's/example.com/'$domain_name'/' .env
sed -i 's/email@domain.com/'$email'/' .env
sed -i 's/which_db/'$which_db'/g' .env
sed -i 's/db_username/'$db_username'/g' .env
sed -i 's/db_password/'$db_password'/g' .env
sed -i 's/db_name/'$db_name'/' .env
sed -i 's/db_table_prefix/'$db_table_prefix'/' .env
sed -i 's/mysql_root_password/'$mysql_root_password'/' .env
sed -i "s@directory_path@$(pwd)@" .env
sed -i 's/local_timezone/'$local_timezone'/' .env

if [ -x "$(command -v docker)" ] && [ "$(docker compose version)" ]; then
    # Firstly: create external volume
	docker volume create --driver local --opt type=none --opt device=`pwd`/certbot --opt o=bind certbot-etc > /dev/null
	# installing Moodle and the other services
	docker compose up -d & export pid=$!
	echo "Moodle and the other services installing proceeding..."
	echo ""
	wait $pid
	if [ $? -eq 0 ]
	then
		echo ""
		until [ -n "$(sudo find ./certbot/live -name '$domain_name' 2>/dev/null | head -1)" ]; do
			echo "waiting for Let's Encrypt certificates for $domain_name"
			sleep 5s & wait ${!}
			if sudo [ -d "./certbot/live/$domain_name" ]; then break; fi
		done
		echo "Ok."
		#until [ ! -z `docker compose ps -a --filter "status=running" --services | grep webserver` ]; do
		#	echo "waiting starting webserver container"
		#	sleep 2s & wait ${!}
		#	if [ ! -z `docker compose ps -a --filter "status=running" --services | grep webserver` ]; then break; fi
		#done
		echo ""
		echo "Reloading webserver ssl configuration"
		docker container restart webserver > /dev/null 2>&1
		echo "Ok."
		echo ""
		echo "completed setup"
		echo ""
		echo "Website: https://$domain_name"
		echo ""
		echo "Ok."
	else
		echo ""
		echo "Error! could not installed Moodle and the other services with docker compose" >&2
		echo ""
		exit 1
	fi
else
	echo ""
	echo "not found docker and/or docker compose, Install docker and/or docker compose" >&2
	echo ""
	exit 1
fi
