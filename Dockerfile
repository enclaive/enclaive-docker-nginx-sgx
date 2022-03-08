FROM enclaive/gramine-os:latest

ARG NGX_VERSION=1.18.0

RUN apt-get update 
RUN apt-get install -y build-essential apache2-utils libssl-dev zlib1g zlib1g-dev

# download source
WORKDIR /entrypoint

ADD http://nginx.org/download/nginx-${NGX_VERSION}.tar.gz ./
RUN tar -xzf nginx-${NGX_VERSION}.tar.gz 
RUN rm nginx-${NGX_VERSION}.tar.gz

# add nginx.conf
COPY ./conf /entrypoint/conf

# add /html
WORKDIR /entrypoint/html

COPY ./html .

# build nginx
WORKDIR /entrypoint/nginx-${NGX_VERSION}

RUN ./configure \
    --prefix=/entrypoint \
    --without-http_rewrite_module \
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

COPY nginx.manifest.template .
RUN /manifest/manifest.sh nginx

# clean up
RUN rm -rf /entrypoint/nginx-${NGX_VERSION} /entrypoint/conf/ca.* /entrypoint/conf/cert-gen.sh 

# start enclaived nginx
ENTRYPOINT [ "/entrypoint/enclaive.sh" ]
CMD [ "nginx" ]

# ports
EXPOSE 80 443
