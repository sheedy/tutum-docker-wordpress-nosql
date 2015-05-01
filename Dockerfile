FROM ubuntu:trusty
MAINTAINER Michael Sheedy git@michaelsheedy.com

ENV WORDPRESS_VER 4.1.1
WORKDIR /

# Install packages
RUN apt-get update && \
 DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
 DEBIAN_FRONTEND=noninteractive apt-get -y install supervisor pwgen && \
 apt-get -y install git apache2 libapache2-mod-php5 php5-mysql php5-pgsql php5-gd php-pear php-apc curl && \
 curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin && \
 mv /usr/local/bin/composer.phar /usr/local/bin/composer

RUN apt-get -yq install mysql-client && \
    # Configure /app folder
    mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html && \
    rm -rf /app && \
    curl -0L http://wordpress.org/wordpress-4.1.1.tar.gz | tar zxv && \
    mv /wordpress /app && \
    rm -rf /var/lib/apt/lists/*
    
# Override default apache conf
ADD apache.conf /etc/apache2/sites-enabled/000-default.conf

# Enable apache rewrite module
RUN a2enmod rewrite

# Add image configuration and scripts
ADD start.sh /start.sh
ADD run.sh /run.sh
ADD wp-config.php /app/wp-config.php
RUN chmod +x /*.sh
RUN chmod 755 /*.sh

ADD supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf

# Expose environment variables
ENV DB_HOST **LinkMe**
ENV DB_PORT **LinkMe**
ENV DB_NAME wordpress
ENV DB_USER admin
ENV DB_PASS **ChangeMe**

# EXPOSE 80
# VOLUME ["/app/wp-content"]
CMD ["/run.sh"]

