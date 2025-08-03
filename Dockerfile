# Build stage: compile the .NET 7 console application
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy and restore project dependencies
COPY OrgCodingHoursCLI/OrgCodingHoursCLI.csproj .
RUN dotnet restore OrgCodingHoursCLI.csproj

# Copy source files and publish as a self-contained Linux-x64 binary
COPY OrgCodingHoursCLI/. .
RUN dotnet publish OrgCodingHoursCLI.csproj -c Release -o /app/out \
    -r linux-x64 --self-contained true --no-restore

# Final runtime image
FROM node:14-slim AS final
# Install git, curl, certificates, and nodegit dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl libkrb5-dev && rm -rf /var/lib/apt/lists/*

# Install git-hours CLI globally
RUN npm install -g git-hours@1.5.0

# Copy the published .NET application
COPY --from=build /app/out /app

# Set working directory to the GitHub workspace
WORKDIR /github/workspace

# Run the OrgCodingHoursCLI when the container starts
ENTRYPOINT ["/app/OrgCodingHoursCLI"]
