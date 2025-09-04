#!/bin/bash

# Specify the date for naming the directory
DATE=$(date +%Y-%m-%d)

# Create the backup directory
DEST_DIR="/data/bakcup/services/$DATE"
mkdir -p "$DEST_DIR"

# Array of files to copy
FILES_TO_COPY=(
    "appsettings.json"
    "appsettingsBlackMark.json"
    "rabbitmqSettings.json"
    "massTransitSettings.json"
    "AvailableParticipant.json"
    "Hub25NsiSystemTimeoutSettings.json"
    "users.json"
)

# Find and copy the specified files
find /opt/N3/N3.*/r*/ -type f | while read -r FILE; do
    # Extract the file name from the path
    FILENAME=$(basename "$FILE")

    # Check if the file should be copied
    if [[ " ${FILES_TO_COPY[@]} " =~ " ${FILENAME} " ]]; then
        echo "Found file: $FILE"  # Output the found file
        
        # Form the target path
        TARGET_DIR="$DEST_DIR/$(dirname "${FILE#/opt/N3/}")"
        
        mkdir -p "$TARGET_DIR"  # Create the directory if it doesn't exist
        cp "$FILE" "$TARGET_DIR/"  # Copy the file to the target directory
    fi
done
