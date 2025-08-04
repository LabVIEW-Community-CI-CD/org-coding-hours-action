# CI and Release Pipeline

This repository's automated pipeline builds and validates the Org Coding Hours CLI before packaging it for distribution and embedding it into the Docker action.

## Building and Testing the CLI

- The CLI is built with [`dotnet publish`](https://learn.microsoft.com/dotnet/core/tools/dotnet-publish):
  ```bash
  dotnet publish OrgCodingHoursCLI/OrgCodingHoursCLI.csproj -c Release
  ```
- Unit tests run separately with [`dotnet test`](https://learn.microsoft.com/dotnet/core/tools/dotnet-test):
  ```bash
  dotnet test OrgCodingHoursCLI.Tests/OrgCodingHoursCLI.Tests.csproj
  ```
- Pester scripts in `tests/` exercise the compiled binary and confirm that a Docker image built from the repo contains the CLI.

## Publishing the CLI as a Package

`dotnet publish` produces a self-contained executable (`OrgCodingHoursCLI`) that can be uploaded as a release asset or consumed directly by workflows without Docker. This packaged CLI is what gets embedded into the container image.

## Docker Image from the Packaged CLI

The `docker_build` job downloads the pre-published CLI and the `Dockerfile` builds a runtime image that also compiles `git-hours` from source:

```Dockerfile
FROM golang:1.24 AS git-hours
ARG GIT_HOURS_VERSION=v0.1.2
RUN git clone --depth 1 --branch $GIT_HOURS_VERSION https://github.com/trinhminhtriet/git-hours /src \
    && cd /src \
    && go build -o /git-hours

FROM mcr.microsoft.com/dotnet/runtime:8.0
ARG CLI_VERSION
ARG GIT_HOURS_VERSION
ENV ORG_CLI_VERSION=$CLI_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl libkrb5-dev unzip \
    && rm -rf /var/lib/apt/lists/*
COPY --from=git-hours /git-hours /usr/local/bin/git-hours
COPY package/OrgCodingHoursCLI*.nupkg /tmp/OrgCodingHoursCLI.nupkg
RUN mkdir /app \
    && unzip /tmp/OrgCodingHoursCLI.nupkg -d /tmp/cli \
    && cp /tmp/cli/lib/net8.0/* /app/ \
    && rm -rf /tmp/cli /tmp/OrgCodingHoursCLI.nupkg
```

Because the CLI is built ahead of time, the Docker build no longer needs to contact external NuGet feeds.

## Deterministic Releases

- Release workflows create signed Git tags and use `gh release create --generate-notes`, producing notes directly from commit history.
- Base images (`golang:1.24`, `mcr.microsoft.com/dotnet/runtime:8.0`) and the bundled `git-hours` version are pinned, so image contents do not change unexpectedly.
- Every release references a specific tagged commit, allowing users to pin the action to an exact version for repeatable results.
