#!/bin/bash

# Script to add and activate a new watsonx Orchestrate SaaS environment for ADK
# Usage: ./add-orchestrate-env.sh

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to validate URL format
validate_url() {
    local url=$1
    if [[ ! $url =~ ^https?:// ]]; then
        return 1
    fi
    return 0
}

# Function to validate API key (basic check for non-empty)
validate_api_key() {
    local key=$1
    if [[ -z "$key" || ${#key} -lt 10 ]]; then
        return 1
    fi
    return 0
}

# Main script
echo "================================================"
echo "  watsonx Orchestrate SaaS Environment Setup"
echo "================================================"
echo ""

# Prompt for environment name
read -p "coverage-test-bob-1" ENV_NAME
if [[ -z "$ENV_NAME" ]]; then
    print_error "Environment name cannot be empty"
    exit 1
fi

# Prompt for environment URL
read -p "https://api.dl.watson-orchestrate.ibm.com/instances/20250515-2143-5278-0081-5721aa0b2cb4" ENV_URL
if ! validate_url "$ENV_URL"; then
    print_error "Invalid URL format. URL must start with http:// or https://"
    exit 1
fi

# Remove trailing slash from URL if present
ENV_URL=${ENV_URL%/}

# Prompt for API key (hidden input)
read -s -p "Enter API key: " API_KEY
echo ""
if ! validate_api_key "$API_KEY"; then
    print_error "Invalid API key. Key must be at least 10 characters long"
    exit 1
fi

# Create or update ADK configuration directory
CONFIG_DIR="$HOME/.adk"
CONFIG_FILE="$CONFIG_DIR/config.json"

print_info "Setting up configuration directory..."
mkdir -p "$CONFIG_DIR"

# Check if config file exists
if [[ -f "$CONFIG_FILE" ]]; then
    print_warning "Configuration file already exists. Creating backup..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create configuration JSON
print_info "Creating configuration for environment: $ENV_NAME"
cat > "$CONFIG_FILE" << EOF
{
  "environments": {
    "$ENV_NAME": {
      "url": "$ENV_URL",
      "apiKey": "$API_KEY",
      "active": true,
      "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  },
  "activeEnvironment": "$ENV_NAME"
}
EOF

# Set appropriate permissions (read/write for owner only)
chmod 600 "$CONFIG_FILE"

print_info "Configuration file created at: $CONFIG_FILE"

# Create environment file for easy sourcing
ENV_FILE="$CONFIG_DIR/env.$ENV_NAME.sh"
cat > "$ENV_FILE" << EOF
#!/bin/bash
# Environment variables for $ENV_NAME
export ORCHESTRATE_ENV_NAME="$ENV_NAME"
export ORCHESTRATE_URL="$ENV_URL"
export ORCHESTRATE_API_KEY="$API_KEY"
EOF

chmod 600 "$ENV_FILE"

print_info "Environment file created at: $ENV_FILE"

# Test connection (optional)
echo ""
read -p "Would you like to test the connection? (y/n): " TEST_CONN
if [[ "$TEST_CONN" =~ ^[Yy]$ ]]; then
    print_info "Testing connection to $ENV_URL..."
    
    # Simple curl test to check if the endpoint is reachable
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "Authorization: Bearer $API_KEY" \
        "$ENV_URL/api/health" | grep -q "^[23]"; then
        print_info "Connection test successful!"
    else
        print_warning "Connection test failed or endpoint not reachable. Please verify your URL and API key."
    fi
fi

# Summary
echo ""
echo "================================================"
print_info "Setup completed successfully!"
echo "================================================"
echo ""
echo "Environment Details:"
echo "  Name: $ENV_NAME"
echo "  URL: $ENV_URL"
echo "  Config: $CONFIG_FILE"
echo ""
echo "To activate this environment in your shell, run:"
echo "  source $ENV_FILE"
echo ""
echo "To use with ADK commands, the configuration is now active."
echo ""

exit 0

# Made with Bob
