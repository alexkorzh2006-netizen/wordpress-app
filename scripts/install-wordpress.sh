#!/usr/bin/env bash
set -Eeuo pipefail

# Based on:
# https://developer.wordpress.org/advanced-administration/before-install/howto-install/
# https://make.wordpress.org/cli/handbook/guides/installing/
# https://developer.wordpress.org/cli/commands/core/install/

exec > >(tee -a /var/log/wordpress-install.log) 2>&1
trap 'echo "WordPress installation failed at line $LINENO"' ERR

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root with sudo."
  exit 1
fi

wordpress_url="${1:-${WORDPRESS_URL:-}}"

bootstrap_directory="/run/wordpress-bootstrap"
wordpress_title="${WORDPRESS_SITE_TITLE:-}"
wordpress_admin_user="${WORDPRESS_ADMIN_USER:-}"
wordpress_admin_email="${WORDPRESS_ADMIN_EMAIL:-}"
wordpress_admin_password="${WORDPRESS_ADMIN_PASSWORD:-}"
database_password="${WORDPRESS_DB_PASSWORD:-}"

if [ -r "$bootstrap_directory/site-title" ]; then
  wordpress_title="$(<"$bootstrap_directory/site-title")"
fi

if [ -r "$bootstrap_directory/admin-user" ]; then
  wordpress_admin_user="$(<"$bootstrap_directory/admin-user")"
fi

if [ -r "$bootstrap_directory/admin-email" ]; then
  wordpress_admin_email="$(<"$bootstrap_directory/admin-email")"
fi

if [ -r "$bootstrap_directory/admin-password" ]; then
  wordpress_admin_password="$(<"$bootstrap_directory/admin-password")"
fi

if [ -r "$bootstrap_directory/database-password" ]; then
  database_password="$(<"$bootstrap_directory/database-password")"
fi

wordpress_title="${wordpress_title:-Test WordPress}"
wordpress_admin_user="${wordpress_admin_user:-wpadmin}"
wordpress_admin_email="${wordpress_admin_email:-admin@example.com}"

wordpress_root="/var/www/html"
database_name="wordpress"
database_user="wordpress"
credentials_file="/root/wordpress-credentials.txt"
completion_file="/var/lib/wordpress-installation-complete"
wp_cli_directory=""

cleanup() {
  if [ -n "$wp_cli_directory" ] && [ -d "$wp_cli_directory" ]; then
    rm -r -- "$wp_cli_directory"
  fi
}

trap cleanup EXIT

if [ -f "$completion_file" ]; then
  echo "WordPress is already installed."
  echo "Credentials: $credentials_file"
  exit 0
fi

umask 027
export DEBIAN_FRONTEND=noninteractive

apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 upgrade -y
apt-get -o DPkg::Lock::Timeout=120 install -y \
  apache2 \
  ca-certificates \
  curl \
  gnupg \
  libapache2-mod-php \
  mariadb-server \
  openssl \
  php \
  php-curl \
  php-gd \
  php-intl \
  php-mbstring \
  php-mysql \
  php-xml \
  php-zip

if [ -z "$wordpress_url" ]; then
  if ! metadata_token="$(curl --fail --silent --show-error \
    --connect-timeout 5 \
    --request PUT \
    --header 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
    http://169.254.169.254/latest/api/token)"; then
    echo "EC2 metadata is unavailable. Pass the URL explicitly."
    exit 1
  fi

  private_ip="$(curl --fail --silent --show-error \
    --connect-timeout 5 \
    --header "X-aws-ec2-metadata-token: $metadata_token" \
    http://169.254.169.254/latest/meta-data/local-ipv4)"

  if [ -z "$private_ip" ]; then
    echo "EC2 private IP is unavailable. Pass the URL explicitly."
    exit 1
  fi

  wordpress_url="http://$private_ip"
fi

