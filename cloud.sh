#!/bin/bash

# Check if the user provided the source directory
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <source_directory>"
    exit 1
fi

SOURCE_DIR="$1"
CONSOLIDATE_DIR="consolidated"

# Ensure the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR does not exist."
    exit 1
fi

# Create the consolidation directory if it doesn't exist
mkdir -p "$CONSOLIDATE_DIR"

# Function to compute file dates from filename
extract_date_from_filename() {
    local file="$1"
    local base_name=$(basename "$file")
    local date_part=$(echo "$base_name" | grep -oE '[0-9]{8}_[0-9]{6}')
    
    if [ -n "$date_part" ]; then
        # Convert YYYYMMDD_HHMMSS to YYYY-MM-DD_HH:MM:SS
        formatted_date=$(echo "$date_part" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)\(..\)/\1-\2-\3_\4:\5:\6/')
        echo "$formatted_date"
    else
        echo "Unknown"
    fi
}

# Function to preserve the file's creation and modification dates
preserve_dates() {
    local src="$1"
    local dest="$2"
    
    # Copy the file's access and modification times
    touch -r "$src" "$dest"
    
    # On macOS, you need to copy the creation date separately
    temp_file=$(mktemp)
    stat -f "%B" "$src" > "$temp_file"
    creation_date=$(cat "$temp_file")
    rm "$temp_file"
    
    # Apply creation date to destination file
    xattr -w com.apple.metadata:kMDItemContentCreationDate "$creation_date" "$dest"
}

# Process files in the source directory
find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \
                                -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \) |
while IFS= read -r file; do
    year=$(date -r "$file" +"%Y")
    
    # Create the year directory inside the consolidation directory if it doesn't exist
    mkdir -p "$CONSOLIDATE_DIR/$year"
    
    # Define the destination file path
    destination_file="$CONSOLIDATE_DIR/$year/$(basename "$file")"
    
    # Check if the destination file exists
    if [ -f "$destination_file" ]; then
        # Compare file size and modification time
        if [ "$(stat -f %z "$file")" -eq "$(stat -f %z "$destination_file")" ] && [ "$(stat -f %m "$file")" -eq "$(stat -f %m "$destination_file")" ]; then
            echo "Identical copy already exists at $destination_file. Skipping copy."
            continue
        else
            # Remove the destination file if it doesn't match and will be replaced
            rm -v "$destination_file"
        fi
    fi
    
    # Copy the file to the year directory
    cp -v "$file" "$destination_file"
    
    # Preserve the original file's dates
    preserve_dates "$file" "$destination_file"
done

echo "Consolidation complete. Files have been organized into '$CONSOLIDATE_DIR'."

