FROM enclaive/debug-gramine:latest

ARG NGX_VERSION=1.18.0

RUN apt-get update &&\
    apt-get install -y build-essential libssl-dev zlib1g zlib1g-dev wget \
    re2c libmariadb-dev libxml2-dev bison libsqlite3-dev libcurl4-openssl-dev libargon2-dev \
    libpng-dev libreadline-dev libz-dev  zlib1g-dev libzip-dev libbz2-dev libc-client2007e-dev \
    libkrb5-dev

WORKDIR /src

#build pcre
RUN wget https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.zip &&\
    unzip pcre-8.45.zip &&\
    cd pcre-8.45  &&\
    ./configure --disable-shared --enable-static --prefix /usr &&\
    make -j &&\
    make install


# build nginx
RUN wget https://nginx.org/download/nginx-${NGX_VERSION}.tar.gz &&\
    tar xvf nginx-${NGX_VERSION}.tar.gz &&\
    rm nginx-${NGX_VERSION}.tar.gz &&\
    cd nginx-* ;\
        ./configure \
        --prefix=/app \
        --with-pcre=/src/pcre-8.45 \
        --with-http_ssl_module \
        --with-select_module &&\
    make -j &&\
    make install &&\
    rm -rf nginx-*


# build php
RUN wget https://www.php.net/distributions/php-8.1.4.tar.gz &&\
    tar xvf php-8.1.4.tar.gz

# patch out sockopts
ADD php_sapi_fpm_config.m4 /src/php-8.1.4/sapi/fpm/config.m4

RUN cp /usr/lib/libc-client.* /usr/lib/x86_64-linux-gnu/ &&\
    cd php-8.1.4 &&\
    ./buildconf --force &&\
    ./configure \
        --enable-dba \
        --enable-fpm \
        --enable-gd \
        --enable-mysqlnd \
        --with-password-argon2 \
        --with-bz2 \
        --with-curl \
        --with-imap \
        --with-imap-ssl \
        --with-kerberos \
        --with-mysqli=mysqlnd \
        --with-openssl \
        --with-pdo-mysql=mysqlnd \
        --with-pdo-sqlite \
        --with-readline \
        --with-zip \
        --with-zlib &&\
    make -j &&\
    ldd ./sapi/fpm/php-fpm &&\
    make install

ADD . /app
WORKDIR /app

# creates self-signed server certificate if /ssl is empty
RUN cd /app/conf && ./cert-gen.sh

# create nginx manifest
RUN cd /app &&\
    gramine-sgx-gen-private-key &&\
    gramine-manifest \
        -Dlog_level=error \
        -Darch_libdir=/lib/x86_64-linux-gnu \
        nginx.manifest.template nginx.manifest &&\
    gramine-sgx-sign \
        --manifest nginx.manifest \
        --output nginx.manifest.sgx

COPY fpm.conf /usr/local/etc/php-fpm.conf

# create php manifest
RUN cd /app &&\
    gramine-manifest \
        -Dlog_level=error \
        -Darch_libdir=/lib/x86_64-linux-gnu \
        php.manifest.template php.manifest &&\
    gramine-sgx-sign \
        --manifest php.manifest \
        --output php.manifest.sgx



ENTRYPOINT ["/app/entrypoint.sh"]

# ports
EXPOSE 80 443
