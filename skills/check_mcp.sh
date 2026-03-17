#!/bin/bash

# Check MCP Content Server Availability and Tools
#
# Returns JSON with availability status for each media source:
# {
#   "cms_search": true|false,
#   "data_cloud": true|false,
#   "unsplash": true|false
# }

set -e

TIMEOUT=5

# URL patterns that identify the content MCP endpoint (name-agnostic)
CONTENT_ENDPOINT_PATTERN="platform/content"
CONTENT_READONLY_PATTERN="content-readonly"

# Args pattern that identifies the Unsplash MCP server (name-agnostic)
UNSPLASH_MCP_ARGS_PATTERN="unsplash-mcp-server"


# ---------------------------------------------------------------------------
# Platform detection and settings path
# ---------------------------------------------------------------------------
get_ide_config_root() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        local appdata="${APPDATA:-$HOME/AppData/Roaming}"
        echo "$appdata/Code"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$HOME/Library/Application Support/Code"
    else
        local xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
        echo "$xdg/Code"
    fi
}

SETTINGS_PATH="$(get_ide_config_root)/User/globalStorage/salesforce.salesforcedx-einstein-gpt/settings/a4d_mcp_settings.json"

# ---------------------------------------------------------------------------
# JSON helpers — jq preferred, grep/sed fallback
# ---------------------------------------------------------------------------

_has_jq() { command -v jq &> /dev/null; }

# Get the full raw settings as a string (only useful with jq)
_settings_exists() { [[ -f "$SETTINGS_PATH" ]]; }

