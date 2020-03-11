#!/bin/bash
#
# Vhost-creator-for-apache v 1.0.1
#
# Install: cd /usr/local/bin && wget -O xhost https://raw.githubusercontent.com/andrewsokolok/apache_vhostcreator/master/xhost.sh && chmod +x xhost
#
# Usage: xhost
#

spinner ()
{
    bar=" ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    barlength=${#bar}
    i=0
    while ((i < 100)); do
        n=$((i*barlength / 100))
        printf "\e[00;34m\r[%-${barlength}s]\e[00m" "${bar:0:n}"
        ((i += RANDOM%5+2))
        sleep 0.02
    done
}



# Show "Done."
function say_done() {
    echo " "
    echo -e "Done."
    yes "" | say_continue
}


# Ask to Continue
function say_continue() {
    echo -n " To EXIT Press x Key, Press ENTER to Continue"
    read acc
    if [ "$acc" == "x" ]; then
        exit
    fi
    echo " "
}

# Show "Done."
function say_done_2() {
    echo " "
    echo -e "Done."
    say_continue_2
}

# Ask to Continue
function say_continue_2() {
    echo -n " To EXIT Press x Key, Press ENTER to Continue"
    read acc
    if [ "$acc" == "x" ]; then
        exit
    fi
    echo " "
}

# Obtain Server IP
function __get_ip() {
    serverip=$(ip route get 1 | awk '{print $7;exit}')
    echo $serverip
}

##############################################################################################################

f_banner(){
echo
echo "

             __               __                             __
 _   __/ /_  ____  _____/ /_      _____________  ____ _/ /_____  _____
| | / / __ \/ __ \/ ___/ __/_____/ ___/ ___/ _ \/ __ '/ __/ __ \/ ___/
| |/ / / / / /_/ (__  ) /_/_____/ /__/ /  /  __/ /_/ / /_/ /_/ / /
|___/_/ /_/\____/____/\__/      \___/_/   \___/\__,_/\__/\____/_/


Developed By Andrew S."
echo

}

##############################################################################################################

#Check if Running with root user

if [ "$USER" != "root" ]; then
      echo "Permission Denied"
      echo "Can only be run by root"
      exit
else
      clear
      f_banner
fi


#############################################################################################################
update_system(){
apt-get update -y;
apt-get upgrade -y;
apt-get install linux-headers-$(uname -r) -y;
}


