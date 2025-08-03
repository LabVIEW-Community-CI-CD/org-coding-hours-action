FROM mcr.microsoft.com/dotnet/runtime:8.0

ARG CLI_VERSION
LABEL org.opencontainers.image.version=$CLI_VERSION
# Expose the CLI version for downstream steps
ENV ORG_CLI_VERSION=$CLI_VERSION

# Install git, curl, certificates, node, and unzip
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl libkrb5-dev nodejs npm unzip \
    && rm -rf /var/lib/apt/lists/*

# Install git-hours CLI globally
RUN npm install -g git-hours@1.5.0

# Copy NuGet package for the CLI produced in CI
COPY package/OrgCodingHoursCLI*.nupkg /tmp/OrgCodingHoursCLI.nupkg

# Extract CLI assembly
RUN mkdir /app \
    && unzip /tmp/OrgCodingHoursCLI.nupkg -d /tmp/cli \
    && cp /tmp/cli/lib/net8.0/* /app/ \
    && rm -rf /tmp/cli /tmp/OrgCodingHoursCLI.nupkg

# Set working directory to the GitHub workspace
WORKDIR /github/workspace

# Run the OrgCodingHoursCLI when the container starts
ENTRYPOINT ["dotnet", "/app/OrgCodingHoursCLI.dll"]
