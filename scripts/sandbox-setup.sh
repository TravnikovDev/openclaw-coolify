#!/bin/bash
set -e

# Inherit DOCKER_HOST if set, or default to socket proxy
export DOCKER_HOST="${DOCKER_HOST:-tcp://docker-proxy:2375}"

echo "🦞 Building OpenClaw Sandbox Base Image..."

if ! command -v docker >/dev/null 2>&1; then
    echo "⚠️  Skipping sandbox base image bootstrap: docker CLI is not installed in this container."
    exit 0
fi

if ! docker version >/dev/null 2>&1; then
    echo "⚠️  Skipping sandbox base image bootstrap: cannot reach Docker via $DOCKER_HOST."
    echo "   Docker-backed sandbox sessions will remain unavailable until the Docker proxy is reachable."
    exit 0
fi

# Use python slim as a solid base
BASE_IMAGE="python:3.11-slim-bookworm"
TARGET_IMAGE="openclaw-sandbox:bookworm-slim"

# Check if image already exists
if docker image inspect "$TARGET_IMAGE" >/dev/null 2>&1; then
    echo "✅ Sandbox base image already exists: $TARGET_IMAGE"
    exit 0
fi

echo "   Pulling $BASE_IMAGE..."
docker pull "$BASE_IMAGE"

echo "   Tagging as $TARGET_IMAGE..."
docker tag "$BASE_IMAGE" "$TARGET_IMAGE"

echo "✅ Sandbox base image ready: $TARGET_IMAGE"
