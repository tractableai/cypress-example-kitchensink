# use Cypress provided image with all dependencies included
FROM cypress/included:12.3.0

ENV DEBUG=cypress:*

# Install ffmpeg and xvfb
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg=7:4.3.5-0+deb11u1 \
    xvfb=2:1.20.11-1+deb11u4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch workdir
WORKDIR /qa-automation

# Copy our test application
COPY package.json yarn.lock serve.json ./
COPY app ./app

# Copy Cypress tests
COPY cypress.config.js cypress ./
COPY cypress ./cypress

# Set the Cypress Cache folder
# During CI in Harness LOCAL_CACHE_DIR should be `.cache`
# The `.cache` should be populated by one of the S3 retrieve cache steps
ARG LOCAL_CACHE_DIR=/root/.cache/Cache
# ENV CYPRESS_CACHE_FOLDER=/qa-automation/.cache
ENV CYPRESS_CACHE_FOLDER=/root/.cache/Cypress/
# Copy local cypress cache over into docker image
# COPY $LOCAL_CACHE_DIR .cache

# Install all dependencies
RUN env && yarn install --frozen-lockfile && yarn cache clean --all

# Verify installation worked
RUN npx cypress cache path && \
    npx cypress cache list && \
    npx cypress version

# EXPOSE 8181
# EXPOSE 8080
# Used for Xvfb screen. Reference https://docs.cypress.io/guides/continuous-integration/introduction#Xvfb

RUN printf "#!/bin/bash \
\nXvfb -screen 0 1024x768x24 :8099 & \
\nwhile true \
\ndo \
\n  echo \"Running Xvfb\" \
\n  ps -ef|grep Xvfb \
\n  sleep 5 \
\ndone \
" > entrypoint.sh && cat /qa-automation/entrypoint.sh

#ENV DISPLAY=:8099
EXPOSE 8099
# ENV TERM=xterm

# Switch workdir
WORKDIR /qa-automation
ENTRYPOINT ["npx"]