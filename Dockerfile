# use Cypress provided image with all dependencies included
FROM cypress/included:12.3.0

ENV DEBUG=cypress:*
ENV CI=true
# Don't use the root folder to cache cypress binaries
# ENV CYPRESS_CACHE_FOLDER=/root/.cache/Cypress/
ENV CYPRESS_CACHE_FOLDER=/home/node/.cache/Cypress/

# Used for Xvfb screen. Reference https://docs.cypress.io/guides/continuous-integration/introduction#Xvfb
EXPOSE 8099
# Leave DISPLAY empty for local runs; For Harness runs must be the X11 Display Server port
# ENV DISPLAY=:8099

# Install ffmpeg and xvfb
RUN whoami && apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg=7:4.3.5-0+deb11u1 \
    xvfb=2:1.20.11-1+deb11u4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy node files as preparation for installing dependencies
WORKDIR /
COPY package.json yarn.lock ./

# Install all project dependencies
# Use our Nexus artifactory for Tractable npm packages
RUN env && \
    yarn add cypress@12.3.0 --dev && \
    yarn install --frozen-lockfile && \
    yarn cache clean && \
    chown -R node /home/node

# Change the workdir from `/` to `/qa-automation`
WORKDIR /qa-automation

# Setting the user to NODE instead of running the container as ROOT
# In Harness you will have to run the container as user 1000 (default)
USER node

# Copy Cypress tests
COPY cypress.config.js ./
COPY cypress ./cypress

# Only needed for this example project to start a webserver under port 8080 for the tests
# For other projects copy whatever you need to build
COPY scripts ./scripts
COPY serve.json package.json ./
COPY app ./app
EXPOSE 8080

# Install cypress if necessary (otherwise will take from cache)
RUN npx cypress install && \
    npx cypress cache path && \
    npx cypress cache list && \
    npx cypress version && \
    npx cypress verify

# start the container with npx
ENTRYPOINT ["npx"]

# Local build workflow example
# Build a local docker image while using our cache with the binaries
#   docker build -t cypress:local .
# Run the cypress tests while using our cypress director for parallel runs
#   docker run --rm --net=host -e CYPRESS_API_URL="https://director-sorry-cypress.infra-eu.k8s.tractable.io" cypress:local cy2 run --record --key XXX --parallel --ci-build-id "local-$(date +'%H:%M:%S')"
# If you just wanna see what's inside your new image:
#   docker run --rm -it --entrypoint=/bin/bash cypress:local
