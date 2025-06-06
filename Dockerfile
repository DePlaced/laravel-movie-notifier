FROM node:20-alpine AS nodebuild
WORKDIR /app

# Only copy package files first for cache optimization
COPY package.json package-lock.json* yarn.lock* ./
RUN npm install

# Now copy the rest of your app (for Vite to see resources)
COPY . .

RUN npm run build

# ---- Main PHP/Nginx image ----
FROM php:8.4-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    bash \
    curl \
    supervisor \
    libpng \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    zip \
    unzip \
    git \
    icu-dev \
    oniguruma-dev

# Install PHP extensions
RUN docker-php-ext-configure gd \
    --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo pdo_mysql gd intl mbstring opcache

# 1. Copy composer files and install dependencies first
COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Set working directory
WORKDIR /var/www/html

# Copy your Laravel app files
COPY . .

# Set permissions for Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache

# Nginx config
COPY ./docker/nginx.conf /etc/nginx/nginx.conf

# Supervisor config for PHP and Nginx
COPY ./docker/supervisord.conf /etc/supervisord.conf

EXPOSE 80

# Start supervisor to run both php-fpm and nginx
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
