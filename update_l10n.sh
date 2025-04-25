#!/bin/bash

# Force LTR interpretation for the entire script
export LC_ALL=C

# Script to update localization ARB files from a JSON source
# Usage: ./update_l10n.sh

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq first." >&2
    exit 1
fi

# Check if input file exists
INPUT_FILE="l10nupdate.json"
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE not found in current directory." >&2
    exit 1
fi

# Directory containing ARB files
L10N_DIR="./lib/localization"
if [ ! -d "$L10N_DIR" ]; then
    echo "Error: Localization directory $L10N_DIR not found." >&2
    exit 1
fi

# Get all language codes from the JSON file
languages=$(jq -r '.translations | map(keys) | add | unique[]' "$INPUT_FILE" 2>/dev/null | LC_ALL=C sort)

if [ -z "$languages" ]; then
    echo "Error: Could not extract language codes from JSON file." >&2
    echo "Please verify the JSON structure matches:"
    echo '{
      "translations": {
        "key": {
          "languageCode": "translation",
          ...
        },
        ...
      }
    }'
    exit 1
fi

# Process each language
for lang in $languages; do
    # Skip English (en) as it's typically the source language
    if [ "$lang" == "en" ]; then
        continue
    fi
    
    # Sanitize language code by removing all non-alphanumeric characters
    clean_lang=$(printf '%s' "$lang" | tr -cd '[:alnum:]-')
    
    # Construct filename in one atomic operation with sanitized language code
    filename="app_${clean_lang}.arb"

    # Handle special cases for Chinese variants
    case "$clean_lang" in
        "zh-Hant") arb_file="$L10N_DIR/app_zh-Hant.arb" ;;
        "zh-TW") arb_file="$L10N_DIR/app_zh-TW.arb" ;;
        "zh") arb_file="$L10N_DIR/app_zh.arb" ;;
        *) arb_file="$L10N_DIR/app_$clean_lang.arb" ;;
    esac

    arb_file="${L10N_DIR}/${filename}"
    # Check if ARB file exists
    if [ ! -f "$arb_file" ]; then
        echo "Warning: ARB file $arb_file not found. Skipping..."
        continue
    fi
    
    echo "Updating $arb_file"
    
    # Create a temporary file
    tmp_file=$(mktemp)
    
    # Get all translations for this language
    translations=$(jq -r --arg clean_lang "$clean_lang" '.translations | to_entries[] | select(.value[$clean_lang]) | "\(.key)=\(.value[$clean_lang] | gsub("\n"; "") | gsub("\r"; ""))"' "$INPUT_FILE" 2>/dev/null)
    
    if [ -z "$translations" ]; then
        echo "Warning: No translations found for language $clean_lang"
        continue
    fi
    
    # Start with the original file
    cp "$arb_file" "$tmp_file"
    
    # Process each translation
    while IFS="=" read -r key value; do
        clean_value=$(printf '%s' "$value" | tr -d '\r')
        # Check if the key already exists in the ARB file
        if jq -e ".$key" "$tmp_file" >/dev/null 2>&1; then
            # Key exists - update it
            jq --arg key "$key" --arg clean_value "$clean_value" '.[$key] = $clean_value' "$tmp_file" > "${tmp_file}.tmp" && mv "${tmp_file}.tmp" "$tmp_file"
        else
            # Key doesn't exist - add it
            jq --arg key "$key" --arg clean_value "$clean_value" '. + {($key): $clean_value}' "$tmp_file" > "${tmp_file}.tmp" && mv "${tmp_file}.tmp" "$tmp_file"
        fi
    done <<< "$translations"
    
    # Format the JSON file and update the original
    jq . "$tmp_file" > "$arb_file"
    rm "$tmp_file"
done