FROM ubuntu:jammy AS builder

ARG NGX_VERSION=1.22.0

COPY ./packages-build.txt ./packages.txt

RUN apt-get update \
    && xargs -a packages.txt -r apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://nginx.org/download/nginx-${NGX_VERSION}.tar.gz -qO - | tar xzf -

WORKDIR nginx-${NGX_VERSION}

COPY ./module-sgx/ ./module-sgx/

RUN git clone https://github.com/openresty/echo-nginx-module.git &&\
    ./configure \
    --prefix=/entrypoint \
    --without-http_rewrite_module \
    --with-http_ssl_module \
    --with-http_geoip_module \
    --with-compat \
    --add-dynamic-module=./module-sgx \
    --add-dynamic-module=./echo-nginx-module
RUN make -j
RUN make -j modules
RUN make install

# final stage

FROM enclaive/gramine-os:latest

RUN apt-get update \
    && apt-get install -y geoip-database libgeoip-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /entrypoint/ /entrypoint/

COPY ./conf/ /entrypoint/conf/
COPY ./ssl/  /entrypoint/conf/ssl/
COPY ./html/ /entrypoint/html/
COPY ./nginx.manifest.template /manifest/

# creates self-signed server certificate if not present
RUN cd /entrypoint/conf/ssl/ && ./cert-gen.sh && cd - \
    && /manifest/manifest.sh nginx \
    && rm -rf /entrypoint/conf/ca.* /entrypoint/conf/cert-gen.sh

ENTRYPOINT [ "/entrypoint/enclaive.sh" ]
CMD [ "nginx" ]
EXPOSE 80 443
