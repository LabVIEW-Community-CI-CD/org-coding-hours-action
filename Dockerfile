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

# Stage to acquire git-hours binary (Linux x64)
FROM debian:bullseye-slim AS git-hours
WORKDIR /tmp
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates tar && rm -rf /var/lib/apt/lists/*
# Download and extract the git-hours binary (v0.0.6)
RUN curl -sSL https://github.com/lazypic/git-hours/releases/download/v0.0.6/git-hours_linux_x86-64.tgz -o git-hours.tgz \
    && tar -xzf git-hours.tgz && rm git-hours.tgz

# Final runtime image
FROM debian:bullseye-slim AS final
# Install git and certificates for HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the published .NET application
COPY --from=build /app/out /app
# Copy the git-hours CLI into the image
COPY --from=git-hours /tmp/git-hours /usr/local/bin/git-hours

# Ensure the git-hours binary is executable
RUN chmod +x /usr/local/bin/git-hours

# Add /usr/local/bin to PATH (in case it's not already)
ENV PATH="/usr/local/bin:${PATH}"

# Set working directory to the GitHub workspace
WORKDIR /github/workspace

# Run the OrgCodingHoursCLI when the container starts
ENTRYPOINT ["/app/OrgCodingHoursCLI"]