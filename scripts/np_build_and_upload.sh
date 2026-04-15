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

# -------------------------------
# ✅ Extract changed services
# -------------------------------
echo "$CHANGED_FILES" | \
  grep '^sourcecode/services/' | \
  awk -F'/' '{print $3}' | \
  sort | uniq > .changed_services

# -------------------------------
# ✅ Extract changed libraries
# -------------------------------
echo "$CHANGED_FILES" | \
  grep '^sourcecode/libraries/' | \
  awk -F'/' '{print $3}' | \
  sort | uniq > .changed_libraries

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
# 📦 Prepare BAR folder
# -------------------------------
mkdir -p bar

TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "TIMESTAMP=$TIMESTAMP" >> .env

ROOT_PATH="sourcecode"

# 👉 Libraries (like -l in mqsicreatebar)
COMMON_LIBS="CommonLibrary Exception_Handler"

# -------------------------------
# 🔥 COMMON BUILD FUNCTION
# -------------------------------
build_bar() {
  NAME=$1
  TYPE=$2

  echo "-----------------------------------"
  echo "Building $TYPE: $NAME"

  BAR_FILE="bar/${CI_PROJECT_NAME}-${NAME}-v${BUILD_NUMBER}.bar"

  if [ "$TYPE" == "service" ]; then

    echo "Including libraries: $COMMON_LIBS"

    # ✅ FIX: use correct relative paths
    PROJECT_ARGS="--project services/$NAME"

    for lib in $COMMON_LIBS; do
      PROJECT_ARGS="$PROJECT_ARGS --project libraries/$lib"
    done

    ibmint package \
      --input-path "$ROOT_PATH" \
      $PROJECT_ARGS \
      --output-bar-file "$BAR_FILE"

  else
    # ✅ FIX: correct library path
    ibmint package \
      --input-path "$ROOT_PATH" \
      --project "libraries/$NAME" \
      --output-bar-file "$BAR_FILE"
  fi

  if [ ! -f "$BAR_FILE" ]; then
    echo "ERROR: BAR not created for $NAME"
    return
  fi

  echo "BAR created: $BAR_FILE"

  # -------------------------------
  # 🚀 Upload to Nexus
  # -------------------------------
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
echo "===== BUILDING SERVICE BAR FILES ====="

if [ -s .changed_services ]; then
  while read service; do
    [ -z "$service" ] && continue
    build_bar "$service" "service"
  done < .changed_services
fi

# -------------------------------
# 🔨 Build LIBRARIES
# -------------------------------
echo "===== BUILDING LIBRARY BAR FILES ====="

if [ -s .changed_libraries ]; then
  while read lib; do
    [ -z "$lib" ] && continue
    build_bar "$lib" "library"
  done < .changed_libraries
fi

echo "===== BUILD COMPLETED ====="

ls -l bar/
