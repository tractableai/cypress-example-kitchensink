# use Cypress provided image with all dependencies included
FROM cypress/included:12.3.0

ENV DEBUG=cypress:*

# Be aware this docker container will run as root
USER root
# Change the workdir from `/` to `/qa-automation`
WORKDIR /qa-automation

# Install ffmpeg and xvfb
RUN whoami && apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg=7:4.3.5-0+deb11u1 \
    xvfb=2:1.20.11-1+deb11u4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy our test application
COPY package.json yarn.lock serve.json ./
COPY app ./app

# Copy Cypress tests
COPY cypress.config.js cypress ./
COPY cypress ./cypress

# Set the Cypress Cache folder
# During CI in Harness LOCAL_CACHE_DIR should be `/harness/.cache/Cypress`
# The `/harness/.cache/Cypress` should be populated by one of the S3 retrieve cache steps
# RUN mkdir -p ~/.cache/
ARG LOCAL_CACHE_DIR=/harness/.cache/Cypress
# Copy over cypress cache into docker image
COPY $LOCAL_CACHE_DIR /root/.cache/Cypress/
RUN ls -al /root/.cache/Cypress/
# Force cypress CLI to use our cache
ENV CYPRESS_CACHE_FOLDER=/root/.cache/Cypress/

# Install all project dependencies
# Use our Nexus artifactory for Tractable npm packages
RUN env && \
    yarn config set registry https://nexus.tractable.ai/repository/npm-tractable/ && \
    yarn install --frozen-lockfile
    # && yarn cache clean --all

# Install cypress if necessary (otherwise will take from cache)
RUN npx cypress install && \
    npx cypress cache path && \
    npx cypress cache list && \
    npx cypress version && \
    npx cypress verify

# Startscript to run a virtual screen
RUN printf "#!/bin/bash \
\nXvfb -screen 0 1024x768x24 :8099 & \
\nwhile true \
\ndo \
\n  echo \"Running Xvfb\" \
\n  ps -ef|grep Xvfb \
\n  sleep 5 \
\ndone \
" > entrypoint.sh && cat entrypoint.sh

# Used for Xvfb screen. Reference https://docs.cypress.io/guides/continuous-integration/introduction#Xvfb
EXPOSE 8099

# start the container with npx
ENTRYPOINT ["npx"]

# Local build workflow example
# Install the cypress package into your node_modules
#   yarn install
# Generate a local cypress cache with cypress binaries
#   CYPRESS_CACHE_FOLDER=.cache/Cypress yarn npx cypress install
# Build a local docker image while using our cache with the binaries
#   docker build --build-arg LOCAL_CACHE_DIR=.cache/Cypress -t cypress:local .
# Run the cypress tests while using our cypress director for parallel runs
#   docker run --rm --net=host -e CYPRESS_API_URL="https://director-sorry-cypress.infra-eu.k8s.tractable.io" cypress:local cy2 run --record --key XXX --parallel --ci-build-id "local-$(date +'%H:%M:%S')"