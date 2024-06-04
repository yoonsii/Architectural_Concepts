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

#setting IP info for ubsx2
echo "setting IP info for ubsx2"

sudo ip link set enp0s8 down
sudo ip addr flush dev enp0s8
sudo ip addr add 192.168.56.51/24 dev enp0s8
sudo ip link set enp0s8 up
ip addr


#Install Nextcloud to failover

cd /var/www/html/nextcloud/

# first lets try with removing the admin user - already in database
# sudo -u www-data php occ  maintenance:install \
# --database='mysql' --database-name='nextcloud' \
# --database-user='replica' --database-pass='password' \
# --admin-user='admin2' --admin-pass='password'


cd /var/www/html/nextcloud/config/

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/0 => '"'localhost'"',/a\
    1 => '"'192.168.56.51'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php


        chown -R www-data: /var/www/html/nextcloud/
        chmod -R 755 /var/www/html/nextcloud

		