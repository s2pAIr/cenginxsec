FROM nginx:1.15.7
LABEL maintainer="Suvicha Buakhom [Samos] <suvicha@central.tech>"
ARG NGINX_SRC_VERSION=1.15.7

RUN echo ${NGINX_SRC_VERSION}

# Pre required before install modsecurity 
RUN apt-get update && apt-get install -y \
  apt-utils \
  autoconf \
  automake \
  build-essential \
  git \
  libcurl4-openssl-dev \
  libgeoip-dev \
  liblmdb-dev \ 
  libpcre++-dev \
  libtool \
  libxml2-dev \
  libyajl-dev \
  pkgconf \
  wget \
  zlib1g-dev

# Download and compile modsecurity 3.0 source code
RUN cd /opt && \
	git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity && \
	cd ModSecurity && \
	git submodule init && \
	git submodule update && \
	./build.sh && \
	./configure && \
	make && \
	make install

# Download the NGINX connector for ModSecurity and compile it as a dynamic module
RUN cd /opt && \
	git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git && \
	wget http://nginx.org/download/nginx-${NGINX_SRC_VERSION}.tar.gz && \
	tar zxvf nginx-${NGINX_SRC_VERSION}.tar.gz && \
  cd nginx-${NGINX_SRC_VERSION} && \
	./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
	make modules && \
	cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules

# Load module
RUN cd /etc/nginx && \
  mkdir modules-enabled.d && \
  echo "load_module modules/ngx_http_modsecurity_module.so;" > /etc/nginx/modules-enabled.d/loadmodsec.conf && \
  echo "include /etc/nginx/modules-enabled.d/*.conf;" > /etc/nginx/nginx.conf.tmp && \
  cat nginx.conf >> /etc/nginx/nginx.conf.tmp && \
  mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

# configure, enable, and test modsecurity
RUN mkdir /etc/nginx/modsec && \
  cd /etc/nginx/modsec && \
  wget https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended && \
  mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf && \
  cp /opt/ModSecurity/unicode.mapping /etc/nginx/modsec && \
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf

# Replace file /etc/nginx/conf.d/default.conf
# This file add enable modsecurity command and call modsecurity rule file in server{}
RUN cd /etc/nginx/conf.d && \
  wget https://github.com/s2pAIr/cenginxsec/blob/master/default.conf 

# Enabling the OWASP CRS
RUN cd /opt && \
  wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0.2.tar.gz && \
  tar -xzvf v3.0.2.tar.gz && \
  mv owasp-modsecurity-crs-3.0.2 /usr/local && \
  cd /usr/local/owasp-modsecurity-crs-3.0.2 && \
  cp crs-setup.conf.example crs-setup.conf && \
  cp /usr/local/owasp-modsecurity-crs-3.0.2/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /usr/local/owasp-modsecurity-crs-3.0.2/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf && \
  cp /usr/local/owasp-modsecurity-crs-3.0.2/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /usr/local/owasp-modsecurity-crs-3.0.2/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

# Start basic config /etc/nginx/modsec/main.conf 
# This file include /etc/nginx/modsec/modsecurity.conf
RUN cd /etc/nginx/modsec && \
  wget https://github.com/s2pAIr/cenginxsec/blob/master/main.conf

# https://www.nginx.com/blog/compiling-and-installing-modsecurity-for-open-source-nginx/