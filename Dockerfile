FROM ubuntu:18.04

MAINTAINER Luca Garbin (service+github@lucagarbin.it)

RUN apt-get update -y
RUN apt-get install -y software-properties-common language-pack-en-base
RUN LC_ALL=en_US.UTF-8 add-apt-repository -y ppa:ondrej/php
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y \
     unzip \
     curl \
     git \
     vim \
     ssh \
     libaio1 \
     php7.3-cli \
     php7.3 \
     php7.3-curl \
     php7.3-gd \
     php7.3-json \
     php7.3-ldap \
     php7.3-mbstring \
     php7.3-mysql \
     php7.3-pgsql \
     php7.3-sqlite3 \
     php7.3-xml \
     php7.3-xsl \
     php7.3-zip \
     php7.3-soap \
     php7.3-imagick \
     php-pear \
     php7.3-dev \
     php-odbc \
     php7.3-pdo-odbc

RUN pecl -v

RUN apt-get -y install libmcrypt-dev

# Laravel PDF generator 1-devpendecies
RUN apt-get install -y libxrender1 libfontconfig libxext6

# Install driver sql server
RUN apt-get update
RUN apt-get install -y apt-transport-https
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y libcurl3 msodbcsql mssql-tools
RUN apt-get install -y unixodbc
RUN apt-get install -y unixodbc-dev

# install driver sqlsrv
RUN pecl channel-update pecl.php.net
RUN pecl install sqlsrv-5.6.0
RUN pecl install pdo_sqlsrv-5.6.0

RUN echo extension=pdo_sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-pdo_sqlsrv.ini
RUN echo extension=sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/20-sqlsrv.ini

# install ODBC Driver
# RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql mssql-tools unixodbc-dev
# RUN ACCEPT_EULA=Y apt-get install -y mssql-tools
# RUN ACCEPT_EULA=Y apt-get install -y unixodbc-dev
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN exec bash

# Install Oracle Client
COPY ./oracle-client /tmp
RUN cd /opt &&\
    mkdir oracle &&\
    mv /tmp/instantclient* /opt/oracle/ &&\
    cd /opt/oracle/ &&\
    unzip instantclient-basic-linux.x64-12.2.0.1.0.zip &&\
    unzip instantclient-sqlplus-linux.x64-12.2.0.1.0.zip &&\
    unzip instantclient-sdk-linux.x64-12.2.0.1.0.zip &&\
    cd /opt/oracle/instantclient_12_2/ &&\
    ln -s libclntsh.so.12.1 libclntsh.so &&\
    echo "/opt/oracle/instantclient_12_2/" >> /etc/ld.so.conf.d/oracle.conf &&\
    ldconfig &&\
    echo 'export ORACLE_HOME=/opt/oracle' >> ~/.bashrc &&\
    echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/oracle/instantclient_12_2' >> ~/.bashrc &&\
    echo 'PATH=$PATH:/opt/oracle/instantclient_12_2' >> ~/.bashrc &&\
    echo "alias sqlplus='/usr/bin/rlwrap -m /opt/oracle/instantclient_12_2/sqlplus'" >> ~/.bashrc &&\
    cd /opt/oracle &&\
    pecl download oci8-2.2.0 &&\
    tar -xzvf oci8*.tgz &&\
    cd oci8-2.2.0 &&\
    phpize &&\
    ./configure --with-oci8=instantclient,/opt/oracle/instantclient_12_2/ &&\
    make install &&\
    echo 'instantclient,/opt/oracle/instantclient_12_2' | pecl install oci8-2.2.0 &&\
    echo extension=oci8.so >> /etc/php/7.3/apache2/php.ini &&\
    echo extension=oci8.so >> /etc/php/7.3/cli/php.ini

RUN echo extension=imagick.so >> /etc/php/7.3/apache2/php.ini

# Install ext mcrypt
RUN apt-get -y install gcc make autoconf libc-dev pkg-config
RUN apt-get -y install libmcrypt-dev
RUN pecl install mcrypt-1.0.2 -y
RUN echo extension=mcrypt.so >> /etc/php/7.3/apache2/php.ini &&\
    echo extension=mcrypt.so >> /etc/php/7.3/cli/php.ini

# install locales
RUN apt-get install -y locales && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer

# Enable Apache mod rewrite
RUN /usr/sbin/a2enmod rewrite

# Edit apache2.conf to change apache site settings.
ADD apache2.conf /etc/apache2/

# Edit 000-default.conf to change apache site settings.
ADD 000-default.conf /etc/apache2/sites-available/

EXPOSE 80

WORKDIR /var/www/

CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]