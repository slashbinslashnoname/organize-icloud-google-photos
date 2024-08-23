#!/bin/bash

# Ensure foldername is provided
if [ -z "$1" ]; then
  echo "Usage: $0 foldername [skip_folders...]"
  exit 1
fi

# Set the input folder and skip folders
INPUT_FOLDER="$1"
shift
SKIP_FOLDERS=("$@")

# Detect the platform (Linux or macOS)
if uname | grep -q "Darwin"; then
  PLATFORM="macOS"
else
  PLATFORM="Linux"
fi

# Function to convert timestamp to formatted date for touch command
convert_timestamp() {
  local TIMESTAMP="$1"
  if [ "$PLATFORM" = "macOS" ]; then
    # macOS date format for touch
    date -j -f "%s" "$TIMESTAMP" +"%Y%m%d%H%M.%S"
  else
    # Linux date format for touch
    date -d "@$TIMESTAMP" +"%Y%m%d%H%M.%S"
  fi
}

# Function to check if a directory should be skipped
should_skip() {
  local DIR="$1"
  for skip_folder in "${SKIP_FOLDERS[@]}"; do
    if [[ "$DIR" == *"$skip_folder"* ]]; then
      return 0
    fi
  done
  return 1
}

# Extract the year from the folder name
extract_year_from_folder() {
  local FOLDER="$1"
  echo "$FOLDER" | grep -o '[0-9]\{4\}' | head -n 1
}

# Extract the year from the JSON formatted date
extract_year_from_json() {
  local FORMATTED_DATE="$1"
  echo "$FORMATTED_DATE" | grep -o '[0-9]\{4\}' | head -n 1
}

# Loop through all media files in the input folder recursively
find "$INPUT_FOLDER" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.dng" -o -iname "*.cr2" -o -iname "*.nef" -o -iname "*.arw" \) | while read -r MEDIA_FILE; do

  # Determine the directory of the media file
  MEDIA_DIR=$(dirname "$MEDIA_FILE")

  # Skip the directory if it matches any skip folder pattern
  if should_skip "$MEDIA_DIR"; then
    echo "Skipping directory $MEDIA_DIR"
    continue
  fi

  # Extract media file base name and extension
  BASE_NAME=$(basename "${MEDIA_FILE%.*}")
  EXTENSION="${MEDIA_FILE##*.}"

  # Define potential JSON file paths
  JSON_FILE="${MEDIA_FILE}.json"
  JSON_FILE_FALLBACK="${MEDIA_FILE%.*}.json"

  # Search for the JSON file with a pattern match if the exact JSON file does not exist
  if [ ! -f "$JSON_FILE" ] && [ ! -f "$JSON_FILE_FALLBACK" ]; then
    # Construct potential JSON file name patterns
    JSON_FILE_PATTERN=$(dirname "$MEDIA_FILE")/"$BASE_NAME"*.json
    JSON_FILE=$(ls $JSON_FILE_PATTERN 2>/dev/null | head -n 1)

    # If a JSON file is found, update JSON_FILE to the found file
    if [ -n "$JSON_FILE" ]; then
      echo "Using JSON file $JSON_FILE"
    else
      echo "JSON file for $MEDIA_FILE does not exist. Skipping..."
      continue
    fi
  fi

  # Extract JSON file path (either exact or fallback or found pattern)
  if [ -f "$JSON_FILE" ]; then
    JSON_FILE="$JSON_FILE"
  else
    JSON_FILE="$JSON_FILE_FALLBACK"
  fi

  # Extract the year from the folder name first
  YEAR=$(extract_year_from_folder "$MEDIA_DIR")

  # If the year is not found in the folder name, check the JSON metadata
  if [ -z "$YEAR" ]; then
    if [ -f "$JSON_FILE" ]; then
      PHOTO_TAKEN_TIME=$(jq -r '.photoTakenTime.formatted' "$JSON_FILE")
      YEAR=$(extract_year_from_json "$PHOTO_TAKEN_TIME")
    fi
  fi

  # Default to "unknown" if no year is found
  YEAR=${YEAR:-"unknown"}

  # Extract the timestamp if available
  if [ -f "$JSON_FILE" ]; then
    PHOTO_TAKEN_TIMESTAMP=$(jq -r '.photoTakenTime.timestamp' "$JSON_FILE")
    if [ -n "$PHOTO_TAKEN_TIMESTAMP" ]; then
      FORMATTED_DATE=$(convert_timestamp "$PHOTO_TAKEN_TIMESTAMP")
    else
      FORMATTED_DATE=$(date +"%Y%m%d%H%M.%S")
    fi
  else
    # Use the current date if no timestamp is available
    FORMATTED_DATE=$(date +"%Y%m%d%H%M.%S")
  fi

  # Determine the destination path
  DEST_DIR="consolidated/$YEAR"
  DEST_FILE="$DEST_DIR/$(basename "$MEDIA_FILE")"

  # Check if the file already exists in the destination folder
  if [ -f "$DEST_FILE" ]; then
    echo "File $DEST_FILE already exists. Skipping..."
    continue
  fi

  # Create the destination directory if it doesn't exist
  mkdir -p "$DEST_DIR"

  # Copy the media file to the destination directory
  cp "$MEDIA_FILE" "$DEST_FILE"

  # Update the file's creation and modification dates
  touch -t "$FORMATTED_DATE" "$DEST_FILE"

  echo "Processed $MEDIA_FILE -> $DEST_FILE"

done

