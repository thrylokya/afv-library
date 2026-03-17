#!/usr/bin/env python3
"""
Check MCP Content Server Availability and Tools

Returns JSON with availability status for each media source:
{
    "cms_search": true|false,
    "data_cloud": true|false,
    "unsplash": true|false
}

Invocation: Run with `python3 check_mcp.py` or, if Python is not available,
use the Bash equivalent `bash check_mcp.sh`. Both produce identical output.
"""

import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# Use only stdlib (no requests) so the script runs in minimal Vibes/CI environments

# Timeout for HTTP requests (seconds)
TIMEOUT = 5

# Relative path from IDE config root (Code/Cursor) to A4D MCP settings file
_A4D_MCP_SETTINGS_REL = Path('User/globalStorage/salesforce.salesforcedx-einstein-gpt/settings/a4d_mcp_settings.json')


def _get_ide_config_root():
    """
    Return the IDE (Code/VS Code) config root directory for this platform.
    Used to find globalStorage for the Salesforce Einstein GPT extension.
    """
    if sys.platform == 'win32':
        appdata = os.environ.get('APPDATA', '')
        if not appdata:
            appdata = Path.home() / 'AppData' / 'Roaming'
        return Path(appdata) / 'Code'
    if sys.platform == 'darwin':
        return Path.home() / 'Library' / 'Application Support' / 'Code'
    # Linux and other POSIX
    xdg = os.environ.get('XDG_CONFIG_HOME') or (Path.home() / '.config')
    return Path(xdg) / 'Code'


def get_a4d_mcp_settings_path():
    """Return the A4D MCP settings path for the current platform (Mac, Windows, Linux, etc.)."""
    return _get_ide_config_root() / _A4D_MCP_SETTINGS_REL


# Path to A4D MCP settings (platform-agnostic)
SETTINGS_PATH = get_a4d_mcp_settings_path()

# URL patterns that identify the content MCP endpoint (server name is irrelevant)
CONTENT_ENDPOINT_PATTERN = 'platform/content'
CONTENT_READONLY_PATTERN = 'content-readonly'

# Args pattern that identifies the Unsplash MCP server (server name is irrelevant)
UNSPLASH_MCP_ARGS_PATTERN = 'unsplash-mcp-server'


def _http_post_json(url, headers, payload, timeout=TIMEOUT):
    """
    POST JSON to url using stdlib only (no requests dependency).
    Returns (status_code, response_headers, response_data_dict or None).
    On failure returns (None, None, None).
    """
    data = json.dumps(payload).encode('utf-8')
    req_headers = {**headers, 'Content-Type': 'application/json'}
    req = Request(url, data=data, headers=req_headers, method='POST')
    try:
        with urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode('utf-8')
            result = json.loads(body) if body else None
            return (resp.status, resp.headers, result)
    except HTTPError as e:
        try:
            body = e.read().decode('utf-8')
            result = json.loads(body) if body else None
        except Exception:
            result = None
        return (e.code, e.headers, result)
    except (URLError, OSError, ValueError, json.JSONDecodeError):
        return (None, None, None)


def get_raw_settings():
    """
    Read and parse the full A4D MCP settings file.
    Returns the full settings dict or None if not found / invalid.
    """
    try:
        if not SETTINGS_PATH.exists():
            return None

        with open(SETTINGS_PATH, 'r') as f:
            return json.load(f)
    except Exception:
        return None


def get_mcp_settings():
    """
    Read and parse A4D MCP settings.
    Returns the mcpServers dict or None if not found.
    """
    settings = get_raw_settings()
    if not settings:
        return None
    return settings.get('mcpServers', {})


def _args_contain_content_endpoint(args):
    """True if args list contains the content MCP endpoint URL (any server name)."""
    if not args:
        return False
    for arg in args:
        if isinstance(arg, str) and (
            CONTENT_ENDPOINT_PATTERN in arg or CONTENT_READONLY_PATTERN in arg
        ):
            return True
    return False


