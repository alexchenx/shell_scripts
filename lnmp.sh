#!/bin/bash

# Description: 
#	  Auto install Mysql, php, wordpress

# Environment: 
#	  Only tested on CentOS7.4 64bit mini

# History:
# 2019/5/9		Alex Chen		First release.

# Software version details:
#	  mysql-5.6.44.tar.gz
#	  php-7.3.5.tar.gz
#	  nginx-1.16.0.tar.gz
#	  wordpress-5.2.tar.gz

systemctl stop firewalld
yum install -y ntpdate wget cmake gcc gcc-c++ ncurses-devel bison autoconf libxml2 libxml2-devel

echo "sync date:"
ntpdate ntp.aliyun.com

mkdir -p /data/{software,app,resources}

mysql_download_url="https://qooco-software.oss-cn-beijing.aliyuncs.com/Mysql/mysql-5.6.44.tar.gz"
php_download_url="https://qooco-software.oss-cn-beijing.aliyuncs.com/php-7.3.5.tar.gz"
nginx_download_url="https://qooco-software.oss-cn-beijing.aliyuncs.com/nginx-1.16.0.tar.gz"
wordpress_download_url="https://qooco-software.oss-cn-beijing.aliyuncs.com/wordpress-5.2.tar.gz"

echo "Installing Mysql5.6..."
cd /data/software/
useradd mysql
mkdir -p /data/app/mysql/data && chown -R mysql.mysql /data/app/mysql/data/
wget ${mysql_download_url}
tar -zxvf mysql-5.6.44.tar.gz 
cd mysql-5.6.44
cmake -DCMAKE_INSTALL_PREFIX=/data/app/mysql/
make && make install
cp /data/app/mysql/support-files/my-default.cnf  /etc/my.cnf
/data/app/mysql/scripts/mysql_install_db --user=mysql --basedir=/data/app/mysql/ --datadir=/data/app/mysql/data/
cp /data/app/mysql/support-files/mysql.server /etc/init.d/mysqld
/etc/init.d/mysqld start
echo '/etc/init.d/mysqld start' >> /etc/rc.local
chmod +x /etc/rc.local
echo 'export PATH=$PATH:/data/app/mysql/bin/' >> /etc/profile
source /etc/profile

echo "Set root password."
mysql -u root -e "create database wordpress;"
mysql -u root -e "set password for root@'localhost' = password('123456');"



echo "Install PHP7.3.5 ...."
cd /data/software/
useradd www;
wget ${php_download_url}
tar -zxvf php-7.3.5.tar.gz
cd php-7.3.5
./configure --prefix=/data/app/php --enable-fpm
make && make install
cp /data/app/php/etc/php-fpm.conf.default /data/app/php/etc/php-fpm.conf 
cp /data/app/php/etc/php-fpm.d/www.conf.default /data/app/php/etc/php-fpm.d/www.conf
cp /data/software/php-7.3.5/php.ini-production /data/app/php/lib/php.ini


echo "install mysqli module"
cd /data/software/php-7.3.5/ext/mysqli
sed -i 's/ext\/mysqlnd\/mysql_float_to_double.h/\/data\/software\/php-7.3.5\/ext\/mysqlnd\/mysql_float_to_double.h/' mysqli_api.c
/data/app/php/bin/phpize
./configure --with-php-config=/data/app/php/bin/php-config --with-mysqli=/data/app/mysql/bin/mysql_config
make && make install
echo 'extension=mysqli.so' >> /data/app/php/lib/php.ini


echo "install zlib module"
cd /data/software/php-7.3.5/ext/zlib
cp config0.m4 config.m4
/data/app/php/bin/phpize
./configure --with-php-config=/data/app/php/bin/php-config --with-zlib
make && make install
echo 'extension=zlib.so' >> /data/app/php/lib/php.ini

/data/app/php/sbin/php-fpm
echo '/data/app/php/sbin/php-fpm' >> /etc/rc.local

