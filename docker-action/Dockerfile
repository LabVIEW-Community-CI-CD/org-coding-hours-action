FROM golang:1.24-bullseye AS builder

# Install certificate authorities before fetching git-hours.
# If building behind a corporate proxy with a custom certificate,
# copy it into /usr/local/share/ca-certificates/ before the
# `update-ca-certificates` step.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# COPY corporate.crt /usr/local/share/ca-certificates/corporate.crt
RUN update-ca-certificates

# Build the git-hours binary
ARG GIT_HOURS_VERSION=v0.1.2
RUN git clone --depth 1 --branch ${GIT_HOURS_VERSION} https://github.com/trinhminhtriet/git-hours.git /src/git-hours \
    && sed -i 's/go 1.24.1/go 1.24/' /src/git-hours/go.mod \
    && cd /src/git-hours && go install .

FROM python:3.11-slim

# Install system packages required for cloning repositories
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Add git-hours to PATH
COPY --from=builder /go/bin/git-hours /usr/local/bin/git-hours
ENV PATH="/usr/local/bin:${PATH}"

# Copy all helper scripts into the image
COPY scripts/ /action/

ENTRYPOINT ["python3", "/action/org_coding_hours.py"]

