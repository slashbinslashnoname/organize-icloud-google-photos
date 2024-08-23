#!/bin/bash

# Function to preserve timestamps
preserve_timestamps() {
    local src="$1"
    local dst="$2"
    touch -r "$src" "$dst"
}

# Function to convert media files
convert_media() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    local base="${filename%.*}"
    local output_file="${file%/*}/${base}-converted.mp4"
    
    # Check if the file already contains '-converted' in its name
    if [[ "$filename" != *"-converted"* ]]; then
        echo "Converting $file to $output_file"
        
        # Convert the file to libx264 format
        ffmpeg -i "$file" -vcodec libx264 -acodec aac "$output_file"
        
        # Preserve timestamps
        preserve_timestamps "$file" "$output_file"
        
        # Remove the original file if conversion is successful
        if [[ $? -eq 0 ]]; then
            echo "Removing original file: $file"
            rm "$file"
        else
            echo "Error converting $file"
        fi
    else
        echo "Skipping already converted file: $file"
    fi
}

# Function to process each directory recursively
process_directory() {
    local dir="$1"
    for file in "$dir"/*; do
        if [[ -d "$file" ]]; then
            process_directory "$file"
        elif [[ -f "$file" ]]; then
            # Convert filename to lowercase to check extension
            local file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
            # Check if the file is a video file
            case "$file_lower" in
                *.mp4|*.mov|*.avi|*.mkv|*.flv|*.wmv|*.m4v|*.mpeg|*.mpg)
                    convert_media "$file"
                    ;;
                *)
                    echo "Skipping non-video file: $file"
                    ;;
            esac
        fi
    done
}

# Check if the media directory is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <media_directory>"
    exit 1
fi

MEDIA_DIR="$1"

# Ensure the provided path is a directory
if [[ ! -d "$MEDIA_DIR" ]]; then
    echo "Error: $MEDIA_DIR is not a directory"
    exit 1
fi

# Process the main directory and its subdirectories
process_directory "$MEDIA_DIR"

echo "All files processed."

