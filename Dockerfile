FROM node:14-slim
ARG CLI_VERSION
LABEL org.opencontainers.image.version=$CLI_VERSION
# Expose the CLI version for downstream steps
ENV ORG_CLI_VERSION=$CLI_VERSION
# Install git, curl, certificates, and nodegit dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl libkrb5-dev && rm -rf /var/lib/apt/lists/*
# Install git-hours CLI globally
RUN npm install -g git-hours@1.5.0
# Copy the prebuilt .NET application
COPY cli/ /app
# Set working directory to the GitHub workspace
WORKDIR /github/workspace
# Run the OrgCodingHoursCLI when the container starts
ENTRYPOINT ["/app/OrgCodingHoursCLI"]
