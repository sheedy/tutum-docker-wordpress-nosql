#!/bin/bash

chown www-data:www-data /app -R
chmod -R 777 /app/wp-content

DB_HOST=${DB_PORT_3306_TCP_ADDR:-${DB_HOST}}
DB_HOST=${DB_1_PORT_3306_TCP_ADDR:-${DB_HOST}}
DB_PORT=${DB_PORT_3306_TCP_PORT:-${DB_PORT}}
DB_PORT=${DB_1_PORT_3306_TCP_PORT:-${DB_PORT}}

if [ "$DB_PASS" = "**ChangeMe**" ] && [ -n "$DB_1_ENV_MYSQL_PASS" ]; then
    DB_PASS="$DB_1_ENV_MYSQL_PASS"
fi

echo "=> Using the following MySQL/MariaDB configuration:"
echo "========================================================================"
echo "      Database Host Address:  $DB_HOST"
echo "      Database Port number:   $DB_PORT"
echo "      Database Name:          $DB_NAME"
echo "      Database Username:      $DB_USER"
echo "========================================================================"

# Volume script from https://github.com/romaninsh/docker-wordpress/blob/master/volume-init.sh

test -d /data/ || { echo "No data volume found. Skipping."; }

# Grab wp-content if it's found (plugins etc)
if [ ! -d /data/wp-content/ ]; then
  echo "Moving wp-content to blank volume.."
  cp -aR /app/wp-content/ /data/
fi

echo "Linking wp-content.."
rm -rf /app/wp-content
ln -sf /data/wp-content /app/wp-content

# Grab custom config file if it's there
if [ -f /data/wp-config-production.php ]; then
  echo "Using wp-config-production.php.."
  rm -f /app/wp-config.php
  ln -sf /data/wp-config-production.php /app/wp-config.php
fi

# Grab .htaccess if it's there
if [ -f /data/.htaccess ]; then
  echo "Using .htaccess.."
  ln -sf /data/.htaccess /app/.htaccess
fi

# Execute init.sh if it's found
if [ -x /data/init.sh ]; then
  echo "Executing custom init.sh.."
  /data/init.sh
fi

# End volume script

if [ -f /.mysql_db_created ]; then
        exec /run.sh
        exit 1
fi

for ((i=0;i<10;i++))
do
    DB_CONNECTABLE=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e 'status' >/dev/null 2>&1; echo "$?")
    if [[ DB_CONNECTABLE -eq 0 ]]; then
        break
    fi
    sleep 5
done

if [[ $DB_CONNECTABLE -eq 0 ]]; then
    DB_EXISTS=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e "SHOW DATABASES LIKE '"$DB_NAME"';" 2>&1 |grep "$DB_NAME" > /dev/null ; echo "$?")

    if [[ DB_EXISTS -eq 1 ]]; then
        echo "=> Creating database $DB_NAME"
        RET=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e "CREATE DATABASE $DB_NAME")
        if [[ RET -ne 0 ]]; then
            echo "Cannot create database for wordpress"
            exit RET
        fi
        if [ -f /initial_db.sql ]; then
            echo "=> Loading initial database data to $DB_NAME"
            RET=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT $DB_NAME < /initial_db.sql)
            if [[ RET -ne 0 ]]; then
                echo "Cannot load initial database data for wordpress"
                exit RET
            fi
        fi
        echo "=> Done!"    
    else
        echo "=> Skipped creation of database $DB_NAME – it already exists."
    fi
else
    echo "Cannot connect to Mysql"
    exit $DB_CONNECTABLE
fi

touch /.mysql_db_created

source /etc/apache2/envvars
exec apache2 -D FOREGROUND
