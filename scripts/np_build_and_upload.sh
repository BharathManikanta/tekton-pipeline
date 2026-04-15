#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
echo "BUILD_NUMBER=$BUILD_NUMBER" > .env

CI_PROJECT_NAME="tekton-pipeline"

# -------------------------------
# 🔍 Detect changed files
# -------------------------------
echo "Detecting changed files..."

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
echo "$CHANGED_FILES"

# Extract services
echo "$CHANGED_FILES" | \
  grep '^sourcecode/services/' | \
  awk -F'/' '{print $3}' | sort | uniq > .changed_services

# Extract libraries
echo "$CHANGED_FILES" | \
  grep '^sourcecode/libraries/' | \
  awk -F'/' '{print $3}' | sort | uniq > .changed_libraries

echo "Changed services:"
cat .changed_services || true

echo "Changed libraries:"
cat .changed_libraries || true

# Exit if nothing changed
if [ ! -s .changed_services ] && [ ! -s .changed_libraries ]; then
  echo "No changes detected. Exiting build."
  exit 0
fi

# -------------------------------
# 📦 Setup
# -------------------------------
mkdir -p bar

TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "TIMESTAMP=$TIMESTAMP" >> .env

ROOT_PATH="sourcecode"

# -------------------------------
# 🔥 COMMON BUILD FUNCTION
# -------------------------------
build_bar() {
  NAME=$1
  TYPE=$2   # service or library

  echo "-----------------------------------"
  echo "Building $TYPE: $NAME"

  if [ "$TYPE" == "service" ]; then
    INPUT_PATH="$ROOT_PATH"
    EXTRA_ARGS="--application $NAME"
  else
    INPUT_PATH="$ROOT_PATH/libraries/$NAME"
    EXTRA_ARGS=""
  fi

  BAR_FILE="bar/${CI_PROJECT_NAME}-${NAME}-v${BUILD_NUMBER}.bar"

  # ✅ SINGLE COMMAND USED FOR BOTH
  ibmint package \
    --input-path "$INPUT_PATH" \
    --output-bar-file "$BAR_FILE" \
    $EXTRA_ARGS

  if [ ! -f "$BAR_FILE" ]; then
    echo "ERROR: BAR not created for $NAME"
    return
  fi

  echo "Uploading $NAME to Nexus..."

  curl -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${NAME}-v${BUILD_NUMBER}.bar"

  curl -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${NAME}-latest-${TIMESTAMP}.bar"

  curl -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${NAME}-latest.bar"
}

# -------------------------------
# 🔨 Build SERVICES
# -------------------------------
if [ -s .changed_services ]; then
  while read service; do
    [ -z "$service" ] && continue
    build_bar "$service" "service"
  done < .changed_services
fi

# -------------------------------
# 🔨 Build LIBRARIES
# -------------------------------
if [ -s .changed_libraries ]; then
  while read lib; do
    [ -z "$lib" ] && continue
    build_bar "$lib" "library"
  done < .changed_libraries
fi

echo "===== BUILD COMPLETED ====="

ls -l bar/
