#!/bin/bash

# Find all changed YAML files
files=$(git diff --name-only origin/main...HEAD | grep '\.github/workflows/.*\.yml$')
if [ -z "$files" ]; then
    echo "No YAML workflow files changed. Skipping check."
    exit 0
fi

# Function to check the node version of an action
check_node_version() {
    action=$1
    owner_repo=$(echo "$action" | cut -d'@' -f1)
    version=$(echo "$action" | cut -d'@' -f2)
    metadata_url="https://raw.githubusercontent.com/$owner_repo/$version/action.yml"
    metadata=$(curl -s $metadata_url)
    if [ -z "$metadata" ]; then
        metadata_url="https://raw.githubusercontent.com/$owner_repo/$version/action.yaml"
        metadata=$(curl -s $metadata_url)
    fi
    if [ -z "$metadata" ]; then
        echo "Warning: Could not retrieve metadata for $action"
        return 1
    fi
    node_version=$(echo "$metadata" | yq -r '.runs.using' -)
    if [[ "$node_version" == *"node12"* || "$node_version" == *"node14"* || "$node_version" == *"node16"* ]]; then
        echo "Error: $action uses deprecated Node.js version $node_version"
        return 1
    else
        echo "$action uses supported Node.js version $node_version"
        return 0
    fi
}

error=0
# Check each changed YAML file
for file in $files; do
    echo
    echo "***************************************************"
    echo "Checking $file..."

    # Parse each action's uses line and check the version
    while read -r use; do
        echo "Checking action: $use"
        check_node_version "$use"
        if [ $? -ne 0 ]; then
            error=1
            echo "Action file $file contains action $use with deprecated Node.js version"
        fi
    done <<< "$(yq -r '.jobs[] | .steps[] | select(.uses) | .uses' "$file")"
done

echo "Check complete."
if [ $error -eq 1 ]; then
    echo "One or more modified actions uses a deprecated Node.js version."
    exit 1
fi
