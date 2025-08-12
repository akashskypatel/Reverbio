#!/bin/bash

#!/bin/bash

# Check if argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [major|minor|patch]"
    exit 1
fi

# Validate argument
case "$1" in
    major|minor|patch)
        ;;
    *)
        echo "Error: Invalid argument. Use 'major', 'minor', or 'patch'."
        exit 1
        ;;
esac

# Extract current version from pubspec.yaml
CURRENT_VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}' | tr -d '"')
IFS='+' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
IFS='.' read -ra SEMVER <<< "${VERSION_PARTS[0]}"

# Increment version based on argument
case "$1" in
    major)
        NEW_VERSION="$((SEMVER[0] + 1)).0.0${VERSION_PARTS[1]}"
        ;;
    minor)
        NEW_VERSION="${SEMVER[0]}.$((SEMVER[1] + 1)).0${VERSION_PARTS[1]}"
        ;;
    patch)
        NEW_VERSION="${SEMVER[0]}.${SEMVER[1]}.$((SEMVER[2] + 1))${VERSION_PARTS[1]}"
        ;;
esac

# Update pubspec.yaml
sed -i "s/version: $CURRENT_VERSION/version: $NEW_VERSION/" pubspec.yaml
echo "✅ Updated version: $CURRENT_VERSION → $NEW_VERSION ($1 bump)"

# Read the version from pubspec.yaml
version=$(grep version pubspec.yaml | awk -F'[ +]' '{print $2}' | tr -d "'")

# Define the variable name and file name
variable="appVersion"
filename="lib/API/version.dart"

# Write the version to the Dart file
echo "const $variable = '$version';" > $filename
