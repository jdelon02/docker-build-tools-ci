# Use an official Python runtime as a parent image
FROM drupaldocker/php:7.2-cli

# Set the working directory to /build-tools-ci
WORKDIR /build-tools-ci

# Copy the current directory contents into the container at /build-tools-ci
ADD . /build-tools-ci

# Collect the components we need for this image
RUN apt-get update
RUN apt-get install -y ruby jq
RUN gem install circle-cli
RUN composer -n global require -n "hirak/prestissimo:^0.3"

RUN mkdir -p /usr/local/share/terminus
RUN /usr/bin/env COMPOSER_BIN_DIR=/usr/local/bin composer -n --working-dir=/usr/local/share/terminus require pantheon-systems/terminus:"^1.9"
RUN mkdir -p /usr/local/share/drush
RUN /usr/bin/env composer -n --working-dir=/usr/local/share/drush require drush/drush "^8"
RUN ln -fs /usr/local/share/drush/vendor/drush/drush/drush /usr/local/bin/drush
RUN chmod +x /usr/local/bin/drush

# Add a collection of useful Terminus plugins
env TERMINUS_PLUGINS_DIR /usr/local/share/terminus-plugins
RUN mkdir -p /usr/local/share/terminus-plugins
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-build-tools-plugin:^2.0.0-beta1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-secrets-plugin:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-rsync-plugin:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-quicksilver-plugin:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-composer-plugin:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-drupal-console-plugin:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-mass-update:^1
RUN composer -n create-project -d /usr/local/share/terminus-plugins pantheon-systems/terminus-site-clone-plugin:^1
RUN composer -n create-project --no-dev -d /usr/local/share/terminus-plugins pantheon-systems/terminus-aliases-plugin:^1

# Add phpcs for use in checking code style
RUN mkdir ~/phpcs && cd ~/phpcs && COMPOSER_BIN_DIR=/usr/local/bin composer require squizlabs/php_codesniffer:^2.7

# Add phpunit for unit testing
RUN mkdir ~/phpunit && cd ~/phpunit && COMPOSER_BIN_DIR=/usr/local/bin composer require phpunit/phpunit:^6

# Add bats for functional testing
RUN git clone https://github.com/sstephenson/bats.git; bats/install.sh /usr/local

# Add behat for more functional testing
RUN mkdir ~/behat && \
    cd ~/behat && \
    COMPOSER_BIN_DIR=/usr/local/bin \
    composer require \
        "behat/behat:^3.1" \
        "behat/mink:*" \
        "behat/mink-extension:^2.2" \
        "behat/mink-goutte-driver:^1.2" \
        "drupal/drupal-extension:*"

###########################
# Install headless Chrome
# Borrowed from https://github.com/Zenika/alpine-chrome
###########################

# Installs latest Chromium package.
RUN echo @edge http://nl.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
    && echo @edge http://nl.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories \
    && apk add --no-cache \
    chromium@edge \
    harfbuzz@edge \
    nss@edge \
    && rm -rf /var/cache/*

# Add Chrome as a user
RUN mkdir -p /usr/src/app \
    && adduser -D chrome \
    && chown -R chrome:chrome /usr/src/app
# Run Chrome as non-privileged
USER chrome
WORKDIR /usr/src/app

ENV CHROME_BIN=/usr/bin/chromium-browser \
    CHROME_PATH=/usr/lib/chromium/