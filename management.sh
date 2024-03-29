#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh
echo "Installing wspecsbox system management daemon..."

# DEPENDENCIES

# We used to install management daemon-related Python packages
# directly to /usr/local/lib. We moved to a virtualenv because
# these packages might conflict with apt-installed packages.
# We may have a lingering version of acme that conflcits with
# certbot, which we're about to install below, so remove it
# first. Once acme is installed by an apt package, this might
# break the package version and `apt-get install --reinstall python3-acme`
# might be needed in that case.
while [ -d /usr/local/lib/python3.4/dist-packages/acme ]; do
	pip3 uninstall -y acme;
done

# duplicity is used to make backups of user data. It uses boto
# (via Python 2) to do backups to AWS S3. boto from the Ubuntu
# package manager is too out-of-date -- it doesn't support the newer
# S3 api used in some regions, which breaks backups to those regions.
# See #627, #653.
#
# virtualenv is used to isolate the Python 3 packages we
# install via pip from the system-installed packages.
#
# certbot installs EFF's certbot which we use to
# provision free TLS certificates.
apt_install duplicity python3-pip virtualenv certbot
hide_output pip3 install --upgrade boto

# Create a virtualenv for the installation of Python 3 packages
# used by the management daemon.
inst_dir=/usr/local/lib/wspecsbox
mkdir -p $inst_dir
venv=$inst_dir/env
if [ ! -d $venv ]; then
	hide_output virtualenv -ppython3 $venv
fi

# Upgrade pip because the Ubuntu-packaged version is out of date.
hide_output $venv/bin/pip install --upgrade pip

# Install other Python 3 packages used by the management daemon.
# The first line is the packages that Josh maintains himself!
# NOTE: email_validator is repeated in setup/questions.sh, so please keep the versions synced.
hide_output $venv/bin/pip install --upgrade \
	rtyaml "email_validator>=1.0.0" "exclusiveprocess" \
	flask dnspython python-dateutil \
	"idna>=2.0.0" "cryptography==2.2.2" boto psutil postfix-mta-sts-resolver

# CONFIGURATION

# Create a backup directory and a random key for encrypting backups.
mkdir -p $STORAGE_ROOT/backup
if [ ! -f $STORAGE_ROOT/backup/secret_key.txt ]; then
	$(umask 077; openssl rand -base64 2048 > $STORAGE_ROOT/backup/secret_key.txt)
fi


# Download jQuery and Bootstrap local files

# Make sure we have the directory to save to.
assets_dir=$inst_dir/vendor/assets
rm -rf $assets_dir
mkdir -p $assets_dir

# jQuery CDN URL
jquery_version=3.5.1
jquery_url=https://code.jquery.com

# Get jQuery
wget_verify $jquery_url/jquery-$jquery_version.min.js c8e1c8b386dc5b7a9184c763c88d19a346eb3342 $assets_dir/jquery.min.js

# Bootstrap CDN URL
bootstrap_version=4.5.2
bootstrap_url=https://github.com/twbs/bootstrap/releases/download/v$bootstrap_version/bootstrap-$bootstrap_version-dist.zip

# Get Bootstrap
wget_verify $bootstrap_url f23782f6f421c167b3101270dfc89d8a4d36dbe9 /tmp/bootstrap.zip
unzip -q /tmp/bootstrap.zip -d $assets_dir
mv $assets_dir/bootstrap-$bootstrap_version-dist $assets_dir/bootstrap
rm -f /tmp/bootstrap.zip

cp -r conf $inst_dir
cp -r tools $inst_dir
cp -r management $inst_dir
find $inst_dir -type f -exec sed -i "s/phpPHP_VERSION/php$PHP_VERSION/g" {} \;
# Create an init script to start the management daemon and keep it
# running after a reboot.
cat > $inst_dir/start <<EOF
#!/bin/bash
source $venv/bin/activate
exec python3 $inst_dir/management/daemon.py
EOF
chmod +x $inst_dir/start
cp --remove-destination wspecsbox.service /lib/systemd/system/wspecsbox.service # target was previously a symlink so remove it first
hide_output systemctl link -f /lib/systemd/system/wspecsbox.service
hide_output systemctl daemon-reload
hide_output systemctl enable wspecsbox.service

# Perform nightly tasks at 3am in system time: take a backup, run
# status checks and email the administrator any changes.

cat > /etc/cron.d/wspecsbox-nightly << EOF
# wspecsbox --- Do not edit / will be overwritten on update.
# Run nightly tasks: backup, status checks.
0 3 * * *	root	(cd /usr/local/lib/wspecsbox && management/daily_tasks.sh)
EOF

# Start the management server.
restart_service wspecsbox

# Wait for the management daemon to start...
until nc -z -w 4 127.0.0.1 10222
do
  echo Waiting for the wspecsbox management daemon to start...
  sleep 2
done

# ...and then have it write the DNS and nginx configuration files and start those
# services.
mkdir -p /etc/nginx/conf.d/partials
tools/dns_update
tools/web_update

# Give fail2ban another restart. The log files may not all have been present when
# fail2ban was first configured, but they should exist now.
restart_service fail2ban
