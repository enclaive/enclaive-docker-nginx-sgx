FROM ubuntu:impish AS builder

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
    --with-compat \
    --add-dynamic-module=./module-sgx \
    --add-dynamic-module=./echo-nginx-module
RUN make -j
RUN make -j modules
RUN make install

# final stage

FROM enclaive/gramine-os:latest

COPY ./packages.txt ./packages.txt

RUN apt-get update \
    && xargs -a packages.txt -r apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /entrypoint/ /entrypoint/
COPY ./conf /entrypoint/conf
COPY ./html /entrypoint/html

WORKDIR /entrypoint/conf
COPY ./ssl .
# creates self-signed server certificate if /ssl is empty
RUN ./cert-gen.sh

WORKDIR /manifest
COPY nginx.manifest.template .
RUN /manifest/manifest.sh nginx

# clean up
RUN rm -rf /entrypoint/conf/ca.* /entrypoint/conf/cert-gen.sh

ENTRYPOINT [ "/entrypoint/enclaive.sh" ]
CMD [ "nginx" ]
EXPOSE 80 443
