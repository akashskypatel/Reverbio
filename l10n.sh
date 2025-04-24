#!/bin/bash

# Usage: ./l10n.sh "key" "value" [l10n_dir]

KEY="$1"
VALUE="$2"
L10N_DIR="${3:-./lib/localization}"

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
  echo "Error: Both key and value arguments are required"
  echo "Usage: $0 \"key\" \"value\" [l10n_dir]"
  exit 1
fi

if [ ! -d "$L10N_DIR" ]; then
  echo "Error: Directory $L10N_DIR not found"
  exit 1
fi

# JSON escape function
json_escape() {
  echo "$1" | sed -e 's/[\\"]/\\&/g' -e 's/\//\\\//g'
}

ESCAPED_VALUE=$(json_escape "$VALUE")

# Process each ARB file
find "$L10N_DIR" -name "*.arb" | while read -r file; do
  echo "Processing $file"

  # Create temp files
  tmp_file=$(mktemp)
  metadata_file=$(mktemp)
  entries_file=$(mktemp)

  # Split into metadata and entries
  awk '
    /^[[:space:]]*@/ { print > "'"$metadata_file"'"; next }
    /^[[:space:]]*"/ { print > "'"$entries_file"'"; next }
    { print >> "'"$metadata_file"'" }
  ' "$file"

  # Remove existing key if present
  grep -v "\"$KEY\":" "$entries_file" > "${entries_file}.tmp"
  mv "${entries_file}.tmp" "$entries_file"

  # Add/update entry
  echo "  \"$KEY\": \"$ESCAPED_VALUE\"," >> "$entries_file"

  # Sort entries alphabetically
  sort -o "$entries_file" "$entries_file"

  # Remove trailing comma from last entry
  sed -i -e '$s/,$//' "$entries_file"

  # Rebuild file
  {
    # Preserve initial {
    grep -m 1 '^{' "$file" || echo "{"
    
    # Metadata section
    grep -v '^{' "$metadata_file" | grep -v '^}'
    
    # Sorted entries
    cat "$entries_file"
    
    # Closing brace
    echo "}"
  } > "$tmp_file"

  # Validate basic JSON structure
  if grep -q '^{' "$tmp_file" && grep -q '^}' "$tmp_file"; then
    mv "$tmp_file" "$file"
    echo "  Updated '$KEY'"
  else
    echo "  ERROR: Failed to generate valid JSON for $file"
    rm -f "$tmp_file"
  fi

  # Cleanup
  rm -f "$metadata_file" "$entries_file"
done

echo "Update complete"