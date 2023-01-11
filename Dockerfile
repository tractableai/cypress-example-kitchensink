# use Cypress provided image with all dependencies included
FROM cypress/included:10.11.0

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
ARG LOCAL_CACHE_DIR=/root/.cache
ENV CYPRESS_CACHE_FOLDER=/qa-automation/.cache/Cypress
# Copy local cypress cache over into docker image
COPY $LOCAL_CACHE_DIR .cache
RUN mkdir -p $LOCAL_CACHE_DIR && \
    ls -al $LOCAL_CACHE_DIR && \
    mkdir -p $CYPRESS_CACHE_FOLDER && \
    ls -al $CYPRESS_CACHE_FOLDER

# Install all dependencies
RUN env && yarn install --frozen-lockfile
# Alternatively if npm project:
#   RUN npm ci

# Verify installation worked
RUN npx cypress cache path && \
    npx cypress cache list && \
    npx cypress version && \
    npx cypress verify

# EXPOSE 8181
# EXPOSE 8080
# Used for Xvfb screen. Reference https://docs.cypress.io/guides/continuous-integration/introduction#Xvfb
EXPOSE 8099
ENV TERM=xterm
ENV DISPLAY=:8099
RUN echo "#!/bin/bash\n" \
         "Xvfb -screen 0 1024x768x24 :8099 &\n" \
         "while true\n" \
         "do\n" \
         "  echo \"Running Xvfb\"\n" \
         "  ps -ef|grep Xvfb\n" \
         "  sleep 5\n" \
         "done\n" > entrypoint.sh

RUN cat /qa-automation/entrypoint.sh

ENTRYPOINT ["sh", "/qa-automation/entrypoint.sh"]