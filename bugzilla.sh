#!/bin/bash

dbs_name=bugzilla
dbs_user=bugsbunny
dbs_pass=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c6`
web_user=www-data

function configweb {
	lighttpd-enable-mod cgi
	echo  "				
	cgi.assign      = (		  
	".pl"  => "/usr/bin/perl",      
	)" >> /etc/lighttpd/conf-enabled/10-cgi.conf
	/etc/init.d/lighttpd reload
}

echo "Hello, I will try to install BugZilla for you"

#check for debian
if [ -e /etc/debian_version ]; then
	echo "I see you are on Debian version `cat /etc/debian_version`"
else
	echo "You are not on Debian, gross."
	exit 1
fi
#check for web server
if lighttpd -v; then
	echo "It seems that you're running lighttpd. I will assume the document root is /var/www" 
	configweb
else
	echo "You do not appear to be running a web server"
	apt-get install lighttpd
fi

#check for mysql server
if mysqld -V; then
	echo "Looks like mysql server is installed. Moving along..."
else
	echo "Mysql does not appear to be installed."
	apt-get install mysql-server
fi

echo "Which version of Bugzilla would you like?"
echo "Enter 1 for stable, 2 for testing"
read distribution

if [ $distribution = "1" ]; then
	version=bugzilla-3.6.2.tar.gz
elif [ $distribution == "2" ]; then
	version=bugzilla-3.7.3.tar.gz
else
	echo "Dude, I said stable or unstable, not $distribution."
	exit 1
fi

cd /tmp/
rm $version
wget http://ftp.mozilla.org/pub/mozilla.org/webtools/$version 
tar --directory /var/www -xzf $version
mv /var/www/`basename $version .tar.gz` /var/www/bugzilla

echo "Fetching Debian Dependencies" 
# These are the Debian dependencies for bugzilla - probably a good enough guess for these purposes
  apt-get install libappconfig-perl libcdt4 libcgi-pm-perl libchart-perl \
  libclass-accessor-perl libclass-singleton-perl libdatetime-locale-perl \
  libdatetime-perl libdatetime-timezone-perl libemail-abstract-perl \
  libemail-address-perl libemail-date-format-perl libemail-messageid-perl \
  libemail-mime-contenttype-perl libemail-mime-encodings-perl \
  libemail-mime-perl libemail-send-io-perl libemail-send-perl \
  libemail-simple-perl libexiv2-9 libfcgi-perl libfilter-perl libgd-gd2-perl \
  libgd-graph-perl libgd-graph3d-perl libgd-text-perl libgraph4 libgvc5 \
  libio-all-perl libjs-yui liblist-moreutils-perl liblqr-1-0 libmagickcore3 \
  libmagickcore3-extra libmagickwand3 libmime-types-perl libnetpbm10 \
  libparams-validate-perl libpathplan4 libreturn-value-perl libspiffy-perl \
  libsub-name-perl libtemplate-perl libtemplate-plugin-gd-perl libxdot4 netpbm \
  perlmagick ufraw-batch imagemagick libtimedate-perl libtemplate-perl 	\
  libemail-mime-perl liburi-perl libemail-send-perl libemail-mime-contenttype-perl 
  libemail-mime-modifier-perl liblist-moreutils-perl libappconfig-perl  \
  libdate-calc-perl libtemplate-perl libmime-perl build-essential 	\
  libdatetime-timezone-perl libdatetime-perl libemail-send-perl libemail-mime-perl \
  libemail-mime-modifier-perl  

# Install perl dependencies
cd /var/www/bugzilla
for module in Email::MIME::Encodings Template; do
	perl install-module.pl $module
done

echo "Creating database, you will need your root database password"
mysql -u root -p -e "create database $dbs_name;"
mysql -u root -p -e "GRANT ALL ON $dbs_name.* TO $dbs_user@localhost IDENTIFIED BY '$dbs_pass';"

#Set the localconfig options
echo "  \$db_name = '$dbs_name';
        \$db_user = '$dbs_user';
        \$db_pass = '$dbs_pass';
        \$web_user = '$webservergroup';
        \$db_port = '3306';" > /var/www/bugzilla/localconfig

#Finally run the Bugzilla Setup
perl /var/www/bugzilla/checksetup.pl
#Again once auto-conf is done
perl /var/www/bugzilla/checksetup.pl