def get_content_server_config():
    """
    Get the MCP server config that uses the content endpoint URL.
    Does not depend on server name; finds any server whose args contain
    the content endpoint (e.g. .../platform/content or .../content-readonly).
    Returns the config dict or empty dict if not found.
    """
    mcp_servers = get_mcp_settings()
    if not mcp_servers:
        return {}
    for config in mcp_servers.values():
        if not isinstance(config, dict):
            continue
        args = config.get('args', [])
        if _args_contain_content_endpoint(args):
            return config
    return {}


def get_contentmcp_url():
    """
    Extract MCP content server URL from settings.
    Returns the URL or None if not found, not configured, or stdio type.
    """
    content_config = get_content_server_config()
    if not content_config:
        return None

    if content_config.get('type') == 'stdio':
        return None

    args = content_config.get('args', [])
    for arg in args:
        if isinstance(arg, str) and (
            CONTENT_ENDPOINT_PATTERN in arg or CONTENT_READONLY_PATTERN in arg
        ):
            return arg

    return None


def is_contentmcp_enabled():
    """
    Check if content MCP server is enabled in settings.
    Returns True if enabled (disabled: false) AND not stdio type, False otherwise.

    Note: For stdio type servers, we cannot check availability via URL,
    so we return False to skip URL-based checks.
    """
    content_config = get_content_server_config()
    if not content_config:
        return False

    # Check if disabled field is explicitly false (enabled)
    disabled = content_config.get('disabled', False)
    if disabled:
        return False

    # If it's stdio type, we can't do URL-based availability checks
    # The MCP server is managed by the IDE/extension, not accessible via HTTP
    if content_config.get('type') == 'stdio':
        # For stdio, assume it's available if enabled
        # (The IDE manages the connection)
        return True

    # For non-stdio (like mcp-remote), we can check via URL
    return True


def _args_contain_unsplash_mcp(args):
    """True if args list contains the unsplash MCP server (any server name)."""
    if not args:
        return False
    for arg in args:
        if isinstance(arg, str) and UNSPLASH_MCP_ARGS_PATTERN in arg:
            return True
    return False


def get_unsplash_server_config():
    """
    Get the Unsplash MCP server config from settings.
    Checks (1) root-level "unsplash" key and (2) any server in mcpServers
    whose args contain "unsplash-mcp-server" (name-agnostic).
    Returns the config dict or empty dict if not found.
    """
    settings = get_raw_settings()
    if not settings:
        return {}

    # Root-level "unsplash" (some configs put it here)
    root_unsplash = settings.get('unsplash')
    if isinstance(root_unsplash, dict) and root_unsplash:
        return root_unsplash

    # Any server in mcpServers that runs unsplash-mcp-server
    mcp_servers = settings.get('mcpServers', {})
    for config in mcp_servers.values() if mcp_servers else ():
        if isinstance(config, dict) and _args_contain_unsplash_mcp(config.get('args', [])):
            return config

    return {}


def is_unsplash_mcp_enabled():
    """
    Check if Unsplash MCP server is configured and enabled.
    Returns True if configured and enabled, False otherwise.
    """
    unsplash_config = get_unsplash_server_config()
    if not unsplash_config:
        return False

    disabled = unsplash_config.get('disabled', False)
    return not disabled


def get_bearer_token():
    """
    Extract bearer token from A4D MCP settings.
    Returns the token string or None if not found.
    """
    content_config = get_content_server_config()
    if not content_config:
        return None

    # Extract Authorization header from args
    args = content_config.get('args', [])
    for i, arg in enumerate(args):
        if arg == '--header' and i + 1 < len(args):
            auth_header = args[i + 1]
            # Format: "Authorization: Bearer <token>"
            if auth_header.startswith('Authorization: Bearer '):
                return auth_header.replace('Authorization: Bearer ', '')

    return None


def get_base_headers():
    """Get base headers for MCP requests (without session ID)."""
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream'
    }
    token = get_bearer_token()
    if token:
        headers['Authorization'] = f'Bearer {token}'
    return headers


