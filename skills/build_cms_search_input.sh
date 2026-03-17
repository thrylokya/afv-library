#!/usr/bin/env bash
# Build CMS Search Input JSON
#
# Generates properly formatted input JSON for search_media_cms_channels MCP tool.
# Cross-platform compatible: Mac, Windows (Git Bash/MSYS/Cygwin), Linux, POSIX
#
# Usage:
#   bash build_cms_search_input.sh --keywords "car,automobile,vehicle" --taxonomies "Modern,Luxury" --locale "en_US"
#   bash build_cms_search_input.sh --keywords "car" --taxonomies "Luxury"
#
# Examples:
#   # With empty keywords
#   bash build_cms_search_input.sh --keywords "" --taxonomies "Bright,Spacious" --locale "en_US"
#
#   # With empty taxonomies
#   bash build_cms_search_input.sh --keywords "logo,brand" --taxonomies "" --locale "en_US"
#
#   # With page parameters
#   bash build_cms_search_input.sh --keywords "car" --taxonomies "Luxury" --locale "en_US" --limit 10 --offset 0

set -e

# Default values
KEYWORDS=""
TAXONOMIES=""
LOCALE="en_US"
PAGE_OFFSET=0
PAGE_LIMIT=5

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keywords)
            KEYWORDS="$2"
            shift 2
            ;;
        --taxonomies)
            TAXONOMIES="$2"
            shift 2
            ;;
        --locale)
            LOCALE="$2"
            shift 2
            ;;
        --offset)
            PAGE_OFFSET="$2"
            shift 2
            ;;
        --limit)
            PAGE_LIMIT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --keywords KEYWORDS --taxonomies TAXONOMIES [--locale LOCALE] [--offset OFFSET] [--limit LIMIT]"
            echo ""
            echo "Required arguments:"
            echo "  --keywords KEYWORDS        Comma-separated keywords (e.g., 'car,automobile,vehicle')"
            echo "                             Use empty string '' for no keywords"
            echo "  --taxonomies TAXONOMIES    Comma-separated taxonomy labels (e.g., 'Modern,Luxury')"
            echo "                             Use empty string '' for no taxonomies"
            echo ""
            echo "Optional arguments:"
            echo "  --locale LOCALE            Language locale (default: 'en_US')"
            echo "  --offset OFFSET            Page offset for pagination (default: 0)"
            echo "  --limit LIMIT              Number of results to return (default: 5)"
            echo ""
            echo "Examples:"
            echo "  $0 --keywords 'car,automobile,vehicle' --taxonomies 'Modern,Luxury' --locale 'en_US'"
            echo "  $0 --keywords '' --taxonomies 'Bright,Spacious' --locale 'en_US'"
            echo "  $0 --keywords 'logo,brand' --taxonomies '' --locale 'en_US' --limit 10"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to build search keyword (OR-separated)
build_search_keyword() {
    local keywords="$1"

    if [[ -z "$keywords" ]]; then
        echo ""
        return
    fi

    # Replace commas with " OR "
    local result=$(echo "$keywords" | sed 's/,/ OR /g' | sed 's/  */ /g')
    echo "$result"
}

# Function to build taxonomy expression (JSON string)
build_taxonomy_expression() {
    local taxonomies="$1"

    if [[ -z "$taxonomies" ]]; then
        echo "{}"
        return
    fi

    # Split by comma and build JSON array
    IFS=',' read -ra taxonomy_array <<< "$taxonomies"

    # Build JSON array string
    local json_array="["
    local first=true
    for tax in "${taxonomy_array[@]}"; do
        tax=$(echo "$tax" | xargs)  # Trim whitespace
        if [[ -n "$tax" ]]; then
            if [[ "$first" == true ]]; then
                first=false
            else
                json_array+=", "
            fi
            json_array+="\"$tax\""
        fi
    done
    json_array+="]"

    # Build complete JSON string
    echo "{\"OR\": $json_array}"
}

# Build components
SEARCH_KEYWORD=$(build_search_keyword "$KEYWORDS")
TAXONOMY_EXPRESSION=$(build_taxonomy_expression "$TAXONOMIES")

# Output JSON
cat <<EOF
{
  "inputs": [{
    "searchKeyword": "$SEARCH_KEYWORD",
    "taxonomyExpression": "$TAXONOMY_EXPRESSION",
    "searchLanguage": "$LOCALE",
    "channelIds": "",
    "channelType": "PublicUnauthenticated",
    "contentTypeFqns": "sfdc_cms__image",
    "pageOffset": $PAGE_OFFSET,
    "pageLimit": $PAGE_LIMIT
  }]
}
EOF
