FROM mcr.microsoft.com/playwright:v1.34.0-jammy

RUN npm install -g netlify-cli node-jq serve \
    && netlify --version \
    && node-jq --version \
    && serve --version