def initialize_mcp_session(endpoint_url):
    """
    Initialize MCP session and get session ID.
    Args:
        endpoint_url: The MCP server endpoint URL
    Returns session ID or None if initialization fails.
    """
    headers = get_base_headers()

    # Step 1: Initialize
    payload = {
        "jsonrpc": "2.0",
        "method": "initialize",
        "id": "0",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "CheckMCPScript", "version": "1.0.0"}
        }
    }

    try:
        status, resp_headers, data = _http_post_json(endpoint_url, headers, payload, TIMEOUT)
        if status == 200 and data is not None:
            # Try to get from Mcp-Session-Id header
            session_id = resp_headers.get('Mcp-Session-Id') if resp_headers else None
            if session_id:
                return session_id

            # Try to get from response body
            if 'result' in data and isinstance(data['result'], dict):
                session_id = data['result'].get('sessionId') or data['result'].get('session_id')
                if session_id:
                    return session_id
    except Exception:
        pass

    return None


def send_initialized_notification(endpoint_url, session_id):
    """
    Send initialized notification to MCP server.
    Args:
        endpoint_url: The MCP server endpoint URL
        session_id: The session ID from initialization
    Returns True if successful, False otherwise.
    """
    headers = get_base_headers()
    headers['Mcp-Session-Id'] = session_id

    payload = {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    }

    try:
        status, _, _ = _http_post_json(endpoint_url, headers, payload, TIMEOUT)
        return status in [200, 202]  # Accept both 200 and 202
    except Exception:
        return False


def list_available_tools():
    """
    List all available tools from MCP server using JSON-RPC.
    Follows proper MCP initialization flow.
    Returns a list of tool names, or empty list if unavailable.
    """
    # Get the endpoint URL
    endpoint_url = get_contentmcp_url()
    if not endpoint_url:
        # stdio type or no URL configured
        return []

    # Step 1: Initialize and get session ID
    session_id = initialize_mcp_session(endpoint_url)
    if not session_id:
        return []

    # Step 2: Send initialized notification
    if not send_initialized_notification(endpoint_url, session_id):
        return []

    # Step 3: List tools
    headers = get_base_headers()
    headers['Mcp-Session-Id'] = session_id

    payload = {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": "1",
        "params": {}
    }

    try:
        status, _, data = _http_post_json(endpoint_url, headers, payload, TIMEOUT)
        if status == 200 and data and 'result' in data and 'tools' in data['result']:
            tools = data['result']['tools']
            tool_names = [tool.get('name') for tool in tools if isinstance(tool, dict) and 'name' in tool]
            return tool_names
    except Exception:
        pass

    return []


def check_mcp_health():
    """Check if MCP server is reachable by attempting to list tools."""
    tools = list_available_tools()
    return len(tools) > 0


def check_tool_available(tool_name):
    """
    Check if a specific tool is available via MCP server.
    Uses JSON-RPC to list tools and searches for the tool name.
    """
    available_tools = list_available_tools()
    return tool_name in available_tools


def main():
    """Main execution."""
    result = {
        "cms_search": False,
        "data_cloud": False,
        "unsplash": False
    }

    # First check if contentmcp server is enabled in settings
    if not is_contentmcp_enabled():
        # contentmcp is disabled, return all false
        print(json.dumps(result))
        return 0

    # Check if it's stdio type
    content_config = get_content_server_config()

    if content_config.get('type') == 'stdio':
        # For stdio type, we can't check via URL
        # Assume tools are available if the server is enabled
        # The IDE/extension manages the connection
        result["cms_search"] = True
        result["data_cloud"] = True
    else:
        # For non-stdio (like mcp-remote), check via URL
        if check_mcp_health():
            # Check for CMS search tool
            if check_tool_available("search_media_cms_channels"):
                result["cms_search"] = True

            # Check for Data Cloud search tool
            if check_tool_available("search_electronic_media"):
                result["data_cloud"] = True

    # Check for Unsplash MCP server separately
    if is_unsplash_mcp_enabled():
        result["unsplash"] = True

    # Output JSON result
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