#############################################################################################################
new_virtualhost(){
clear
f_banner

### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
apacheUser=$(ps -ef | egrep '(httpd|apache2|apache)' | grep -v root | head -n1 | awk '{print $1}')
email='webmaster@localhost'
sitesEnabled='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
userDir='/var/www/'
sitesAvailabledomain=$sitesAvailable$domain.conf

### don't modify from here unless you know what you are doing ####

if [ "$(whoami)" != 'root' ]; then
        echo $"You have no permission to run $0 as non-root user. Use sudo"
                exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
        then
                echo $"You need to prompt for action (create or delete) -- Lower-case only"
                exit 1;
fi

while [ "$domain" == "" ]
do
        echo -e $"Please provide domain. e.g.dev,staging"
        read domain
done

if [ "$rootDir" == "" ]; then
        rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
        userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
        then
                ### check if domain already exists
                if [ -e $sitesAvailabledomain ]; then
                        echo -e $"This domain already exists.\nPlease Try Another one"
                        exit;
                fi

                ### check if directory exists or not
                if ! [ -d $rootDir ]; then
                        ### create the directory
                        mkdir $rootDir
                        ### give permission to root dir
                        chmod 755 $rootDir
                        ### write test file in the new domain dir
                        if ! echo "Options -Indexes" > $rootDir/.htaccess
                        then
                                echo $"ERROR: Not able to write in file $rootDir/.htaccess. Please check permissions"
                                exit;
                        else
                                echo $"Added content to $rootDir/.htaccess"
                        fi
                fi

                ### create virtual host rules file
                if ! echo "
                <VirtualHost *:80>
                        ServerAdmin $email
                        ServerName $domain
                        ServerAlias $domain
                        DocumentRoot $rootDir
                        <Directory />
                                AllowOverride All
                        </Directory>
                        <Directory $rootDir>
                                Options Indexes FollowSymLinks MultiViews
                                AllowOverride all
                                Require all granted
                        </Directory>
                        ErrorLog /var/log/apache2/$domain-error.log
                        LogLevel error
                        CustomLog /var/log/apache2/$domain-access.log combined
                </VirtualHost>" > $sitesAvailabledomain
                then
                        echo -e $"There is an ERROR creating $domain file"
                        exit;
                else
                        echo -e $"\nNew Virtual Host Created\n"
                fi

                ### Add domain in /etc/hosts
                if ! echo "127.0.0.1    $domain" >> /etc/hosts
                then
                        echo $"ERROR: Not able to write in /etc/hosts"
                        exit;
                else
                        echo -e $"Host added to /etc/hosts file \n"
                fi

                ### Add domain in /mnt/c/Windows/System32/drivers/etc/hosts (Windows Subsytem for Linux)
                if [ -e /mnt/c/Windows/System32/drivers/etc/hosts ]
                then
                        if ! echo -e "\r127.0.0.1       $domain" >> /mnt/c/Windows/System32/drivers/etc/hosts
                        then
                                echo $"ERROR: Not able to write in /mnt/c/Windows/System32/drivers/etc/hosts (Hint: Try running Bash as administrator)"
                        else
                                echo -e $"Host added to /mnt/c/Windows/System32/drivers/etc/hosts file \n"
                        fi
                fi

                if [ "$owner" == "" ]; then
                        iam=$(whoami)
                        if [ "$iam" == "root" ]; then
                                chown -R $apacheUser:$apacheUser $rootDir
                        else
                                chown -R $iam:$iam $rootDir
                        fi
                else
                        chown -R $owner:$owner $rootDir
                fi

                ### enable website
                a2ensite $domain

                ### restart Apache
                /etc/init.d/apache2 reload

                ### show the finished message
                echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $rootDir"

        else
                ### check whether domain already exists
                if ! [ -e $sitesAvailabledomain ]; then
                        echo -e $"This domain does not exist.\nPlease try another one"
                        exit;
                else
                        ### Delete domain in /etc/hosts
                        newhost=${domain//./\\.}
                        sed -i "/$newhost/d" /etc/hosts

                        ### Delete domain in /mnt/c/Windows/System32/drivers/etc/hosts (Windows Subsytem for Linux)
                        if [ -e /mnt/c/Windows/System32/drivers/etc/hosts ]
                        then
                                newhost=${domain//./\\.}
                                sed -i "/$newhost/d" /mnt/c/Windows/System32/drivers/etc/hosts
                        fi

                        ### disable website
                        a2dissite $domain

                        ### restart Apache
                        /etc/init.d/apache2 reload

                        ### Delete virtual host rules files
                        rm $sitesAvailabledomain
                fi

                ### check if directory exists or not
                if [ -d $rootDir ]; then
                        echo -e $"Delete host root directory ? (y/n)"
                        read deldir

                        if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
                                ### Delete the directory
                                rm -rf $rootDir
                                echo -e $"Directory deleted"
                        else
                                echo -e $"Host directory conserved"
                        fi
                else
                        echo -e $"Host directory not found. Ignored"
                fi

                ### show the finished message
                echo -e $"Complete!\nYou just removed Virtual Host $domain"

fi
}


#############################################################################################################

add_alias_virtualhost(){
clear
f_banner

echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Adding New Alias To Exisiting Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menuvhost              # create an array called $menuvhost
menuvhost[0]=""                   # set and ignore index zero so we can count from 1

/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} ' | cut -d$'\n' -f 2- > /tmp/vhost_arr.txt
#echo "$(/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} )'" > /tmp/vhost_arr.txt

# read menu file line-by-line, save as $line
while IFS= read -r line; do
  menuvhost[${#menuvhost[@]}]="$line"  # push $line onto $menuvhost[]
done < /tmp/vhost_arr.txt

# function to show the menu
menuvhost() {
  echo "Please select the domain number in which you want to add an alias"
  echo ""
  for (( i=1; i<${#menuvhost[@]}; i++ )); do
    echo "$i) ${menuvhost[$i]}"
  done
  echo ""
}

# initial menu
menuvhost
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menuvhost[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menuvhost
  read option
done

#echo "You said '$option' which is '${menuvhost[$option]}'"

echo -n "Type your new domain name alias that will be add to ${menuvhost[$option]}: "; read newdomainname
sed "s/ServerAlias.*/& $newdomainname/" -i /etc/apache2/sites-available/${menuvhost[$option]}.conf
a2dissite ${menuvhost[$option]}
a2ensite ${menuvhost[$option]}
#certbot --apache --register-unsafely-without-email;
echo -e $"Complete!\nYou just add new alias  $newdomainname to ${menuvhost[$option]}'s virtual host config"

say_done_2
}

#############################################################################################################

new_virtualhost_create(){
clear
f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Creating New Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

echo -e "Enter your new virtual host name: "; read newvirtualhostdomain;

new_virtualhost create $newvirtualhostdomain

say_done_2
}

#############################################################################################################

new_virtualhost_delete(){
clear
f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Deleting Existing Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menuvhostdelete              # create an array called $menuvhostdelete
menuvhostdelete[0]=""                   # set and ignore index zero so we can count from 1

/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} ' | cut -d$'\n' -f 2- > /tmp/vhost_arr.txt
#echo "$(/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} )'" > /tmp/vhost_arr.txt

# read menu file line-by-line, save as $line
while IFS= read -r line; do
  menuvhostdelete[${#menuvhostdelete[@]}]="$line"  # push $line onto $menuvhostdelete[]
done < /tmp/vhost_arr.txt

# function to show the menu
menuvhostdelete() {
  echo "Please select the domain number that you want to delete: "
  echo ""
  for (( i=1; i<${#menuvhostdelete[@]}; i++ )); do
    echo "$i) ${menuvhostdelete[$i]}"
  done
  echo ""
}

# initial menu
menuvhostdelete
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menuvhostdelete[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menuvhostdelete
  read option
done

#echo "You said '$option' which is '${menuvhostdelete[$option]}'"


new_virtualhost delete ${menuvhostdelete[$option]}

say_done_2
}

#############################################################################################################
start_certbot(){
clear
f_banner


echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Starting Certbot"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

apt-get install certbot python-certbot-apache -y;
certbot --apache --register-unsafely-without-email;

}
#############################################################################################################

install_apache_maxmind(){
clear
f_banner

echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Install apache with maxmind geobase"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""



if [ $(/etc/init.d/apache2 status | grep -v grep | grep 'Apache2 is running' | wc -l) > 0 ]
then
 echo "Apache server is already installed and running. Exit after 1 sec.."
 sleep 1
 exit 0
else
update_system
apt-get install software-properties-common -y;
add-apt-repository universe -y;
add-apt-repository ppa:certbot/certbot -y;
add-apt-repository ppa:maxmind/ppa -y;
apt-get update -y;
apt-get install libmaxminddb0 libmaxminddb-dev mmdb-bin libapache2-mod-geoip -y;
apt-get install geoipupdate -y;
apt-get install apache2 -y;
apt-get -y install  php7.0 libapache2-mod-php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-cli php7.0-dev;

wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz;
tar -xvf GeoLite2-Country*;
mkdir /usr/local/share/GeoIP;
mv GeoLite2-Country*/GeoLite2-Country.mmdb /usr/local/share/GeoIP;
fi
#add  city base
#wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
#tar -xvf GeoLite2-City*
#mv GeoLite2-City*/GeoLite2-City.mmdb /usr/local/share/GeoIP

if grep -xqFe "  GeoIPEnable On" /etc/apache2/mods-available/geoip.conf
then
sed -i -e 's/GeoIPEnable Off/GeoIPEnable On/g' /etc/apache2/mods-available/geoip.conf;
sed -i -e 's/#GeoIPDBFile \/usr\/share\/GeoIP\/GeoIP.dat/GeoIPDBFile \/usr\/share\/GeoIP\/GeoIP.dat/g' /etc/apache2/mods-available/geoip.conf;
sed -i -e 's/<\/IfModule>/GeoIPScanProxyHeaders On\n<\/IfModule>/g' /etc/apache2/mods-available/geoip.conf;
echo -e '<IfModule mod_geoip.c>\nGeoIPEnable On\nGeoIPDBFile /usr/share/GeoIP/GeoIP.dat Standard\nGeoIPEnableUTF8 On\n</IfModule>' >> /etc/apache2/apache2.conf;

a2enmod rewrite;
a2enmod geoip;
/etc/init.d/apache2 restart;
service apache2 restart;

#autoupdate geoip base
echo "9 10 * * 4  /usr/bin/geoipupdate" >> /var/spool/cron/root;
crontab -u root /var/spool/cron/root;
service cron reload;
cd;
else
  echo "Apache geoip module is already installed and running. Script will stop after 1 seconds"
  sleep 1
 exit 0
fi

say_done_2
}
#############################################################################################################

delete_alias(){
clear
f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Deleting Existing Alias from Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menudomainaliasdelete              # create an array called $menudomainaliasdelete
menudomainaliasdelete[0]=""                   # set and ignore index zero so we can count from 1

/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} ' | cut -d$'\n' -f 2- > /tmp/vhost_arr.txt
#echo "$(/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} )'" > /tmp/vhost_arr.txt

# read menu file line-by-line, save as $line
while IFS= read -r line; do
  menudomainaliasdelete[${#menudomainaliasdelete[@]}]="$line"  # push $line onto $menudomainaliasdelete[]
done < /tmp/vhost_arr.txt

# function to show the menu
menudomainaliasdelete() {
  echo "Please select the domain number from you want to delete alias: "
  echo ""
  for (( i=1; i<${#menudomainaliasdelete[@]}; i++ )); do
    echo "$i) ${menudomainaliasdelete[$i]}"
  done
  echo ""
}

# initial menu
menudomainaliasdelete
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menudomainaliasdelete[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menudomainaliasdelete
  read option
done

#echo "You said '$option' which is '${menudomainaliasdelete[$option]}'"


###second array with aliases

domainaliasdelete=${menudomainaliasdelete[$option]}

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menualiasdelete              # create an array called $menualiasdelete
menualiasdelete[0]=""                   # set and ignore index zero so we can count from 1

grep -i "ServerAlias" /etc/apache2/sites-available/$domainaliasdelete.conf | grep -vx ';.*' | cut -d' ' -f 26- | sed -e s/\ /\\n/g | cut -d$'\n' -f 2- > /tmp/vhost_alias_arr_del.txt


# read menu file line-by-line, save as $line
while IFS= read -r line2; do
  menualiasdelete[${#menualiasdelete[@]}]="$line2"  # push $line2 onto $menualiasdelete[]
done < /tmp/vhost_alias_arr_del.txt



# function to show the menu
menualiasdelete() {
  echo "Please select number alias you want to delete: "
  echo ""
  for (( i=1; i<${#menualiasdelete[@]}; i++ )); do
    echo "$i) ${menualiasdelete[$i]}"
  done
  echo ""
}

# initial menu
menualiasdelete
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menualiasdelete[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menualiasdelete
  read option
done

#echo "You said '$option' which is '${menualiasdelete[$option]}'"

deletealias=${menualiasdelete[$option]}

sed -r "s/[ ]\<$deletealias\>//g" -i /etc/apache2/sites-available/$domainaliasdelete.conf

say_done_2
}

#############################################################################################################
disable_vhost(){
clear
f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Disable Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menudisablevhost              # create an array called $menudisablevhost
menudisablevhost[0]=""                   # set and ignore index zero so we can count from 1

/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} ' | cut -d$'\n' -f 2- > /tmp/vhost_arr.txt
#echo "$(/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} )'" > /tmp/vhost_arr.txt

# read menu file line-by-line, save as $line
while IFS= read -r line; do
  menudisablevhost[${#menudisablevhost[@]}]="$line"  # push $line onto $menudisablevhost[]
done < /tmp/vhost_arr.txt

# function to show the menu
menudisablevhost() {
  echo "Please select the number domain vhost that you want to disable: "
  echo ""
  for (( i=1; i<${#menudisablevhost[@]}; i++ )); do
    echo "$i) ${menudisablevhost[$i]}"
  done
  echo ""
}

# initial menu
menudisablevhost
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menudisablevhost[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menudisablevhost
  read option
done

#echo "You said '$option' which is '${menudisablevhost[$option]}'"
a2dissite ${menudisablevhost[$option]}
echo "reloading apache..."
systemctl reload apache2
say_done_2
}
#############################################################################################################
enable_vhost(){
clear
f_banner

echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m Enable Virtualhost"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""

unset option menu ERROR      # prevent inheriting values from the shell
declare -a menuenablevhost              # create an array called $menuenablevhost
menuenablevhost[0]=""                   # set and ignore index zero so we can count from 1

ls -FA /etc/apache2/sites-available/ | grep -v "/" | sed -r 's/^(.+)\.[^.]+$/\1/' > /tmp/vhost_all.txt
#echo "$(/usr/sbin/apache2ctl -S 2>&1 | awk '/namevhost/  {print $4;} )'" > /tmp/vhost_all.txt

# read menu file line-by-line, save as $line
while IFS= read -r line; do
  menuenablevhost[${#menuenablevhost[@]}]="$line"  # push $line onto $menuenablevhost[]
done < /tmp/vhost_all.txt

# function to show the menu
menuenablevhost() {
  echo "Please select the number domain vhost that you want to enable: "
  echo ""
  for (( i=1; i<${#menuenablevhost[@]}; i++ )); do
    echo "$i) ${menuenablevhost[$i]}"
  done
  echo ""
}

# initial menu
menuenablevhost
read option

# loop until given a number with an associated menu item
while ! [ "$option" -gt 0 ] 2>/dev/null || [ -z "${menuenablevhost[$option]}" ]; do
  echo "No such option '$option'" >&2  # output this to standard error
  menuenablevhost
  read option
done

#echo "You said '$option' which is '${menuenablevhost[$option]}'"
a2ensite ${menuenablevhost[$option]}
echo "reloading apache..."
systemctl reload apache2
say_done_2
}
#############################################################################################################
show_list_virtualhosts(){
clear
f_banner

echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
   echo -e "\e[93m[+]\e[00m List All Virtualhosts"
   echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
spinner
echo ""
#to enable debug mode uncomment the string below
#do not enable on REAL PRODUCTION USE!
#set -x
# Author: Oliver Rex
	INVERSE='\033[7m'  #  ${INVERSE}
	NORMAL='\033[0m'   #  ${NORMAL}

#in case of fire: steal, kill, fuck the geese, wait for a dial tone response
whereismywebserver () {
	software80=$(netstat -tulpn | grep :80 | awk -F "/" '{print $NF}' | sed s/' '//g) #last word from output
	if [[ $software80 ]]; then
		softwareconf=$(echo $software80'.conf') #filename to locate
		locate $softwareconf || whereis $software80 || which $software80 #a last hope
	else
		echo -en Unfortunately Apache is not present on this server. Your web daemon is not found on port 80 using netstat. '\n' Please use ${INVERSE}"lsof -i :80 | grep LISTEN"${NORMAL} or try to start webserver daemon! '\n'
		exit 0
	fi
	if [ ! $software80 ]; then
		echo -en Also you can review your virtual hosts without this script! '\n'
	else 
		echo -en Unfortunately Apache is not present on this server. Your web daemon is called ${INVERSE}$software80${NORMAL} '\n' Please try to review your virtual hosts without this script! '\n'
		exit 0
	fi
}

#Set config path to find conf files
if [ -d '/etc/httpd/' ]; then
	cfpath='/etc/httpd/' #RHEL way
elif [ -d '/etc/apache2/' ]; then
	cfpath='/etc/apache2/' #Debian way
else 
	whereismywebserver #Jedi way
fi

#cat all configuration files, filter junk: commented lines, empty lines, etc
rawdata=$(find $cfpath -type f -name '*.conf' -exec cat {} \;| sed 's/^[ \t]*//' | grep -v ^[#] | awk 'NF')

#show column headings
echo -en ${INVERSE}'VHOST:PORT' 'DOMAIN' 'ALIASES' 'DIRECTORY' '\n' | column -t
echo -en ${NORMAL}

#parse prefiltered data
echo "$rawdata"| awk \
                '/^<VirtualHost*/,/^<\/VirtualHost>/\
                        {if\
                        (/^<\/VirtualHost>/)p=1;\
                        if\
                                        (/ServerName|VirtualHost|ServerAlias|DocumentRoot|## User/)out = \
                                                out (out?OFS:"") (/User/?$3:$2)}\
                                p{print out;p=0;out=""}' | 
sed -s 's/>//g' | column -t

#FIN!

say_done_2
}
#############################################################################################################


menu=""
until [ "$menu" = "10" ]; do

clear
f_banner

echo
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo -e "\e[93m[+]\e[00m SELECT WHAT YOU WANT TO DO"
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""

echo "1. Show list with all virtualhosts"
echo "2. Install apache with maxmind geobase"
echo "3. Create independent virtualhost"
echo "4. Delete independent virtualhost"
echo "5. Add alias to existing domain"
echo "6. Only start Certbot"
echo "7. Disable vhost"
echo "8. Enable vhost"
echo "9. Remove alias"
echo "10. Exit"
echo

read menu
case $menu in

1)
show_list_virtualhosts
;;

2)
install_apache_maxmind
new_virtualhost_create
start_certbot
;;

3)
new_virtualhost_create
start_certbot
;;

4)
new_virtualhost_delete
;;

5)
add_alias_virtualhost
start_certbot
;;

6)
start_certbot
;;

7)
disable_vhost
;;

8)
enable_vhost
;;

9)
delete_alias
;;

10)
break
;;

*) ;;

esac
done