# ---------------------------------------------------------------------------
# Name-agnostic content server detection
# Scans ALL mcpServers entries for args containing CONTENT_ENDPOINT_PATTERN
# or CONTENT_READONLY_PATTERN. Returns the server key (name) or empty.
# ---------------------------------------------------------------------------
get_content_server_key() {
    if ! _settings_exists; then echo ""; return; fi

    if _has_jq; then
        local key
        key=$(jq -r '
            .mcpServers // {} | to_entries[] |
            select(.value.args? // [] | map(select(type == "string")) |
                any(contains("'"$CONTENT_ENDPOINT_PATTERN"'") or contains("'"$CONTENT_READONLY_PATTERN"'")))
            | .key' "$SETTINGS_PATH" 2>/dev/null | head -n 1)
        echo "$key"
    else
        # grep fallback: look for any args line containing the patterns
        local key
        key=$(grep -B 20 "$CONTENT_ENDPOINT_PATTERN\|$CONTENT_READONLY_PATTERN" "$SETTINGS_PATH" 2>/dev/null \
            | grep -o '"[^"]*": *{' | tail -n 1 | sed 's/[": {]//g')
        echo "$key"
    fi
}

# ---------------------------------------------------------------------------
# Content server config queries (all name-agnostic via get_content_server_key)
# ---------------------------------------------------------------------------
is_content_server_disabled() {
    local key
    key=$(get_content_server_key)
    [[ -z "$key" ]] && return 0  # no server found → treat as disabled

    if _has_jq; then
        local disabled
        disabled=$(jq -r ".mcpServers[\"$key\"].disabled // false" "$SETTINGS_PATH" 2>/dev/null)
        [[ "$disabled" == "true" ]] && return 0
        return 1
    else
        if grep -A 5 "\"$key\"" "$SETTINGS_PATH" 2>/dev/null | grep -q '"disabled": *true'; then
            return 0
        fi
        return 1
    fi
}

is_contentmcp_enabled() {
    if ! _settings_exists; then return 1; fi

    local key
    key=$(get_content_server_key)
    [[ -z "$key" ]] && return 1

    if is_content_server_disabled; then return 1; fi
    return 0
}

is_stdio_type() {
    if ! _settings_exists; then return 1; fi

    local key
    key=$(get_content_server_key)
    [[ -z "$key" ]] && return 1

    if _has_jq; then
        local stype
        stype=$(jq -r ".mcpServers[\"$key\"].type // empty" "$SETTINGS_PATH" 2>/dev/null)
        [[ "$stype" == "stdio" ]] && return 0
    else
        if grep -A 10 "\"$key\"" "$SETTINGS_PATH" 2>/dev/null | grep -q '"type": *"stdio"'; then
            return 0
        fi
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Extract the MCP content endpoint URL from settings args (name-agnostic).
# Returns empty if not found — no localhost or env var fallback.
# ---------------------------------------------------------------------------
get_contentmcp_url() {
    local key
    key=$(get_content_server_key)
    [[ -z "$key" ]] && { echo ""; return; }

    if _has_jq; then
        local url
        url=$(jq -r "
            .mcpServers[\"$key\"].args // [] | map(select(type == \"string\")) |
            map(select(contains(\"$CONTENT_ENDPOINT_PATTERN\") or contains(\"$CONTENT_READONLY_PATTERN\")))
            | .[0] // empty" "$SETTINGS_PATH" 2>/dev/null)
        if [[ -n "$url" ]]; then echo "$url"; return; fi
    else
        local url
        url=$(grep -o 'http[s]*://[^"]*' "$SETTINGS_PATH" 2>/dev/null \
            | grep -E "$CONTENT_ENDPOINT_PATTERN|$CONTENT_READONLY_PATTERN" | head -n 1)
        if [[ -n "$url" ]]; then echo "$url"; return; fi
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# Name-agnostic Unsplash detection.
# Checks (1) root-level "unsplash" key and (2) any mcpServers entry whose
# args contain "unsplash-mcp-server".
# ---------------------------------------------------------------------------
get_unsplash_server_key() {
    if ! _settings_exists; then echo ""; return; fi

    if _has_jq; then
        # Check root-level "unsplash" key first
        local root_unsplash
        root_unsplash=$(jq -r '.unsplash // empty' "$SETTINGS_PATH" 2>/dev/null)
        if [[ -n "$root_unsplash" && "$root_unsplash" != "null" ]]; then
            echo "__root__"
            return
        fi

        # Scan mcpServers for any server with unsplash-mcp-server in args
        local key
        key=$(jq -r '
            .mcpServers // {} | to_entries[] |
            select(.value.args? // [] | map(select(type == "string")) |
                any(contains("'"$UNSPLASH_MCP_ARGS_PATTERN"'")))
            | .key' "$SETTINGS_PATH" 2>/dev/null | head -n 1)
        echo "$key"
    else
        # grep fallback: check root "unsplash" or args containing the pattern
        if grep -q "\"unsplash\"" "$SETTINGS_PATH" 2>/dev/null; then
            echo "unsplash"
            return
        fi
        if grep -q "$UNSPLASH_MCP_ARGS_PATTERN" "$SETTINGS_PATH" 2>/dev/null; then
            local key
            key=$(grep -B 20 "$UNSPLASH_MCP_ARGS_PATTERN" "$SETTINGS_PATH" 2>/dev/null \
                | grep -o '"[^"]*": *{' | tail -n 1 | sed 's/[": {]//g')
            echo "$key"
        fi
    fi
}

is_unsplash_mcp_enabled() {
    if ! _settings_exists; then return 1; fi

    local key
    key=$(get_unsplash_server_key)
    [[ -z "$key" ]] && return 1

    if [[ "$key" == "__root__" ]]; then
        # Root-level unsplash: check disabled
        if _has_jq; then
            local disabled
            disabled=$(jq -r '.unsplash.disabled // false' "$SETTINGS_PATH" 2>/dev/null)
            [[ "$disabled" == "true" ]] && return 1
        fi
        return 0
    fi

    # mcpServers entry
    if _has_jq; then
        local disabled
        disabled=$(jq -r ".mcpServers[\"$key\"].disabled // false" "$SETTINGS_PATH" 2>/dev/null)
        [[ "$disabled" == "true" ]] && return 1
        return 0
    else
        if grep -A 5 "\"$key\"" "$SETTINGS_PATH" 2>/dev/null | grep -q '"disabled": *true'; then
            return 1
        fi
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Bearer token extraction (name-agnostic: from the matched content server)
# Looks for --header arg followed by "Authorization: Bearer <token>".
# ---------------------------------------------------------------------------
get_bearer_token() {
    if ! _settings_exists; then echo ""; return; fi

    local key
    key=$(get_content_server_key)
    [[ -z "$key" ]] && { echo ""; return; }

    if _has_jq; then
        # Find the arg after "--header" that starts with "Authorization: Bearer "
        local token
        token=$(jq -r "
            .mcpServers[\"$key\"].args // [] | to_entries |
            map(select(.value == \"--header\")) |
            .[0].key as \$idx |
            if \$idx then
                .mcpServers[\"$key\"].args[\$idx + 1] // empty
            else empty end
        " "$SETTINGS_PATH" 2>/dev/null)

        # jq path above is tricky; simpler approach: iterate pairs
        token=$(jq -r "
            [.mcpServers[\"$key\"].args // []] | .[0] | . as \$args |
            [range(0; length - 1)] |
            map(select(\$args[.] == \"--header\" and (\$args[. + 1] | startswith(\"Authorization: Bearer \")))) |
            .[0] as \$i |
            if \$i then \$args[\$i + 1] | sub(\"Authorization: Bearer \"; \"\") else empty end
        " "$SETTINGS_PATH" 2>/dev/null)
        echo "$token"
    else
        local token
        token=$(grep -o 'Authorization: Bearer [^"]*' "$SETTINGS_PATH" 2>/dev/null \
            | sed 's/Authorization: Bearer //' | head -n 1)
        echo "$token"
    fi
}

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
MCP_ENDPOINT=""
BEARER_TOKEN=""

_curl_post() {
    local url="$1"
    local payload="$2"
    local include_headers="${3:-false}"

    local -a curl_args=(-s -m "$TIMEOUT")

    if [[ "$include_headers" == "true" ]]; then
        curl_args+=(-i)
    fi

    if [[ -n "$BEARER_TOKEN" ]]; then
        curl_args+=(-H "Authorization: Bearer $BEARER_TOKEN")
    fi
    curl_args+=(-H "Content-Type: application/json")
    curl_args+=(-H "Accept: application/json, text/event-stream")

    if [[ -n "${SESSION_ID:-}" ]]; then
        curl_args+=(-H "Mcp-Session-Id: $SESSION_ID")
    fi

    curl_args+=(-X POST -d "$payload" "$url")
    curl "${curl_args[@]}" 2>/dev/null
}

_curl_post_status() {
    local url="$1"
    local payload="$2"

    local -a curl_args=(-s -o /dev/null -w "%{http_code}" -m "$TIMEOUT")

    if [[ -n "$BEARER_TOKEN" ]]; then
        curl_args+=(-H "Authorization: Bearer $BEARER_TOKEN")
    fi
    curl_args+=(-H "Content-Type: application/json")
    curl_args+=(-H "Accept: application/json, text/event-stream")

    if [[ -n "${SESSION_ID:-}" ]]; then
        curl_args+=(-H "Mcp-Session-Id: $SESSION_ID")
    fi

    curl_args+=(-X POST -d "$payload" "$url")
    curl "${curl_args[@]}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# MCP JSON-RPC session flow
# ---------------------------------------------------------------------------
SESSION_ID=""

initialize_mcp_session() {
    if ! command -v curl &> /dev/null; then echo ""; return 1; fi

    local payload='{"jsonrpc":"2.0","method":"initialize","id":"0","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"CheckMCPScript","version":"1.0.0"}}}'

    local response
    response=$(_curl_post "$MCP_ENDPOINT" "$payload" "true")

    # Try Mcp-Session-Id from response headers
    local sid
    sid=$(echo "$response" | grep -i "^Mcp-Session-Id:" | sed 's/^[^:]*: *//' | tr -d '\r\n ')
    if [[ -n "$sid" ]]; then echo "$sid"; return 0; fi

    # Try from response body: result.sessionId or result.session_id
    local body
    body=$(echo "$response" | sed -n '/^\r*$/,$p' | tail -n +2)
    if [[ -n "$body" ]] && _has_jq; then
        sid=$(echo "$body" | jq -r '.result.sessionId // .result.session_id // empty' 2>/dev/null)
        if [[ -n "$sid" ]]; then echo "$sid"; return 0; fi
    elif [[ -n "$body" ]]; then
        sid=$(echo "$body" | grep -o '"sessionId":"[^"]*"' | sed 's/"sessionId":"//;s/"//' | head -n 1)
        if [[ -z "$sid" ]]; then
            sid=$(echo "$body" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//' | head -n 1)
        fi
        if [[ -n "$sid" ]]; then echo "$sid"; return 0; fi
    fi

    echo ""
    return 1
}

send_initialized_notification() {
    local sid="$1"
    if ! command -v curl &> /dev/null; then return 1; fi

    SESSION_ID="$sid"
    local payload='{"jsonrpc":"2.0","method":"notifications/initialized"}'

    local status_code
    status_code=$(_curl_post_status "$MCP_ENDPOINT" "$payload")

    # Accept both 200 and 202 (matching Python)
    if [[ "$status_code" == "200" || "$status_code" == "202" ]]; then
        return 0
    fi
    return 1
}

list_available_tools() {
    if ! command -v curl &> /dev/null; then echo ""; return 1; fi

    local sid
    sid=$(initialize_mcp_session)
    if [[ -z "$sid" ]]; then echo ""; return 1; fi

    if ! send_initialized_notification "$sid"; then echo ""; return 1; fi

    SESSION_ID="$sid"
    local payload='{"jsonrpc":"2.0","method":"tools/list","id":"1","params":{}}'

    local response
    response=$(_curl_post "$MCP_ENDPOINT" "$payload")

    if [[ -n "$response" ]]; then
        echo "$response"
        return 0
    fi
    echo ""
    return 1
}

check_mcp_health() {
    local response
    response=$(list_available_tools)
    if [[ -n "$response" ]] && echo "$response" | grep -q '"tools"'; then
        return 0
    fi
    return 1
}

check_tool_available() {
    local tool_name="$1"
    local tools_response
    tools_response=$(list_available_tools)

    if [[ -n "$tools_response" ]]; then
        if echo "$tools_response" | grep -q "\"name\": *\"$tool_name\""; then
            return 0
        fi
        if echo "$tools_response" | grep -q "\"name\":\"$tool_name\""; then
            return 0
        fi
    fi
    return 1
}

# ===========================================================================
# Main
# ===========================================================================
cms_search=false
data_cloud=false
unsplash=false

if ! is_contentmcp_enabled; then
    echo '{"cms_search": false, "data_cloud": false, "unsplash": false}'
    exit 0
fi

if is_stdio_type; then
    cms_search=true
    data_cloud=true
else
    MCP_ENDPOINT=$(get_contentmcp_url)
    BEARER_TOKEN=$(get_bearer_token)

    if check_mcp_health; then
        if check_tool_available "search_media_cms_channels"; then
            cms_search=true
        fi
        if check_tool_available "search_electronic_media"; then
            data_cloud=true
        fi
    fi
fi

if is_unsplash_mcp_enabled; then
    unsplash=true
fi

echo "{\"cms_search\": $cms_search, \"data_cloud\": $data_cloud, \"unsplash\": $unsplash}"
