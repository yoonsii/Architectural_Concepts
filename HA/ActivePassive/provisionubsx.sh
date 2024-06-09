
      # update app repository
    yes | sudo ufw enable 

      echo "update app repository"

      apt-get update
      apt upgrade

      # install all the required apps
      echo "install all the required apps"
      sudo apt install -y apache2 mariadb-server libapache2-mod-php php-gd php-mysql \
      php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip
      sudo apt install -y software-properties-common
      sudo add-apt-repository ppa:ondrej/php
      sudo apt update
   	  sudo apt install -y php8.2
   	  php --version

      # disable php7.4
      a2dismod php7.4 

      # enable php8.2
      a2enmod php8.2 
    
    # Install PHP 8.2 and required modules

      sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-mysql php8.2-bcmath php8.2-intl php8.2-imap php8.2-opcache php8.2-readline php8.2-soap php8.2-xsl
      systemctl stop apache2
      systemctl status apache2
      systemctl start apache2

    # Download and install NextCloud

      cd /var/www/html/
      wget https://download.nextcloud.com/server/releases/latest.tar.bz2
      tar -xvf latest.tar.bz2
        
      chown -R www-data: nextcloud/
      chmod -R 755 nextcloud

    #Create the NextCloud config file for apache site

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

# enable the site

a2ensite nextcloud.conf 

# required apache mods for nextcloud 

a2enmod rewrite headers env dir mime
systemctl restart apache2
ip addr

#change bind address
sudo sed -i 's/^bind-address[[:space:]]*=[[:space:]]*127\.0\.0\.1$/bind-address            = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

echo "Mark1"
sudo sed -i 's/^#\(server-id[[:space:]]*=[[:space:]]*1\)$/\1/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i 's/^#\(log_bin[[:space:]]*=[[:space:]]*\/var\/log\/mysql\/mysql-bin.log\)$/\1/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb

## Getting log file position and name


MASTER_STATUS=$(sudo mysql -u root -e "SHOW MASTER STATUS\\G")

# Extract the File and Position values using grep and awk
FILE=$(echo "$MASTER_STATUS" | grep 'File:' | awk '{print $2}')
POSITION=$(echo "$MASTER_STATUS" | grep 'Position:' | awk '{print $2}')

# Output the captured values
echo "File: $FILE"
echo "Position: $POSITION"

# Use the captured values in your script
# For example, storing them in variables
FILE_VARIABLE=$FILE
POSITION_VARIABLE=$POSITION


# Output the variable values
echo $FILE_VARIABLE > /tmp/filename.txt
echo $POSITION_VARIABLE > /tmp/position.txt



#Connect to MySQL
sudo mysql << EOF
CREATE USER 'yoonsi'@'localhost' IDENTIFIED BY 'Deathscythe1';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'yoonsi'@'localhost';
FLUSH PRIVILEGES;
EOF

#Connect to MySQL and create the replication user
sudo mysql << EOF | tee /tmp/mysql.log
CREATE USER 'replica'@'%' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
EOF


##EXPERIMENTAL
# sudo mysql -u root -e "CREATE USER 'yoonsi'@'localhost' IDENTIFIED BY 'ypassword';"
# sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
# sudo mysql -u root -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'yoonsi'@'localhost';"
# sudo mysql -u root -e "FLUSH PRIVILEGES;"
# sudo mysql -u root -e "CREATE USER 'replica'@'%' IDENTIFIED BY 'rpassword';"
# sudo mysql -u root -e "GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';"
# sudo mysql -u root -e "FLUSH PRIVILEGES;"
# sudo mysql -u root -e "FLUSH TABLES WITH READ LOCK;"
# sudo echo "Master status:"
# sudo mysql -u root -e "SHOW MASTER STATUS;" | tee /tmp/masterstatus.log
# sudo mysql -u root -e "UNLOCK TABLES;"


sudo apt install cifs-utils -y #required for mount
sudo mkdir /mnt/nextcloud
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/20240608mystorage.cred" ]; then
    sudo bash -c 'echo "username=20240608mystorage" >> /etc/smbcredentials/20240608mystorage.cred'
    sudo bash -c 'echo "password=kba3Wy/maxnVPLFAiXiSBxARVmxv6M0URt7F8YKaUI3NECHPJVY7uDinwKvc8+5T2ptbaIeWFgtU+ASt5tAu5A==" >> /etc/smbcredentials/20240608mystorage.cred'
fi
sudo chmod 600 /etc/smbcredentials/20240608mystorage.cred

sudo bash -c 'echo "//20240608mystorage.file.core.windows.net/20240608fileshare /mnt/nextcloud cifs nofail,credentials=/etc/smbcredentials/20240608mystorage.cred,uid=33,gid=33,dir_mode=0750,file_mode=0750,serverino,nosharesock,actimeo=30" >> /etc/fstab'
sudo mount -t cifs //20240608mystorage.file.core.windows.net/20240608fileshare /mnt/nextcloud -o credentials=/etc/smbcredentials/20240608mystorage.cred,uid=33,gid=33,dir_mode=0750,file_mode=0750,serverino,nosharesock,actimeo=30
      sudo chown -R www-data: /mnt/nextcloud
      sudo chmod -R 750 /mnt/nextcloud




cd /var/www/html/nextcloud/

sudo -u www-data php occ  maintenance:install \
--database='mysql' --database-name='nextcloud' \
--database-user='yoonsi' --database-pass='Deathscythe1' \
--admin-user='admin' --admin-pass='password'

sudo rsync -avz /var/www/html/nextcloud/data/ /mnt/nextcloud/

cd /var/www/html/nextcloud/config/

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/0 => '"'localhost'"',/a\
    1 => '"'192.168.56.50'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/1 => '"'192.168.56.50'"',/a\
    2 => '"'192.168.56.100'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php

config_file="/var/www/html/nextcloud/config/config.php"
new_value="'datadirectory' => '/mnt/nextcloud'"

    sed -i "s|'datadirectory' => '.*'|$new_value|" "$config_file"


	chown -R www-data: /var/www/html/nextcloud/
	chmod -R 755 /var/www/html/nextcloud

#Allow pw auth
sed -i 's/#   PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
rm /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart sshd

  # Wait for 10 seconds to allow the SSH daemon to start
  sleep 15



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
sudo apt install -y corosync pacemaker pcs

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

sudo echo "192.168.56.51     ubsx2" >> /etc/hosts

ip link set enp0s8 down
ip addr flush dev enp0s8
ip addr add 192.168.56.50/24 dev enp0s8
ip link set enp0s8 up

sudo chmod 755 /etc/corosync/corosync.conf 

#some stuff to do here on ubsx2 - complete after - actually not?

sudo systemctl start corosync
sudo systemctl enable corosync
sudo systemctl start pacemaker
sudo systemctl enable pacemaker

sudo systemctl status corosync
sudo systemctl status pacemaker

sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=ignore
sudo pcs property set migration-threshold=1
#https://clusterlabs.org/quickstart-ubuntu.html

sudo pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=192.168.56.100 cidr_netmask=24 nic=enp0s8 op monitor interval=30s

	  

sudo crm_mon -1


sudo systemctl restart corosync
sudo systemctl restart pacemaker







