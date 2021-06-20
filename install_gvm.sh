#!/bin/bash
######################################################################
# Script to install Greenbone/OpenVAS on Ubuntu 20.04 or Debian 10
#
# Note: run as root
#
# Usage: sudo ./install_gvm.sh 
#
# Based on:
# https://kifarunix.com/install-and-setup-gvm-11-on-ubuntu-20-04/?amp
#
# Licensed under GPLv3 or later
######################################################################

# Find out which version to install from user
read -p "Would you like to install version 20 or 21? " GVMVERSION

#validate input
if [[ $GVMVERSION = "21" ]] || [[ $GVMVERSION = "20" ]]; then
    echo "Okay, installing version $GVMVERSION"
else 
    echo "Sorry, I didn't understand the input $GVMVERSION."
    echo "Please re-run install_gvm.sh and enter a version number at the prompt"
    exit 1
fi

#GVMVERSION='21'

gvm_run() {
    sudo -Hiu gvm $@
}
postgres_run() {
    sudo -Hiu postgres $@
}

apt-get update
apt-get upgrade -y 
useradd -r -d /opt/gvm -c "GVM (OpenVAS) User" -s /bin/bash gvm
mkdir /opt/gvm
chown gvm:gvm /opt/gvm
apt-get -y install gcc g++ make bison flex libksba-dev curl redis libpcap-dev cmake \
    git pkg-config libglib2.0-dev libgpgme-dev libgnutls28-dev uuid-dev libssh-gcrypt-dev \
    libldap2-dev gnutls-bin libmicrohttpd-dev libhiredis-dev zlib1g-dev libxml2-dev libradcli-dev clan\
    g-format libldap2-dev doxygen nmap gcc-mingw-w64 xml-twig-tools libical-dev perl-base heimdal-dev \
    libpopt-dev libsnmp-dev python3-setuptools python3-paramiko python3-lxml python3-defusedxml python3-dev \
    gettext python3-polib xmltoman python3-pip texlive-fonts-recommended xsltproc texlive-latex-extra rsync ufw\
    ntp libunistring-dev git libnet1-dev graphviz graphviz-dev --no-install-recommends
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get -y install yarn

# addresses issue #7 on GH
/usr/bin/yarn install
/usr/bin/yarn upgrade

apt-get -y install postgresql postgresql-contrib postgresql-server-dev-all
systemctl restart postgresql
sudo -Hiu postgres createuser gvm
sudo -Hiu postgres createdb -O gvm gvmd
sudo -Hiu postgres psql -c 'create role dba with superuser noinherit;' gvmd
sudo -Hiu postgres psql -c 'grant dba to gvm;' gvmd
sudo -Hiu postgres psql -c 'create extension "uuid-ossp";' gvmd
sudo -Hiu postgres psql -c 'create extension "pgcrypto";' gvmd
systemctl restart postgresql
systemctl enable postgresql

# Taking the below out. If anyone wants to make another attempt to get this working on Kali
# feel free.
# Kali Linux uses postgresql 13 which cmake doesn't know about as of version 3.18 so it get's added here
# should have no effect on Debian stable as the line starts with "11" rather than "12" so it won't be matched.
# It throws an error but it's not critical.
ID=`grep ^ID= /etc/os-release | sed 's/ID=//g'`
#if [[ $ID = "kali" ]]; then
#    sed -i 's/"12" "11" "10"/"13" "12" "11" "10"/g' /usr/share/cmake-3.18/Modules/FindPostgreSQL.cmake
#fi

sed -i 's/\"$/\:\/opt\/gvm\/bin\:\/opt\/gvm\/sbin\:\/opt\/gvm\/\.local\/bin\"/g' /etc/environment
echo "/opt/gvm/lib" > /etc/ld.so.conf.d/gvm.conf
gvm_run mkdir /tmp/gvm-source
cd /tmp/gvm-source

if [ $GVMVERSION = "20" ]; then
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/gvm-libs.git
    gvm_run git clone https://github.com/greenbone/openvas-smb.git
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/openvas.git
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/ospd.git
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/ospd-openvas.git
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/gvmd.git
    gvm_run git clone -b v20.8.1 https://github.com/greenbone/gsa.git
    gvm_run git clone https://github.com/greenbone/python-gvm.git
    gvm_run git clone https://github.com/greenbone/gvm-tools.git