if [[ ! "$wordpress_url" =~ ^https?://[^/]+/?$ ]]; then
  echo "Could not determine the WordPress URL."
  echo "Run: sudo ./install-wordpress.sh http://PRIVATE_IP"
  exit 1
fi

if [ -z "$wordpress_admin_password" ]; then
  wordpress_admin_password="$(openssl rand -hex 16)"
fi

if [ -z "$database_password" ]; then
  database_password="$(openssl rand -hex 24)"
fi

cat > /etc/mysql/mariadb.conf.d/60-wordpress.cnf <<'MARIADB_CONFIG'
[mysqld]
bind-address = 127.0.0.1
MARIADB_CONFIG

systemctl enable mariadb apache2
systemctl restart mariadb

mariadb --protocol=socket <<SQL
CREATE DATABASE IF NOT EXISTS wordpress
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wordpress'@'localhost' IDENTIFIED BY '$database_password';
ALTER USER 'wordpress'@'localhost' IDENTIFIED BY '$database_password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
SQL

wp_cli_directory="$(mktemp -d)"
export GNUPGHOME="$wp_cli_directory/gnupg"
install -d -m 0700 "$GNUPGHOME"

curl --fail --silent --show-error --location \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  --output "$wp_cli_directory/wp-cli.phar"
curl --fail --silent --show-error --location \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.asc \
  --output "$wp_cli_directory/wp-cli.phar.asc"
curl --fail --silent --show-error --location \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/wp-cli.pgp \
  --output "$wp_cli_directory/wp-cli.pgp"

gpg --batch --import "$wp_cli_directory/wp-cli.pgp"
gpg --batch --verify \
  "$wp_cli_directory/wp-cli.phar.asc" \
  "$wp_cli_directory/wp-cli.phar"

install -m 0755 "$wp_cli_directory/wp-cli.phar" /usr/local/bin/wp
cleanup
wp_cli_directory=""
unset GNUPGHOME

install -d -o www-data -g www-data -m 0755 "$wordpress_root"
rm -f "$wordpress_root/index.html"

php -d memory_limit=512M /usr/local/bin/wp core download \
  --allow-root \
  --force \
  --locale=en_US \
  --path="$wordpress_root"

php -d memory_limit=512M /usr/local/bin/wp config create \
  --allow-root \
  --path="$wordpress_root" \
  --dbname="$database_name" \
  --dbuser="$database_user" \
  --dbpass="$database_password" \
  --dbhost=localhost \
  --dbcharset=utf8mb4 \
  --force

php -d memory_limit=512M /usr/local/bin/wp config shuffle-salts \
  --allow-root \
  --path="$wordpress_root"

php -d memory_limit=512M /usr/local/bin/wp core install \
  --allow-root \
  --path="$wordpress_root" \
  --url="$wordpress_url" \
  --title="$wordpress_title" \
  --admin_user="$wordpress_admin_user" \
  --admin_password="$wordpress_admin_password" \
  --admin_email="$wordpress_admin_email"

cat > /etc/apache2/sites-available/wordpress.conf <<'APACHE_CONFIG'
<VirtualHost *:80>
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog ${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
APACHE_CONFIG

a2enmod rewrite
a2dissite 000-default.conf || true
a2ensite wordpress.conf

chown -R www-data:www-data "$wordpress_root"
find "$wordpress_root" -type d -exec chmod 0755 {} +
find "$wordpress_root" -type f -exec chmod 0644 {} +
chmod 0640 "$wordpress_root/wp-config.php"

apache2ctl configtest
systemctl restart apache2

install -m 0600 /dev/null "$credentials_file"
{
  printf 'WordPress URL: %s\n' "$wordpress_url"
  printf 'WordPress admin user: %s\n' "$wordpress_admin_user"
  printf 'WordPress admin password: %s\n' "$wordpress_admin_password"
  printf 'MariaDB database: %s\n' "$database_name"
  printf 'MariaDB user: %s\n' "$database_user"
  printf 'MariaDB password: %s\n' "$database_password"
} > "$credentials_file"

touch "$completion_file"

echo "WordPress installation completed at $wordpress_url"
echo "Credentials were saved to $credentials_file"
