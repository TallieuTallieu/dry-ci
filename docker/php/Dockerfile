# CI image for dry packages: PHP 8.4 CLI with the tools and extensions
# bin/check needs, so a pipeline step skips compiling them on every run.
# Published as ghcr.io/tallieutallieu/dry-ci-php:8.4 by .github/workflows/image.yml.
FROM php:8.4-cli

LABEL org.opencontainers.image.source="https://github.com/TallieuTallieu/dry-ci" \
      org.opencontainers.image.description="PHP 8.4 CLI with Composer, gd, exif, imagick and zip for dry-ci"

# Composer's cache in ~/.composer/cache, where Bitbucket's predefined
# "composer" cache looks.
ENV COMPOSER_HOME=/root/.composer

COPY --from=ghcr.io/mlocati/php-extension-installer:2.12.0 /usr/bin/install-php-extensions /usr/local/bin/

# git and unzip for Composer, and ssh for git@bitbucket.org dependencies such as
# dry3 in a project; install-php-extensions stays in the image, so a package that
# needs one more extension can add it in its own step.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git openssh-client unzip \
    && rm -rf /var/lib/apt/lists/* \
    && install-php-extensions @composer gd exif imagick zip
