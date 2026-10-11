ARG WORDPRESS_VERSION=7.1.2

FROM wordpress:cli-php8.3 AS wordpress-builder

ARG WORDPRESS_VERSION
USER root

RUN php -d memory_limit=512M /usr/local/bin/wp core download \
      --allow-root \
      --force \
      --locale=en_US \
      --path=/build \
      --version="${WORDPRESS_VERSION}"

FROM wordpress:${WORDPRESS_VERSION}-php8.3-apache AS runtime

COPY --from=wordpress-builder --chown=www-data:www-data /build/ /usr/src/wordpress/