elif [ $GVMVERSION = "21" ]; then
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/gvm-libs.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/openvas-smb.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/openvas.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/ospd.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/ospd-openvas.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/gvmd.git
    gvm_run git clone -b v21.4.0 https://github.com/greenbone/gsa.git
    gvm_run git clone -b v21.1.3 https://github.com/greenbone/python-gvm.git
    gvm_run git clone -b v21.1.0 https://github.com/greenbone/gvm-tools.git
fi

gvm_run cp --recursive /opt/gvm/* /tmp/gvm-source/


# Kali linux 2020.4 puts a message about python2 in that's causing problems below. This should workaround.
if [[ $ID = "debian" ]] || [[ $ID = "kali" ]]; then
    touch /opt/gvm/.hushlogin
    chown gvm:gvm /opt/gvm/.hushlogin
    touch /root/.hushlogin
fi

# TODO should refactor this to write out a script for the gvm user to execute like the ones later in 
# this script leaving .bashrc alone. I initially used .bashrc just because it was automatically
# executed when switching to the gvm user.
gvm_run touch /opt/gvm/.bashrc
gvm_run mv /opt/gvm/.bashrc /opt/gvm/.bashrc.bak # save original bashrc file 
gvm_run touch /opt/gvm/.bashrc
gvm_run echo "export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH" | gvm_run tee -a /opt/gvm/.bashrc

# Build and Install GVM Libraries
gvm_run echo "cd /opt/gvm/gvm-libs" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "mkdir build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cd build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/.bashrc

# Build and Install OpenVAS and OpenVAS SMB
gvm_run echo "cd ../../openvas-smb/" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "mkdir build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cd build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cd ../../openvas" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "mkdir build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cd build" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "sed -i 's/set (CMAKE_C_FLAGS_DEBUG\s.*\"\${CMAKE_C_FLAGS_DEBUG} \${COVERAGE_FLAGS}\")/set (CMAKE_C_FLAGS_DEBUG \"\${CMAKE_C_FLAGS_DEBUG} -Werror -Wno-error=deprecated-declarations\")/g' ../../openvas/CMakeLists.txt" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make" | gvm_run tee -a /opt/gvm/.bashrc
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/.bashrc
# Leave gvm environment and clean up
gvm_run echo "exit" | gvm_run tee -a /opt/gvm/.bashrc
su gvm
gvm_run rm /opt/gvm/.bashrc
gvm_run mv /opt/gvm/.bashrc.bak /opt/gvm/.bashrc

# Configuring OpenVAS
ldconfig
cp /tmp/gvm-source/openvas/config/redis-openvas.conf /etc/redis/
chown redis:redis /etc/redis/redis-openvas.conf
echo "db_address = /run/redis-openvas/redis.sock" > /opt/gvm/etc/openvas/openvas.conf
chown gvm:gvm /opt/gvm/etc/openvas/openvas.conf
usermod -aG redis gvm
echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl -p

cat < /etc/systemd/system/disable_thp.service << EOF
[Unit]
Description=Disable Kernel Support for Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c \"echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag\"

[Install]
WantedBy=multi-user.target
EOF

stemctl daemon-reload
systemctl enable --now disable_thp
systemctl start redis-server@openvas
systemctl enable redis-server@openvas
echo "gvm ALL = NOPASSWD: /opt/gvm/sbin/openvas" > /etc/sudoers.d/gvm
# This next line varies between Debian and Ubuntu because it includes /snap/bin on Ubuntu                                                                                                    
ID=`grep ^ID= /etc/os-release | sed 's/ID=//g'`
if [[ $ID = "debian" ]] || [[ $ID = "kali" ]]; then
    sed 's/Defaults\s.*secure_path=\"\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin"/Defaults secure_path=\"\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin:\/opt\/gvm\/sbin\:\/opt\/gvm\/bin"/g' /etc/sudoers | EDITOR='tee' visudo
    
    # when adapting this script for Debian I found that there's an issue later on when the gvm user
    # tries to run greenbone-nvt-sync. The thing tries to write to /dev/stderr and receives a permission denied message
    # The code below works around the problem by adding the gvm user to the tty group and setting the permissons for group
    # read/write on the target of the /dev/stderr symlink (if you're /dev/stderr doesn't point to /dev/pts/2 you may need
    # to adjust the chmod command below.
    # more info at https://unix.stackexchange.com/questions/38538/bash-dev-stderr-permission-denied
    usermod -aG tty gvm
    #chmod g+rw /dev/pts/2 # This doesn't work consistantely 
else
    sed 's/Defaults\s.*secure_path=\"\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin:\/snap\/bin\"/Defaults secure_path=\"\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin:\/snap\/bin:\/opt\/gvm\/sbin:\/opt\/gvm\/bin"/g' /etc/sudoers | EDITOR='tee' visudo
fi

echo "gvm ALL = NOPASSWD: /opt/gvm/sbin/gsad" >> /etc/sudoers.d/gvm

# Build and Install Greenbone Vulnerability Manager
su gvm -c "touch /opt/gvm/gvm_build.sh"
su gvm -c "chmod u+x /opt/gvm/gvm_build.sh"

gvm_run echo "export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "cd /tmp/gvm-source/gvmd" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "mkdir build" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "cd build" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "make" | gvm_run tee -a /opt/gvm/gvm_build.sh
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/gvm_build.sh

su gvm -c "/opt/gvm/gvm_build.sh"
su gvm -c "rm /opt/gvm/gvm_build.sh"

# Build and Install Greenbone Secuirty Assistant
su gvm -c "touch /opt/gvm/gsa_build.sh"
su gvm -c "chmod u+x /opt/gvm/gsa_build.sh"

gvm_run echo "export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH" | gvm_run tee -a /opt/gvm/gsa_build.sh
gvm_run echo "cd /tmp/gvm-source/gsa" | gvm_run tee -a /opt/gvm/gsa_build.sh
gvm_run echo "mkdir build" | gvm_run tee -a /opt/gvm/gsa_build.sh
gvm_run echo "cd build" | gvm_run tee -a /opt/gvm/gsa_build.sh

ID=`grep ^ID= /etc/os-release | sed 's/ID=//g'`
if [[ $ID = "debian" ]] || [[ $ID = "kali" ]]; then
    gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm -DCMAKE_BUILD_TYPE=RELEASE" | gvm_run tee -a /opt/gvm/gsa_build.sh
else
    gvm_run echo "cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gvm" | gvm_run tee -a /opt/gvm/gsa_build.sh
fi
gvm_run echo "make" | gvm_run tee -a /opt/gvm/gsa_build.sh
gvm_run echo "make install" | gvm_run tee -a /opt/gvm/gsa_build.sh

su gvm -c "/opt/gvm/gsa_build.sh"
su gvm -c "rm /opt/gvm/gsa_build.sh"

# Set cron jobs to run once daily at random times
su gvm -c "touch /opt/gvm/cron.sh"
su gvm -c "chmod u+x /opt/gvm/cron.sh"

HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
gvm_run echo "(crontab -l 2>/dev/null; echo \"${MINUTE} ${HOUR} * * * /opt/gvm/sbin/greenbone-feed-sync --type SCAP\") | crontab -" | gvm_run tee -a /opt/gvm/cron.sh


HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
gvm_run echo "(crontab -l 2>/dev/null; echo \"${MINUTE} ${HOUR} * * * /opt/gvm/bin/greenbone-nvt-sync\") | crontab -" | gvm_run tee -a /opt/gvm/cron.sh


HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
gvm_run echo "(crontab -l 2>/dev/null; echo \"${MINUTE} ${HOUR} * * * /opt/gvm/sbin/greenbone-feed-sync --type CERT\") | crontab -" | gvm_run tee -a /opt/gvm/cron.sh


HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
gvm_run echo "(crontab -l 2>/dev/null; echo \"${MINUTE} ${HOUR} * * * /opt/gvm/sbin/greenbone-feed-sync --type GVMD_DATA\") | crontab -" | gvm_run tee -a /opt/gvm/cron.sh


# I know this is kludgy as this should be run after the nvt sync but if it gets 
# run once a day that should do
HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
gvm_run echo "(crontab -l 2>/dev/null; echo \"${MINUTE} ${HOUR} * * * /usr/bin/sudo /opt/gvm/sbin/openvas --update-vt-info\") | crontab -" | gvm_run tee -a /opt/gvm/cron.sh

# Configure certs
gvm_run echo "/opt/gvm/bin/gvm-manage-certs -a" | gvm_run tee -a /opt/gvm/cron.sh

su gvm -c "/opt/gvm/cron.sh"
su gvm -c "rm /opt/gvm/cron.sh"

# not sure why the below is failing when running straight through but working when I try to step though it manually; could be a timing issue
echo "Sleeping for 30 seconds..."
sleep 30

# Build and Install OSPd and OSPd-OpenVAS
su gvm -c "touch /opt/gvm/ospd.sh"
su gvm -c "chmod u+x /opt/gvm/ospd.sh"

gvm_run echo "export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH" | gvm_run tee -a /opt/gvm/ospd.sh

# another difference here between Ubuntu and Debian
# Debian needs the below to be 'python3.7' while Ubuntu 'python3.8'
# going to just get the python3 version number and use it here. That should be better than trying
# to account for the differences with the release ID.
PY3VER=`python3 --version | grep -o [0-9]\.[0-9]`
gvm_run echo "mkdir -p /opt/gvm/lib/python$PY3VER/site-packages/" | gvm_run tee -a /opt/gvm/ospd.sh
gvm_run echo "export PYTHONPATH=/opt/gvm/lib/python$PY3VER/site-packages" | gvm_run tee -a /opt/gvm/ospd.sh
gvm_run echo "cd /tmp/gvm-source/ospd" | gvm_run tee -a /opt/gvm/ospd.sh
gvm_run echo "python3 setup.py install --prefix=/opt/gvm" | gvm_run tee -a /opt/gvm/ospd.sh
gvm_run echo "cd ../ospd-openvas" | gvm_run tee -a /opt/gvm/ospd.sh
gvm_run echo "python3 setup.py install --prefix=/opt/gvm" | gvm_run tee -a /opt/gvm/ospd.sh

su gvm -c "/opt/gvm/ospd.sh"
su gvm -c "rm /opt/gvm/ospd.sh"

# Start OpenVAS Scanner, GSA and GVM services
# Start OpenVAS
su gvm -c "touch /opt/gvm/start.sh"
su gvm -c "chmod u+x /opt/gvm/start.sh"

PY3VER=`python3 --version | grep -o [0-9]\.[0-9]`
gvm_run echo "export PYTHONPATH=/opt/gvm/lib/python$PY3VER/site-packages" | gvm_run tee -a /opt/gvm/start.sh

#############################################################
# This next line is failing for me on Debian 10 
# at least the first time it's run; if I run the line a second time it appears to work as expected
#
# I have no clue why it fails initially then works subsequently
# We can work around this here by running the command twice but it'll 
# be handled when the thing is rebooted after it's all bulit.
#
#Error in atexit._run_exitfuncs:
#Traceback (most recent call last):
#  File "/opt/gvm/lib/python3.7/site-packages/ospd-21.4.0-py3.7.egg/ospd/main.py", line 83, in exit_cleanup
#  File "/opt/gvm/lib/python3.7/site-packages/ospd-21.4.0-py3.7.egg/ospd/server.py", line 233, in close
#  File "/opt/gvm/lib/python3.7/site-packages/ospd-21.4.0-py3.7.egg/ospd/server.py", line 149, in close
#AttributeError: 'NoneType' object has no attribute 'shutdown'

#############################################################
gvm_run echo "/usr/bin/python3 /opt/gvm/bin/ospd-openvas --pid-file /opt/gvm/var/run/ospd-openvas.pid --log-file /opt/gvm/var/log/gvm/ospd-openvas.log --lock-file-dir /opt/gvm/var/run -u /opt/gvm/var/run/ospd.sock" | gvm_run tee -a /opt/gvm/start.sh

ID=`grep ^ID= /etc/os-release | sed 's/ID=//g'`
if [[ $ID = "debian" ]]; then
    gvm_run echo "echo \"Trying again\"" | gvm_run tee -a /opt/gvm/start.sh
    gvm_run echo "sleep 10" | gvm_run tee -a /opt/gvm/start.sh
    gvm_run echo "echo \"Should be good now\"" | gvm_run tee -a /opt/gvm/start.sh
    gvm_run echo "/usr/bin/python3 /opt/gvm/bin/ospd-openvas --pid-file /opt/gvm/var/run/ospd-openvas.pid --log-file /opt/gvm/var/log/gvm/ospd-openvas.log --lock-file-dir /opt/gvm/var/run -u /opt/gvm/var/run/ospd.sock" | gvm_run tee -a /opt/gvm/start.sh
    gvm_run echo "echo Continuing" | gvm_run tee -a /opt/gvm/start.sh
fi

# Start GVM
gvm_run echo "/opt/gvm/sbin/gvmd --osp-vt-update=/opt/gvm/var/run/ospd.sock" | gvm_run tee -a /opt/gvm/start.sh
# Start GSA
gvm_run echo "sudo /opt/gvm/sbin/gsad" | gvm_run tee -a /opt/gvm/start.sh

# Wait a moment for the above to start up
gvm_run echo "sleep 10" | gvm_run tee -a /opt/gvm/start.sh

su gvm -c "/opt/gvm/start.sh"
su gvm -c "rm /opt/gvm/start.sh"

# Create GVM Scanner
su gvm -c "touch /opt/gvm/scan.sh"
su gvm -c "chmod u+x /opt/gvm/scan.sh"
#gvm_run echo -e "/opt/gvm/sbin/gvmd --create-scanner=\"Created OpenVAS Scanner\" --scanner-type=\"OpenVAS\" --scanner-host=/opt/gvm/var/run/ospd.sock" | gvm_run tee -a /opt/gvm/scan.sh

#gvm_run echo "/opt/gvm/sbin/gvmd --get-scanners" | gvm_run tee -a /opt/gvm/scan.sh

# Verify newly created scanner
#gvm_run echo -e "UUID=\$(/opt/gvm/sbin/gvmd --get-scanners | grep Created | awk '{print \$\1}')" | sed 's/\\//g' | gvm_run tee -a /opt/gvm/scan.sh

# Wait a moment then verify the scanner
#gvm_run echo "sleep 10" | gvm_run tee -a /opt/gvm/scan.sh
#gvm_run echo -e "/opt/gvm/sbin/gvmd --verify-scanner=UUID" | sed 's/UUID/\$UUID/g' | gvm_run tee -a /opt/gvm/scan.sh

# Github Issue #23 Modify Default Scanner to use /opt/gvm/var/run/ospd.sock
gvm_run echo -e "UUID=\$(/opt/gvm/sbin/gvmd --get-scanners | grep Default | awk '{print \$\1}')" | sed 's/\\//g' | gvm_run tee -a /opt/gvm/scan.sh
gvm_run echo -e "/opt/gvm/sbin/gvmd --modify-scanner=UUID --scanner-host=/opt/gvm/var/run/ospd.sock" | sed 's/UUID/\$UUID/g' | gvm_run tee -a /opt/gvm/scan.sh
gvm_run echo "sleep 10" | gvm_run tee -a /opt/gvm/scan.sh
gvm_run echo -e "/opt/gvm/sbin/gvmd --verify-scanner=UUID" | sed 's/UUID/\$UUID/g' | gvm_run tee -a /opt/gvm/scan.sh

# Create OpenVAS (GVM) Admin
gvm_run echo -e "/opt/gvm/sbin/gvmd --create-user gvmadmin --password=StrongPass" | gvm_run tee -a /opt/gvm/scan.sh

gvm_run echo -e "/opt/gvm/sbin/gvmd --get-users --verbose | cut -d \" \" -f 2 | xargs /opt/gvm/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value " | gvm_run tee -a /opt/gvm/scan.sh

su gvm -c "/opt/gvm/scan.sh"
su gvm -c "rm /opt/gvm/scan.sh"

# seems that /opt/gvm/bin and /opt/gvm/sbin aren't in user gvm's PATH so instead of having
# all the full paths above you could put "export PATH=$PATH:/opt/gvm/bin:/opt/gvm/sbin" at 
# the start of the above scripts. Not sure which is a better solution.

# Set firewall to allow access on port 443 and 22
ufw allow 443
ufw allow 22
ufw --force enable

# Create systemd services for OpenVAS Scanner, GSA, and GVM services
PY3VER=`python3 --version | grep -o [0-9]\.[0-9]`
cat < /etc/systemd/system/openvas.service <<EOF
[Unit]
Description=Control the OpenVAS service
After=redis.service
After=postgresql.service

[Service]
ExecStartPre=-rm /opt/gvm/var/run/ospd-openvas.pid /opt/gvm/var/run/ospd.sock /opt/gvm/var/run/gvmd.sock
Type=simple
User=gvm
Group=gvm
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin

PY3VER=`python3 --version | grep -o [0-9]\.[0-9]`
Environment=PYTHONPATH=/opt/gvm/lib/python$PY3VER/site-packages

ExecStart=/usr/bin/python3 /opt/gvm/bin/ospd-openvas --pid-file /opt/gvm/var/run/ospd-openvas.pid --log-file /opt/gvm/var/log/gvm/ospd-openvas.log --lock-file-dir /opt/gvm/var/run -u /opt/gvm/var/run/ospd.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat < /etc/systemd/gvm.service << EOF
[Unit]
Description=Control the OpenVAS GVM service
After=openvas.service

[Service]
Type=simple
User=gvm
Group=gvm
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin
Environment=PYTHONPATH=/opt/gvm/lib/python$PY3VER/site-packages
ExecStart=/opt/gvm/sbin/gvmd --osp-vt-update=/opt/gvm/var/run/ospd.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat < /etc/systemd/system/gvm.path << EOF
[Unit]
Description=Start the OpenVAS GVM service when opsd.sock is available

[Path]
PathChanged=/opt/gvm/var/run/ospd.sock
Unit=gvm.service

[Install]
WantedBy=multi-user.target
EOF

cat < /etc/systemd/system/gsa.service << EOF
[Unit]
Description=Control the OpenVAS GSA service
After=openvas.service

[Service]
Type=simple
User=gvm
Group=gvm
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin
Environment=PYTHONPATH=/opt/gvm/lib/python$PY3VER/site-packages
echo -e "ExecStart=/usr/bin/sudo /opt/gvm/sbin/gsad
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

EOF

cat < /etc/systemd/system/gsa.path << EOF
[Unit]
Description=Start the OpenVAS GSA service when gvmd.sock is available

[Path]
PathChanged=/opt/gvm/var/run/gvmd.sock
Unit=gsa.service

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable --now openvas
systemctl enable --now gvm.{path,service}
systemctl enable --now gsa.{path,service}

# Update data from the feed servers
##############################################################################
#update NVT feed
su gvm -c /opt/gvm/bin/greenbone-nvt-sync
/opt/gvm/sbin/openvas --update-vt-info
# give the db a chance to update
echo "Sleeping for 5 minutes to let the DB finish the NVT update"
sleep 300
# update GVMD_DATA
su gvm -c "/opt/gvm/sbin/greenbone-feed-sync --type GVMD_DATA"
echo "Sleeping for 5 minutes to let the DB finish the GVMD_DATA update"
sleep 300
# update SCAP
su gvm -c "/opt/gvm/sbin/greenbone-feed-sync --type SCAP"
echo "Sleeping for 5 minutes to let the DB finish the SCAP update"
sleep 300
# update CERT
su gvm -c "/opt/gvm/sbin/greenbone-feed-sync --type CERT"
echo "Sleeping for 5 minutes to let the DB finish the CERT update"
sleep 300
############################################################################

# REMIND USER TO CHANGE DEFAULT PASSWORD
echo "The installation is done, but there may still be an update in progress."
echo "Please be patient if you aren't able to log in at first."
echo "You may also need to restart"
if [ $GVMVERSION = "20" ] || [ $GVMVERSION = "21" ]; then
    echo ""
    echo "If you're unable to log in to the web interface try restarting"
    echo "and running all of the update commands in the gvm user's crontab"
    echo "sudo su gvm -c \"crontab -l\""
    echo "and ensure they complete successfully. Alternatively, leave the machine running"
    echo "for 24 hours and let cron handle it."
    echo ""
fi
echo "Username is gvmadmin and pasword is StrongPass"
echo "Remember to change this default password"
echo "gvm_run gvmd --user=gvmadmin --new-password=<PASSWORD>"
