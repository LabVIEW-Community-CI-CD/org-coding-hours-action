FROM golang:1.24@sha256:9aba206b3974f93f7056304c991c9cc1f843c939159d9305571ab9766c9ccdf6 AS git-hours-builder
ARG GIT_HOURS_VERSION=v0.1.2
RUN git clone --depth 1 --branch $GIT_HOURS_VERSION https://github.com/trinhminhtriet/git-hours /src \
    && cd /src \
    && go build -o /git-hours

FROM mcr.microsoft.com/dotnet/runtime:8.0@sha256:55277015b7d570ac6cc9aa2ba78fe16eb9f6b214f251d1d49857faea26ce18a2
ARG CLI_VERSION
ARG GIT_HOURS_VERSION
LABEL org.opencontainers.image.version=$CLI_VERSION
ENV ORG_CLI_VERSION=$CLI_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    libkrb5-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*
COPY --from=git-hours-builder /git-hours /usr/local/bin/git-hours
RUN chmod +x /usr/local/bin/git-hours
COPY package/OrgCodingHoursCLI*.nupkg /tmp/OrgCodingHoursCLI.nupkg
RUN mkdir /app \
    && unzip /tmp/OrgCodingHoursCLI.nupkg -d /tmp/cli \
    && cp /tmp/cli/lib/net8.0/* /app/ \
    && rm -rf /tmp/cli /tmp/OrgCodingHoursCLI.nupkg
WORKDIR /github/workspace
ENTRYPOINT ["dotnet", "/app/OrgCodingHoursCLI.dll"]
