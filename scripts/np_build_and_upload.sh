#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
echo "BUILD_NUMBER=$BUILD_NUMBER" > .env

CI_PROJECT_NAME="tekton-pipeline"

echo "Build Number: $BUILD_NUMBER"

# -------------------------------
# 🔍 Detect changed files
# -------------------------------
echo "Detecting changed files..."

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)

echo "$CHANGED_FILES"

# ✅ Extract ONLY services
echo "$CHANGED_FILES" | \
  grep '^sourcecode/services/' | \
  awk -F'/' '{print $3}' | \
  sort | uniq > .changed_services

echo "Changed services:"
cat .changed_services || true

# Exit if no changes
if [ ! -s .changed_services ]; then
  echo "No changes detected. Exiting build."
  exit 0
fi

# -------------------------------
# 📦 Prepare BAR folder
# -------------------------------
mkdir -p bar

TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "TIMESTAMP=$TIMESTAMP" >> .env

# -------------------------------
# 🔨 Build BAR files
# -------------------------------
echo "===== BUILDING BAR FILES ====="

while read service; do

  echo "-----------------------------------"
  echo "Processing service: $service"

  SERVICE_PATH="sourcecode/services/$service"

  if [ ! -d "$SERVICE_PATH" ]; then
    echo "Skipping $service (directory not found)"
    continue
  fi

  echo "Building BAR for $service..."

  ibmint package \
    --input-path "$SERVICE_PATH" \
    --output-bar-file bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar

  BAR_FILE="bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  if [ ! -f "$BAR_FILE" ]; then
    echo "ERROR: BAR not created for $service"
    continue
  fi

  echo "BAR created: $BAR_FILE"

  # Upload
  echo "Uploading $service to Nexus..."

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-latest-${TIMESTAMP}.bar"

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-latest.bar"

done < .changed_services

echo "===== BUILD COMPLETED ====="

ls -l bar/

cp .env "$WORKSPACE" || true
cp .changed_services "$WORKSPACE" || true
