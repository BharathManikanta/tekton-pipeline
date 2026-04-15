#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)
BUILD_NUMBER=$(date +%s)
CI_PROJECT_NAME="tekton-pipeline"

echo "Workspace: $WORKSPACE"
echo "Build Number: $BUILD_NUMBER"

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)

echo "$CHANGED_FILES"

# Extract services
echo "$CHANGED_FILES" | grep '^sourcecode/services/' | awk -F'/' '{print $3}' | sort | uniq > .changed_services

# Extract libraries
echo "$CHANGED_FILES" | grep '^sourcecode/libraries/' | awk -F'/' '{print $3}' | sort | uniq > .changed_libraries

echo "Changed services:"
cat .changed_services || true

echo "Changed libraries:"
cat .changed_libraries || true

if [ ! -s .changed_services ] && [ ! -s .changed_libraries ]; then
  echo "No changes detected. Exiting."
  exit 0
fi

mkdir -p bar
mkdir -p build_workspace

# 🔥 Flatten structure
echo "Preparing build workspace..."

cp -r sourcecode/services/* build_workspace/ 2>/dev/null || true
cp -r sourcecode/libraries/* build_workspace/ 2>/dev/null || true

COMMON_LIBS="CommonLibrary Exception_Handler"

# -------------------------------
# 🔥 BUILD + UPLOAD FUNCTION
# -------------------------------
build_bar() {
  NAME=$1
  TYPE=$2

  echo "-----------------------------------"
  echo "Building $TYPE: $NAME"

  BAR_FILE="bar/${CI_PROJECT_NAME}-${NAME}-v${BUILD_NUMBER}.bar"

  if [ "$TYPE" == "service" ]; then

    PROJECTS="--project $NAME"

    for lib in $COMMON_LIBS; do
      PROJECTS="$PROJECTS --project $lib"
    done

    ibmint package \
      --input-path build_workspace \
      $PROJECTS \
      --output-bar-file "$BAR_FILE"

  else
    ibmint package \
      --input-path build_workspace \
      --project "$NAME" \
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

  # Versioned upload
  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${NAME}-v${BUILD_NUMBER}.bar"

  # Timestamp latest
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${NAME}-latest-${TIMESTAMP}.bar"

  # Static latest
  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${NAME}-latest.bar"

  echo "Upload completed for $NAME"
}

# -------------------------------
# 🔨 Build services
# -------------------------------
if [ -s .changed_services ]; then
  while read service; do
    [ -z "$service" ] && continue
    build_bar "$service" "service"
  done < .changed_services
fi

# -------------------------------
# 🔨 Build libraries
# -------------------------------
if [ -s .changed_libraries ]; then
  while read lib; do
    [ -z "$lib" ] && continue
    build_bar "$lib" "library"
  done < .changed_libraries
fi

echo "===== BUILD COMPLETED ====="
ls -l bar/