echo "Installing Nignx"
yum -y install gcc pcre-devel openssl openssl-devel make
cd /data/software/
wget ${nginx_download_url}
tar -zxvf nginx-1.16.0.tar.gz
cd nginx-1.16.0
./configure --prefix=/data/app/nginx --with-http_ssl_module --with-http_stub_status_module --with-http_v2_module
make && make install

cat > /data/app/nginx/conf/nginx.conf << EOF
#
user www;
worker_processes  auto;
error_log  logs/error.log;
 
events {
    use epoll;
    worker_connections  65535;
}
 
worker_rlimit_nofile 102400;
 
http {
    include       mime.types;
    default_type  application/octet-stream;
 
    log_format  main escape=json '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent \$request_body "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" '
                      '"\$upstream_addr" \$request_time \$upstream_response_time';
 
    access_log  logs/access.log  main;
 
    include vhost/*.conf;
}
EOF


mkdir /data/app/nginx/conf/vhost
cat > /data/app/nginx/conf/vhost/proxy.conf <<EOF
#
server_tokens off;
sendfile on;
tcp_nopush on;
tcp_nodelay on;
keepalive_timeout 65;
server_names_hash_bucket_size 128;
client_header_buffer_size 2k;
client_body_buffer_size 256k;
client_body_in_single_buffer on;
large_client_header_buffers 4 4k;
client_max_body_size 100m;
 
fastcgi_connect_timeout 300;
fastcgi_send_timeout 300;
fastcgi_read_timeout 300;
fastcgi_buffer_size 128k;
fastcgi_buffers 2 256k;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;
fastcgi_intercept_errors on;
 
open_file_cache max=204800 inactive=20s;
open_file_cache_min_uses 1;
open_file_cache_valid 30s;
 
gzip on;
gzip_min_length 1k;
gzip_buffers     4 16k;
gzip_http_version 1.1;
gzip_comp_level 2;
gzip_types text/plain text/xml text/css application/javascript application/json application/font-woff application/x-shockwave-flash image/png image/jpeg image/gif;
gzip_vary on;
gzip_disable "MSIE [1-6]\.";
 
proxy_connect_timeout   300;
proxy_send_timeout      300;
proxy_read_timeout      300;
proxy_buffer_size      256k;
proxy_buffers          4 256k;
proxy_busy_buffers_size 256k;
proxy_temp_file_write_size 256k;
proxy_buffering off;
proxy_cache off;
proxy_set_header Host \$host;
proxy_set_header  X-Real-IP  \$remote_addr;
proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
EOF

echo "Start nginx service."
/data/app/nginx/sbin/nginx

echo '/data/app/nginx/sbin/nginx' >> /etc/rc.local



echo "install wordpress"
cd /data/software/
wget ${wordpress_download_url}
tar -zxvf wordpress-5.2.tar.gz
mv wordpress /data/resources/
cd /data/resources/wordpress/
cp wp-config-sample.php wp-config.php
sed -i 's/database_name_here/wordpress/' wp-config.php
sed -i 's/username_here/root/' wp-config.php
sed -i 's/password_here/123456/' wp-config.php
chown -R www.www /data/resources/wordpress/


cat > /data/app/nginx/conf/vhost/wordpress.conf <<EOF
server {
        listen 80;
        server_name localhost;

        root /data/resources/wordpress;


        location / {
                try_files \$uri \$uri/ /index.php;
                index index.php;
        }

        location ~ \.php$ {
                fastcgi_pass   127.0.0.1:9000;
                fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
                include        fastcgi_params;
        }
}
EOF
/data/app/nginx/sbin/nginx -s reload


echo "Your server information below:"
server_ip=`ifconfig|grep inet|head -1|awk '{print $2}'`
echo "---------- Mysql ----------"
echo "Mysql home: /data/app/mysql"
echo "host: localhost"
echo "username: root"
echo "password: 123456"
echo "dbname: wordpress"
echo ""

echo "---------- PHP ----------"
echo "PHP Home: /data/app/php"
echo ""

echo "---------- Nginx ----------"
echo "Nginx home: /data/app/nginx"
echo ""

echo "---------- Website ----------"
echo "Url: http://${server_ip}/"
echo ""
