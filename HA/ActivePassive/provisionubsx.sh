
      # update app repository
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
CREATE USER 'yoonsi'@'localhost' IDENTIFIED BY '********';
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

cd /var/www/html/nextcloud/

sudo -u www-data php occ  maintenance:install \
--database='mysql' --database-name='nextcloud' \
--database-user='yoonsi' --database-pass='Deathscythe1' \
--admin-user='admin' --admin-pass='password'

cd /var/www/html/nextcloud/config/

# Create a temporary file
tmp_file=$(mktemp)

# Insert the new line after the 'localhost' line
sed '/0 => '"'localhost'"',/a\
    1 => '"'192.168.56.50'"',' config.php > "$tmp_file"

# Replace the original file with the modified version
mv "$tmp_file" config.php


	chown -R www-data: /var/www/html/nextcloud/
	chmod -R 755 /var/www/html/nextcloud

#Allow pw auth
sed -i 's/#   PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
rm /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart sshd

  # Wait for 10 seconds to allow the SSH daemon to start
  sleep 15


ip link set enp0s8 down

ip addr flush dev enp0s8

ip addr add 192.168.56.50/24 dev enp0s8

ip link set enp0s8 up
