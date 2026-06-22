#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Project configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Oracle.Bill"
SCHEME="Oracle.Bill"
CONFIGURATION="Release"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_DIR="${PROJECT_DIR}/dist"
APP_NAME="Oracle.Bill.app"
ZIP_NAME="Oracle.Bill.zip"
DMG_NAME="Oracle.Bill.dmg"

echo "============================================="
echo "Building ${PROJECT_NAME} for Release"
echo "============================================="

# Clean build and output directories
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build the project
echo "🛠️ Compiling and building app bundle..."
xcodebuild \
  -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk macosx \
  -derivedDataPath "${BUILD_DIR}" \
  clean build

# Path to the compiled app bundle
BUILT_APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}"

if [ ! -d "${BUILT_APP_PATH}" ]; then
  echo "❌ Error: Built application not found at ${BUILT_APP_PATH}"
  exit 1
fi

# Copy the app to the output directory
echo "📦 Copying built app to ${OUTPUT_DIR}..."
cp -R "${BUILT_APP_PATH}" "${OUTPUT_DIR}/"

# Create a zip archive of the app
echo "🗜️ Creating ZIP archive..."
(cd "${OUTPUT_DIR}" && zip -r -y -9 "${ZIP_NAME}" "${APP_NAME}")

# Create a DMG installer
echo "💿 Creating DMG installer..."
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app and create link to Applications
cp -R "${BUILT_APP_PATH}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Generate the DMG
hdiutil create \
  -volname "Oracle Bill" \
  -srcfolder "${DMG_TEMP_DIR}" \
  -ov \
  -format UDZO \
  "${OUTPUT_DIR}/${DMG_NAME}"

# Clean up build artifacts, leaving only the dist folder
echo "🧹 Cleaning up intermediate build artifacts..."
rm -rf "${BUILD_DIR}"

echo "============================================="
echo "🎉 Release build completed successfully!"
echo "Artifacts are available in: ${OUTPUT_DIR}"
echo "  - App Bundle: ${OUTPUT_DIR}/${APP_NAME}"
echo "  - ZIP Archive: ${OUTPUT_DIR}/${ZIP_NAME}"
echo "  - DMG Installer: ${OUTPUT_DIR}/${DMG_NAME}"
echo "============================================="
