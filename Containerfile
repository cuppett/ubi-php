FROM registry.access.redhat.com/ubi8/php-74

USER 0

RUN set -ex; \
    dnf -y module reset nginx; \
    dnf -y module install nginx:1.20; \
    dnf -y install php-devel php-pecl-zip; \
    dnf -y clean all; \
    rm -rf /var/cache/dnf;

# Install redis for PHP session handling and common caching
# https://github.com/phpredis/phpredis/blob/develop/INSTALL.markdown
RUN set -ex; \
    cd /tmp; \
    : =====igbinary ===== ;\
    wget --no-check-certificate https://pecl.php.net/get/igbinary-3.2.6.tgz; \
    tar -zxf igbinary-*.tgz; \
    rm igbinary-*.tgz; \
    cd igbinary-*; \
    phpize; \
    ./configure; \
    make -j4 && make install; \
    echo -e "; Enable igbinary extension module\nextension = igbinary.so" > /etc/php.d/40-igbinary.ini; \
    cd ..; \
    : ===== msgpack ===== ;\
    wget --no-check-certificate https://pecl.php.net/get/msgpack-2.1.2.tgz; \
    tar -zxf msgpack-*.tgz; \
    rm msgpack-*.tgz; \
    cd msgpack-*; \
    phpize; \
    ./configure; \
    make -j4 && make install; \
    echo -e "; Enable msgpack extension module\nextension = msgpack.so" > /etc/php.d/40-msgpack.ini; \
    cd ..; \
    : ===== redis ===== ;\
    wget --no-check-certificate https://pecl.php.net/get/redis-5.3.5.tgz; \
    tar -zxf redis-*.tgz; \
    rm redis-*.tgz; \
    cd redis-*; \
    phpize; \
    ./configure --enable-redis-igbinary --enable-redis-msgpack --enable-redis-lzf; \
    make -j4 && make install; \
    echo -e "; Enable redis extension module\nextension = redis.so" > /etc/php.d/50-redis.ini; \
    cd ..; \
    : ===== cleanup ===== ;\
    rm -fR redis* igbinary* msgpack*

USER 1001
