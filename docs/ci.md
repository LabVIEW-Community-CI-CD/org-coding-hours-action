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

The multi-stage `Dockerfile` first builds the CLI in a .NET SDK image and then copies the published output into a minimal runtime image:

```Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
...
RUN dotnet publish OrgCodingHoursCLI.csproj -c Release -o /app/out -r linux-x64 --self-contained true --no-restore
...
FROM node:14-slim AS final
...
COPY --from=build /app/out /app
```

Using the published artifacts ensures that the Docker image contains the same tested CLI package.

## Deterministic Releases

- Release workflows create signed Git tags and use `gh release create --generate-notes`, producing notes directly from commit history.
- Base images (`mcr.microsoft.com/dotnet/sdk:8.0`, `node:14-slim`) and the bundled `git-hours` version are pinned, so image contents do not change unexpectedly.
- Every release references a specific tagged commit, allowing users to pin the action to an exact version for repeatable results.
