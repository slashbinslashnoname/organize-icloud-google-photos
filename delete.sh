#!/bin/bash

# Function to delete files with -consolidated in their names
delete_consolidated_files() {
    local directory="$1"
    
    # Find and delete files with -consolidated in their names
    find "$directory" -type f -name '*-compressed*' -exec rm -v {} \;
}

# Main script logic
# Check if the user provided a directory or not
if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [directory]"
    exit 1
fi

# Set directory to the current directory if not provided
if [ "$#" -eq 0 ]; then
    input_directory="."
else
    input_directory="$1"
fi

# Check if the directory exists
if [ ! -d "$input_directory" ]; then
    echo "Directory $input_directory does not exist."
    exit 1
fi

# Start processing
delete_consolidated_files "$input_directory"

echo "Deletion of -consolidated files completed."

