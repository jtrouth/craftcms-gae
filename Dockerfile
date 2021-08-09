# composer dependencies
FROM composer:1 as vendor
COPY composer.json composer.json
COPY composer.lock composer.lock
RUN composer install --ignore-platform-reqs --no-interaction --prefer-dist

FROM php:apache


# Configure PHP for Cloud Run.
# Precompile PHP code with opcache.
USER root 
RUN apt-get update && apt-get -qq install libpq-dev libmagickwand-dev libzip-dev
RUN pecl install imagick && \
    docker-php-ext-install -j "$(nproc)" opcache pdo_pgsql gd zip \
    && docker-php-ext-enable imagick
RUN a2enmod rewrite

# Update the Apache config
ENV APACHE_DOCUMENT_ROOT /var/www/html/web

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
RUN sed -ri -e 's/80/${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf
RUN sed -ri -e 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf


# Copy in custom code from the host machine.
WORKDIR /var/www/html
COPY --chown=www-data:www-data . ./
COPY --from=vendor --chown=www-data:www-data /app/vendor /var/www/html/vendor
RUN mkdir /var/www/html/storage && chown www-data:www-data /var/www/html/storage && chmod u+w /var/www/html/storage

USER www-data