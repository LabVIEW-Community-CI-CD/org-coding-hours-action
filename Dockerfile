# Build stage: compile the .NET 7 console application
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy and restore project dependencies
COPY OrgCodingHoursCLI/OrgCodingHoursCLI.csproj .
RUN dotnet restore OrgCodingHoursCLI.csproj

# Copy source files and publish as a self-contained Linux-x64 binary
COPY OrgCodingHoursCLI/. .
RUN dotnet publish OrgCodingHoursCLI.csproj -c Release -o /app/out \
    -r linux-x64 --self-contained true --no-restore

# Final runtime image
FROM debian:bookworm-slim AS final
# Install git, curl, certificates, and tar for extracting archives
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl tar && rm -rf /var/lib/apt/lists/*

# Copy the published .NET application
COPY --from=build /app/out /app

# Copy entrypoint script that fetches git-hours at runtime
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory to the GitHub workspace
WORKDIR /github/workspace

# Run the entrypoint script when the container starts
ENTRYPOINT ["/entrypoint.sh"]
