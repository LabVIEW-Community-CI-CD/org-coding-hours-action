FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    python3 \
    wget \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install Go 1.24
RUN wget -q https://go.dev/dl/go1.24.linux-amd64.tar.gz -O /tmp/go.tgz \ 
  && tar -C /usr/local -xzf /tmp/go.tgz \ 
  && rm /tmp/go.tgz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install git-hours
ARG INPUT_GIT_HOURS_VERSION=v0.1.2
ENV GIT_HOURS_VERSION=${INPUT_GIT_HOURS_VERSION}
RUN git clone --depth 1 --branch ${GIT_HOURS_VERSION} https://github.com/trinhminhtriet/git-hours.git /tmp/git-hours \ 
  && sed -i 's/go 1.24.1/go 1.24/' /tmp/git-hours/go.mod \ 
  && cd /tmp/git-hours && go install . \ 
  && rm -rf /tmp/git-hours

# Copy scripts and entrypoint
COPY scripts/ /scripts/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
