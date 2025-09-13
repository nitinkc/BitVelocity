#!/bin/bash

# Event Contracts Validation Script
# This script validates event contract schemas for compliance with BitVelocity standards

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/../event-contracts" && pwd)"
SCHEMA_DIR="$CONTRACTS_DIR/schema"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 BitVelocity Event Contracts Validation"
echo "=========================================="

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Error: jq is required but not installed.${NC}"
    echo "Please install jq to run this validation script."
    exit 1
fi

validate_file_naming() {
    local file="$1"
    local filename=$(basename "$file")
    
    # Check naming convention: entity.action.v<version>.json
    if [[ ! "$filename" =~ ^[a-z]+\.[a-z]+\.v[0-9]+\.json$ ]]; then
        echo -e "${RED}❌ Invalid file name: $filename${NC}"
        echo "   Expected format: entity.action.v<version>.json"
        return 1
    fi
    
    return 0
}

validate_event_type() {
    local file="$1"
    local filename=$(basename "$file")
    local dir_path=$(dirname "$file")
    
    # Extract expected eventType from path and filename
    local domain=$(basename "$(dirname "$dir_path")")
    local context=$(basename "$dir_path")
    local entity_action_version="${filename%.json}"
    
    # The naming convention is domain.context.entity.action.version
    # But the filename is entity.action.version, so we need to construct it properly
    local expected_event_type="${domain}.${context}.${entity_action_version}"
    
    # Get actual eventType from file
    local actual_event_type=$(jq -r '.properties.eventType.const // empty' "$file")
    
    if [[ "$actual_event_type" != "$expected_event_type" ]]; then
        echo -e "${RED}❌ EventType mismatch in $filename${NC}"
        echo "   Expected: $expected_event_type"
        echo "   Actual: $actual_event_type"
        return 1
    fi
    
    return 0
}

validate_required_fields() {
    local file="$1"
    local filename=$(basename "$file")
    
    # Required envelope fields
    local required_fields=(
        "eventId"
        "eventType" 
        "occurredAt"
        "producer"
        "traceId"
        "correlationId"
        "partitionKey"
        "schemaVersion"
        "payload"
    )
    
    local file_required=$(jq -r '.required[]?' "$file")
    
    for field in "${required_fields[@]}"; do
        if ! echo "$file_required" | grep -q "^$field$"; then
            echo -e "${RED}❌ Missing required field '$field' in $filename${NC}"
            return 1
        fi
    done
    
    return 0
}

# Main validation loop
validation_errors=0
total_files=0

echo "📁 Scanning event contracts directory: $CONTRACTS_DIR"
echo ""

while IFS= read -r -d '' file; do
    if [[ "$file" == *"/schema/"* ]]; then
        continue  # Skip schema files
    fi
    
    total_files=$((total_files + 1))
    filename=$(basename "$file")
    
    echo "🔍 Validating: $filename"
    
    # Run all validations
    if validate_file_naming "$file" && \
       validate_event_type "$file" && \
       validate_required_fields "$file"; then
        echo -e "   ${GREEN}✅ Valid${NC}"
    else
        validation_errors=$((validation_errors + 1))
        echo -e "   ${RED}❌ Invalid${NC}"
    fi
    
    echo ""
done < <(find "$CONTRACTS_DIR" -name "*.json" -type f -print0)

# Summary
echo "=========================================="
echo "📊 Validation Summary"
echo "   Total files: $total_files"
echo "   Errors: $validation_errors"

if [[ $validation_errors -eq 0 ]]; then
    echo -e "   ${GREEN}🎉 All event contracts are valid!${NC}"
    exit 0
else
    echo -e "   ${RED}💥 $validation_errors file(s) have validation errors${NC}"
    exit 1
fi