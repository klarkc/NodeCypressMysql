FROM cypress/base:12.6.0

USER root

RUN node --version
RUN echo "force new chrome here"

# install Chromebrowser
RUN \
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list
RUN apt-get update
# disabled dbus install - could not get it to install
# but tested an example project, and Chrome seems to run fine
# RUN apt-get install -y dbus-x11
RUN apt-get install -y google-chrome-stable
RUN rm -rf /var/lib/apt/lists/*

# "fake" dbus address to prevent errors
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Add zip utility - it comes in very handy
RUN apt-get update && apt-get install -y zip

# Install mysql
# Reference https://github.com/docker-library/mysql/blob/master/8.0/Dockerfile
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql
RUN apt-get update && apt-get install -y --no-install-recommends gnupg dirmngr && rm -rf /var/lib/apt/lists/*
RUN mkdir /docker-entrypoint-initdb.d
RUN apt-get update && apt-get install -y --no-install-recommends \
    # for MYSQL_RANDOM_ROOT_PASSWORD
    pwgen \
    # for mysql_ssl_rsa_setup
    openssl \
    # FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
    # File::Basename
    # File::Copy
    # Sys::Hostname
    # Data::Dumper
    perl \
    && rm -rf /var/lib/apt/lists/*
ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.16-2debian9
RUN echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list
# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
RUN apt-get update
RUN apt-cache madison mysql-community-server-core
# also, we set debconf keys to make APT a little quieter
RUN { \
    echo mysql-community-server mysql-community-server/data-dir select ''; \
    echo mysql-community-server mysql-community-server/root-pass password ''; \
    echo mysql-community-server mysql-community-server/re-root-pass password ''; \
    echo mysql-community-server mysql-community-server/remove-test-db select false; \
    } | debconf-set-selections \
    && apt-get install -y --allow-unauthenticated mysql-community-client="${MYSQL_VERSION}" mysql-community-server-core="${MYSQL_VERSION}" && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    # ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
    && chmod 777 /var/run/mysqld
VOLUME /var/lib/mysql
# Config files
COPY config/ /etc/mysql/

EXPOSE 3306 33060
CMD ["mysqld"]

# versions of local tools
RUN echo  " node version:    $(node -v) \n" \
    "npm version:     $(npm -v) \n" \
    "yarn version:    $(yarn -v) \n" \
    "debian version:  $(cat /etc/debian_version) \n" \
    "Chrome version:  $(google-chrome --version) \n" \
    "git version:     $(git --version) \n" \
    "mysql version:     $(mysql --version) \n"
