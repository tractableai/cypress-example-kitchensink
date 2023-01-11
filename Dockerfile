# This Docker file is for building this project on Codeship Pro
# https://documentation.codeship.com/pro/languages-frameworks/nodejs/

# use Cypress provided image with all dependencies included
FROM cypress/included:12.3.0

WORKDIR /qa-automation

RUN node --version && \
    npm --version

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg=7:4.3.5-0+deb11u1 \
    xvfb=2:1.20.11-1+deb11u4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# copy our test application
COPY package.json package-lock.json serve.json ./
COPY app ./app

# copy Cypress tests
COPY cypress.config.js cypress ./
COPY cypress ./cypress

# avoid many lines of progress bars during install
# https://github.com/cypress-io/cypress/issues/1243

# install NPM dependencies and Cypress binary
ENV CI=true
ENV CYPRESS_CACHE_FOLDER=/harness/cache
RUN npm ci

RUN npx cypress cache path && \
    npx cypress cache list && \
    npx cypress version && \
    npx cypress verify

# EXPOSE 8181
# EXPOSE 8080
# Used for Xvfb screen. Reference https://docs.cypress.io/guides/continuous-integration/introduction#Xvfb
EXPOSE 8099

ENV TERM=xterm
