FROM python:3.11-slim

# Install system packages required for cloning repositories
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Add git-hours to PATH
COPY docker-action/bin/git-hours /usr/local/bin/git-hours
ENV PATH="/usr/local/bin:${PATH}"

# Copy all helper scripts into the image
COPY scripts/ /action/

ENTRYPOINT ["python3", "/action/org_coding_hours.py"]

