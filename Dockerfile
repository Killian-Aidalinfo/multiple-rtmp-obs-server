# build stage
FROM alpine:latest AS builder

# Arguments pour la version de NGINX et le module RTMP
ARG NGINX_VERSION=1.26.1

# Installer les dépendances nécessaires à la compilation
RUN apk add --no-cache --virtual .build-deps \
    alpine-sdk \
    linux-headers \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    git

# Télécharger les sources de NGINX et du module RTMP
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xvzf nginx-${NGINX_VERSION}.tar.gz && \
    git clone https://github.com/arut/nginx-rtmp-module.git

# Se déplacer dans le répertoire des sources de NGINX
WORKDIR /nginx-${NGINX_VERSION}

# Configurer et compiler NGINX avec le module RTMP
RUN ./configure --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/run/nginx/nginx.lock \
    --user=nginx \
    --group=nginx \
    --build=Alpine \
    --with-select_module \
    --with-poll_module \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-stream_ssl_preread_module \
    --with-compat \
    --with-pcre-jit \
    --with-openssl-opt=no-nextprotoneg \
    --add-module=../nginx-rtmp-module \
    --with-debug && \
    make && \
    make install

# Supprimer les dépendances de construction et les fichiers temporaires
RUN apk del .build-deps && \
    rm -rf /nginx-${NGINX_VERSION} /nginx-${NGINX_VERSION}.tar.gz /nginx-rtmp-module

# production stage
FROM nginx:1.26.1-alpine as production-stage

# Installer les dépendances nécessaires pour exécuter NGINX
RUN apk add --no-cache \
    pcre \
    zlib \
    libxslt \
    gd \
    geoip

# Copier le binaire NGINX compilé depuis l'image de construction
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules

# Créer les répertoires nécessaires pour les journaux et les caches avec les bonnes permissions
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/run/nginx

# Exposer le port RTMP
EXPOSE 1935

CMD ["nginx", "-g", "daemon off;"]
