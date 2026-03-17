#!/usr/bin/env python3
"""
Build CMS Search Input JSON

Generates properly formatted input JSON for search_media_cms_channels MCP tool.

Usage:
  python3 build_cms_search_input.py --keywords "car,automobile,vehicle" --taxonomies "Modern,Luxury" --locale "en_US"

  # With empty keywords
  python3 build_cms_search_input.py --keywords "" --taxonomies "Bright,Spacious" --locale "en_US"

  # With empty taxonomies
  python3 build_cms_search_input.py --keywords "logo,brand" --taxonomies "" --locale "en_US"

  # With page parameters
  python3 build_cms_search_input.py --keywords "car" --taxonomies "Luxury" --locale "en_US" --limit 10 --offset 0
"""

import argparse
import json
import sys


def build_search_keyword(keywords):
    """
    Convert comma-separated keywords to OR-separated format.

    Args:
        keywords: Comma-separated string of keywords, or empty string

    Returns:
        OR-separated keyword string, or empty string

    Examples:
        "car,automobile,vehicle" -> "car OR automobile OR vehicle"
        "" -> ""
        "logo" -> "logo"
    """
    if not keywords or keywords.strip() == "":
        return ""

    # Split by comma, strip whitespace, filter empty
    keyword_list = [k.strip() for k in keywords.split(',') if k.strip()]

    if not keyword_list:
        return ""

    # Join with OR
    return " OR ".join(keyword_list)


def build_taxonomy_expression(taxonomies):
    """
    Convert comma-separated taxonomies to JSON string format.

    Args:
        taxonomies: Comma-separated string of taxonomy labels, or empty string

    Returns:
        JSON string in format: {"OR": ["Label1", "Label2", "Label3"]}, or "{}"

    Examples:
        "Modern,Luxury,Premium" -> "{\"OR\": [\"Modern\", \"Luxury\", \"Premium\"]}"
        "" -> "{}"
        "Bright" -> "{\"OR\": [\"Bright\"]}"
    """
    if not taxonomies or taxonomies.strip() == "":
        return "{}"

    # Split by comma, strip whitespace, filter empty
    taxonomy_list = [t.strip() for t in taxonomies.split(',') if t.strip()]

    if not taxonomy_list:
        return "{}"

    # Build JSON object and convert to string
    taxonomy_obj = {"OR": taxonomy_list}
    return json.dumps(taxonomy_obj)


def build_cms_search_input(keywords, taxonomies, locale="en_US", page_offset=0, page_limit=5):
    """
    Build the complete input JSON for search_media_cms_channels.

    Args:
        keywords: Comma-separated string of keywords
        taxonomies: Comma-separated string of taxonomy labels
        locale: Language locale (e.g., "en_US", "es_MX", "fr_CA")
        page_offset: Starting offset for pagination (default: 0)
        page_limit: Number of results to return (default: 5)

    Returns:
        Dictionary with properly formatted input
    """
    return {
        "inputs": [{
            "searchKeyword": build_search_keyword(keywords),
            "taxonomyExpression": build_taxonomy_expression(taxonomies),
            "searchLanguage": locale,
            "channelIds": "",
            "channelType": "PublicUnauthenticated",
            "contentTypeFqns": "sfdc_cms__image",
            "pageOffset": page_offset,
            "pageLimit": page_limit
        }]
    }


def main():
    parser = argparse.ArgumentParser(
        description='Build properly formatted input JSON for CMS image search',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic search
  python3 build_cms_search_input.py --keywords "car,automobile,vehicle" --taxonomies "Modern,Luxury" --locale "en_US"

  # Search with only taxonomies (no keywords)
  python3 build_cms_search_input.py --keywords "" --taxonomies "Bright,Spacious,Airy" --locale "en_US"

  # Search with only keywords (no taxonomies)
  python3 build_cms_search_input.py --keywords "logo,brand,corporate" --taxonomies "" --locale "en_US"

  # With custom page limit
  python3 build_cms_search_input.py --keywords "apartment" --taxonomies "Luxury" --locale "en_US" --limit 20
        """
    )

    parser.add_argument(
        '--keywords',
        required=True,
        help='Comma-separated keywords (e.g., "car,automobile,vehicle"). Use empty string "" for no keywords.'
    )

    parser.add_argument(
        '--taxonomies',
        required=True,
        help='Comma-separated taxonomy labels (e.g., "Modern,Luxury,Premium"). Use empty string "" for no taxonomies.'
    )

    parser.add_argument(
        '--locale',
        default='en_US',
        help='Language locale (e.g., "en_US", "es_MX", "fr_CA"). Default: "en_US"'
    )

    parser.add_argument(
        '--offset',
        type=int,
        default=0,
        help='Page offset for pagination. Default: 0'
    )

    parser.add_argument(
        '--limit',
        type=int,
        default=5,
        help='Number of results to return. Default: 5'
    )

    args = parser.parse_args()

    # Build the input
    input_json = build_cms_search_input(
        keywords=args.keywords,
        taxonomies=args.taxonomies,
        locale=args.locale,
        page_offset=args.offset,
        page_limit=args.limit
    )

    # Output JSON
    print(json.dumps(input_json, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
