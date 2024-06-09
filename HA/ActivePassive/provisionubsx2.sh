yes | sudo ufw enable 

# update app repository
echo "update app repository"

apt-get update
apt upgrade


sudo apt install -y apache2 mariadb-server libapache2-mod-php php-gd php-mysql \
php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip sshpass
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php8.2
php --version
a2dismod php7.4 
a2enmod php8.2 
	
# Install PHP 8.2 and required modules - OFF FOR SPEED

sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-mysql php8.2-bcmath php8.2-intl php8.2-imap php8.2-opcache php8.2-readline php8.2-soap php8.2-xsl
systemctl stop apache2
systemctl status apache2
systemctl start apache2
cd /var/www/html/
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xvf latest.tar.bz2
    
chown -R www-data: nextcloud/
chmod -R 755 nextcloud

cat << EOF > /etc/apache2/sites-available/nextcloud.conf
    Alias /nextcloud "/var/www/html/nextcloud/"

    <Directory /var/www/html/nextcloud/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews

    <IfModule mod_dav.c>
        Dav off
    </IfModule>
    </Directory>
EOF

ls -lt /etc/apache2/sites-available/nextcloud.conf

a2ensite nextcloud.conf 

a2enmod rewrite headers env dir mime
systemctl restart apache2

#not strictly needed in ubsx2?
#Allow pw auth
# sed -i 's/#   PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# rm /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
# systemctl restart sshd

#   # Wait for 10 seconds to allow the SSH daemon to start
#   sleep 15



#change bind address
sudo sed -i 's/^bind-address[[:space:]]*=[[:space:]]*127\.0\.0\.1$/bind-address            = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo sed -i 's/^#server-id[[:space:]]*=[[:space:]]*1$/server-id              = 2/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i 's/^#log_bin[[:space:]]*=[[:space:]]*\/var\/log\/mysql\/mysql-bin.log$/log_bin                = \/var\/log\/mysql\/mysql-bin.log/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb

sshpass -p 'vagrant' rsync -azp --rsh='sshpass -p vagrant ssh -o StrictHostKeyChecking=no' vagrant@192.168.56.50:/tmp/filename.txt /tmp/filename.txt
sshpass -p 'vagrant' rsync -azp --rsh='sshpass -p vagrant ssh -o StrictHostKeyChecking=no' vagrant@192.168.56.50:/tmp/position.txt /tmp/position.txt


FILENAMEVAR=$(cat /tmp/filename.txt)
POSITIONVAR=$(cat /tmp/position.txt)


mysql -u root -e "CHANGE MASTER TO
  MASTER_HOST='192.168.56.50',
  MASTER_USER='replica',
  MASTER_PASSWORD='password',
  MASTER_LOG_FILE='${FILENAMEVAR}',
  MASTER_LOG_POS=${POSITIONVAR};
START SLAVE;
SHOW SLAVE STATUS\G"


sudo apt install cifs-utils -y #required for mount
sudo mkdir /mnt/nextcloud
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/22040608mystorage.cred" ]; then
    sudo bash -c 'echo "username=20240608mystorage" >> /etc/smbcredentials/20240608mystorage.cred'
    sudo bash -c 'echo "password=kba3Wy/maxnVPLFAiXiSBxARVmxv6M0URt7F8YKaUI3NECHPJVY7uDinwKvc8+5T2ptbaIeWFgtU+ASt5tAu5A==" >> /etc/smbcredentials/20240608mystorage.cred'
fi
sudo chmod 600 /etc/smbcredentials/20240608mystorage.cred

sudo bash -c 'echo "//20240608mystorage.file.core.windows.net/20240608fileshare /mnt/nextcloud cifs nofail,credentials=/etc/smbcredentials/20240608mystorage.cred,uid=33,gid=33,dir_mode=0750,file_mode=0750,serverino,nosharesock,actimeo=30" >> /etc/fstab'
sudo mount -t cifs //20240608mystorage.file.core.windows.net/20240608fileshare /mnt/nextcloud -o credentials=/etc/smbcredentials/20240608mystorage.cred,uid=33,gid=33,dir_mode=0750,file_mode=0750,serverino,nosharesock,actimeo=30
      sudo chown -R www-data: /mnt/nextcloud
      sudo chmod -R 750 /mnt/nextcloud


#Install Nextcloud to failover

cd /var/www/html/nextcloud/

# first lets try with removing the admin user - already in database

sudo -u www-data php occ  maintenance:install \
--database='mysql' --database-name='nextcloud' \
--database-user='yoonsi' --database-pass='Deathscythe1' \
--admin-user='admin2' --admin-pass='password'

sudo mysql << EOF
use nextcloud;
delete from oc_storages where numeric_id=2;
EOF

cd /var/www/html/nextcloud/config/

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/0 => '"'localhost'"',/a\
    1 => '"'192.168.56.51'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/1 => '"'192.168.56.51'"',/a\
    2 => '"'192.168.56.100'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php

config_file="/var/www/html/nextcloud/config/config.php"
new_value="'datadirectory' => '/mnt/nextcloud'"

    sed -i "s|'datadirectory' => '.*'|$new_value|" "$config_file"


chown -R www-data: /var/www/html/nextcloud/
chmod -R 755 /var/www/html/nextcloud


sudo ufw enable
sudo ufw allow 5405/udp
sudo ufw allow 22/tcp 
sudo ufw allow 3306/tcp
sudo ufw allow 3306/udp
sudo ufw allow 80/tcp

#### Add corosync stuff to end of both provisions


# might be the case that I don't need to do any different steps on the second server. Might be able to run this on both. 
# try when possible.

# install corosync & pacemaker - make sure you understand exactly what these two do
sudo apt install -y corosync pacemaker

# update this to do a test                  TODO

sudo rm -f /etc/corosync/corosync.conf

sudo cat << EOF > /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    cluster_name: mycluster
    transport: udpu
    interface {
        ringnumber: 0
        bindnetaddr: 192.168.56.0
        mcastport: 5405
    }
}

logging {
    fileline: off
    to_stderr: yes
    to_logfile: yes
    logfile: /var/log/corosync/corosync.log
    to_syslog: yes
    debug: off
    timestamp: on
    logger_subsys {
        subsys: AMF
        debug: off
        tags: enter|leave|trace1|trace2|trace3|trace4|trace6
    }
}

nodelist {
    node {
        ring0_addr: 192.168.56.50
        nodeid: 1
        name: ubsx
    }

    node {
        ring0_addr: 192.168.56.51
        nodeid: 2
        name: ubsx2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

EOF


#setting IP info for ubsx2
echo "setting IP info for ubsx2"

sudo echo "192.168.56.50     ubsx" >> /etc/hosts

sudo ip link set enp0s8 down
sudo ip addr flush dev enp0s8
sudo ip addr add 192.168.56.51/24 dev enp0s8
sudo ip link set enp0s8 up
ip addr

sudo chmod 755 /etc/corosync/corosync.conf 


#some stuff to do here on ubsx2 - complete after - actually not?

sudo systemctl start corosync
sudo systemctl enable corosync
sudo systemctl start pacemaker
sudo systemctl enable pacemaker

sudo systemctl status corosync
sudo systemctl status pacemaker


sudo crm_mon -1


sudo systemctl restart corosync
sudo systemctl restart pacemaker





