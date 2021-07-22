FROM ubuntu:16.04

MAINTAINER Luca Garbin (service+github@lucagarbin.it)

RUN apt-get update -y
RUN apt-get install -y software-properties-common python-software-properties language-pack-en-base
RUN LC_ALL=en_US.UTF-8 add-apt-repository -y ppa:ondrej/php
RUN apt-get update -y
RUN apt-get install -y \
     unzip \
     curl \
     git \
     php7.2-cli \
     php7.2 \
     php7.2-curl \
     php7.2-gd \
     php7.2-json \
     php7.2-ldap \
     php7.2-mbstring \
     php7.2-mysql \
     php7.2-pgsql \
     php7.2-sqlite3 \
     php7.2-xml \
     php7.2-xsl \
     php7.2-zip \
     php7.2-soap \
     ssh \
     php-pear \
     php7.2-dev \
     libaio1 \
     php-odbc \
     apt-get install

RUN pecl -v

# Laravel PDF generator 1-devpendecies
RUN apt-get install -y libxrender1 libfontconfig libxext6

# install pre requisites
RUN apt-get update
RUN apt-get install -y apt-transport-https
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql mssql-tools
RUN apt-get install -y unixodbc-utf16
RUN apt-get install -y unixodbc-dev-utf16

# install driver sqlsrv
RUN pecl channel-update pecl.php.net
RUN pecl install sqlsrv-5.6.0
RUN pecl install pdo_sqlsrv-5.6.0

RUN echo extension=pdo_sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-pdo_sqlsrv.ini
RUN echo extension=sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/20-sqlsrv.ini

# install ODBC Driver
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql mssql-tools unixodbc-dev
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
    pecl download oci8 &&\
    tar -xzvf oci8*.tgz &&\
    cd oci8-2.2.0 &&\
    phpize &&\
    ./configure --with-oci8=instantclient,/opt/oracle/instantclient_12_2/ &&\
    make install &&\
    echo 'instantclient,/opt/oracle/instantclient_12_2' | pecl install oci8 &&\
    echo extension=oci8.so >> /etc/php/7.2/apache2/php.ini &&\
    echo extension=oci8.so >> /etc/php/7.2/cli/php.ini &&\
    echo extension=imagick >> /etc/php/7.2/apache2/php.ini

# install locales
RUN apt-get install -y locales && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# install composer
RUN curl -sS https://getcomposer.org/installer | php
RUN chmod a+x composer.phar
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