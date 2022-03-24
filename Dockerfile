FROM enclaive/gramine-sdk:latest

ARG NGX_VERSION=1.18.0

RUN apt-get update 
RUN apt-get install -y build-essential apache2-utils libssl-dev zlib1g zlib1g-dev 
RUN apt-get install -y php-fpm libpcre3 libpcre3-dev


WORKDIR /run/php
#add www.conf
COPY ./conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf

# download source
WORKDIR /entrypoint

ADD https://nginx.org/download/nginx-${NGX_VERSION}.tar.gz ./
RUN tar -xzf nginx-${NGX_VERSION}.tar.gz 
RUN rm nginx-${NGX_VERSION}.tar.gz

# add entrypoint
COPY ./entrypoint .

# add nginx.conf
COPY ./conf/nginx.conf /entrypoint/conf/nginx.conf

# add /html
WORKDIR /entrypoint/html

COPY ./html .

# build nginx
WORKDIR /entrypoint/nginx-${NGX_VERSION}

RUN ./configure \
    --prefix=/entrypoint \
    --with-http_ssl_module 

RUN make 
RUN make install     

# generate server.cert
WORKDIR /entrypoint/conf

COPY ./ssl .
RUN chmod +x cert-gen.sh 
RUN ./cert-gen.sh               # creates self-signed server certificate if /ssl is empty

# create manifest
WORKDIR /manifest


COPY nginx-php.manifest.template .
COPY ./index.php /var/www/html/index.php
# uncomment to run /ping and /status tests with fast-cgi client 
#RUN sed -i "s|listen = /run/php/php7.4-fpm.sock|listen = 9000|g" /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i "s|;ping.path = /ping|ping.path = /ping|g" /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i "s|;ping.response = pong|ping.response = pong|g" /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i "s|;pm.status_path = /status|pm.status_path = /status|g" /etc/php/7.4/fpm/pool.d/www.conf 

RUN mkdir -p /var/log/php7.4-fpm &&  \
    ./manifest.sh nginx-php 
#    sed -i 's|user = www-data|user = root|g' /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i 's|group = www-data|group = root|g' /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i 's|listen.owner = www-data|listen.owner = root|g' /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i 's|listen.group = www-data|listen.group = root|g' /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i 's|listen = /run/php/php7.4-fpm.sock|listen = 9000|g' /etc/php/7.4/fpm/pool.d/www.conf && \
#    sed -i 's|;access.log = log/$pool.access.log|access.log = /var/log/php7.4-fpm/access.log|g' /etc/php/7.4/fpm/pool.d/www.conf && \   
#    ./manifest.sh nginx-php 


# clean up
RUN rm -rf /entrypoint/nginx-${NGX_VERSION} /entrypoint/conf/ca.* /entrypoint/conf/cert-gen.sh 

# start enclaived nginx
ENTRYPOINT [ "/entrypoint/enclaive.sh" ]
CMD [ "nginx-php /entrypoint/entrypoint.sh" ]


# ports
EXPOSE 80 443
