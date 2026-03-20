---
name: searching-media
description: Use when the user wants to FIND, SEARCH, or RETRIEVE images, photos, pictures, media, visuals, graphics, icons, illustrations, banners, thumbnails, logos, hero images, backgrounds, cover images, feature images, stock photos, product images, or visual assets from available sources. Trigger on requests to search, find, get, fetch, retrieve, browse, look up, locate, or add existing media. This is a ROUTING skill — it discovers which search sources are available (Salesforce CMS, Data Cloud, Unsplash) and lets the user choose. Use even if the user describes needing a visual without explicitly saying "search" (e.g., "I need an image for the header", "get me a background for the hero section"). DO NOT trigger for requests to GENERATE, CREATE, MAKE, DESIGN, or BUILD new images — those require different tools.
metadata:
  author: afv-library
  version: "1.0"
---

# Media Search

Universal routing skill for searching and retrieving existing images and media.

## Scope

**This skill is for FINDING existing media, not CREATING new media.**

**Use this skill when the user wants to:**
- Search for images in Salesforce CMS, Data Cloud, or Unsplash
- Find existing visual assets
- Retrieve media from connected sources
- Browse available images
- Locate specific photos or graphics

**DO NOT use this skill when the user wants to:**
- Generate new images with AI (use image generation tools)
- Create graphics or designs from scratch
- Edit or modify existing images
- Build custom visuals or diagrams

## Before You Search

**This is a routing skill, not a direct search skill.** When a user requests to find an image, do NOT immediately call a search tool. Instead:

1. Check which search tools (MCP tools) you have access to
2. Present the available search sources as numbered options
3. Wait for the user to select one
4. Then execute the selected search method

**Never auto-select a search source.** The user must choose from the available options. Similarly, when presenting search results, **never auto-select an image** — let the user choose.

## Workflow Overview

1. Identify which search sources (MCP tools) are available
2. Present those options to the user
3. Wait for user selection
4. Execute the selected search method
5. Return results for the user to choose from

## Discovering Available Search Sources

Before presenting options, check which MCP tools you have access to and map them to search sources:

| MCP Tool Name | Search Source | Search Type |
|---|---|---|
| `search_media_cms_channels` | Search using keywords | Keyword + taxonomy search in Salesforce CMS |
| `search_electronic_media` | Search using Data 360 hybrid search | Semantic/AI search across CMS + 3rd-party DAMs |
| Any Unsplash tool | Unsplash | Free stock photos |

**Your first response** should identify which sources are available and present numbered options to the user. Do not call any search tools yet — just present the options and wait for the user to choose.

### Example First Response

```
I'll help you find that image. Let me check which search sources are available.

Available search sources:
1. Search using Data 360 hybrid search — Semantic search across Salesforce CMS and connected DAMs
2. Search using keywords — Search Salesforce CMS by keywords and taxonomies
3. Other — Provide your own URL or path

Which option would you like to use?
```

If no automated search tools are available:
```
No automated media sources are currently configured. Please provide a direct URL or asset library path.
```

**Example (all sources available):**
```
I can help you find that image. Where would you like to search?

1. **Search using Data 360 hybrid search** — Semantic search across Salesforce CMS and connected DAMs
2. **Search using keywords** — Search Salesforce CMS by keywords and taxonomies
3. **Unsplash** — Free stock photos
4. **Other** — Provide your own URL or path
```

**Example (only keyword search available):**
```
I can help you find that image. Where would you like to search?

1. **Search using keywords** — Search Salesforce CMS by keywords and taxonomies
2. **Other** — Provide your own URL or path
```

**Example (no automated sources):**
```
No automated media sources are currently configured. Please provide:
1. **Direct URL or asset library path**
```

**Wait for the user to select** before proceeding.

## Executing the Selected Search Method

After the user selects an option, execute the corresponding search method below.

### Search using keywords

**Tool:** `search_media_cms_channels`

**Process:**

1. **Analyze the query** — Understand what the user is searching for (subject, attributes, domain)

2. **Extract keywords** — Concrete nouns that would appear in image metadata
   - Use domain-specific synonyms
   - Maximum 10 terms
   - Examples:
     - "luxury apartments" → apartment, villa, penthouse, residence, condo
     - "company logo" → logo, brand, emblem, corporate logo
     - "bright room" → _(empty if no concrete nouns)_

3. **Extract taxonomies** — Descriptive qualities, styles, moods, categories
   - Only adjectives and attributes
   - Examples:
     - "luxury apartment with river view" → Luxury, Premium, Waterfront, Riverside, Panoramic
     - "bright spacious room" → Bright, Spacious, Open, Airy, Light
     - "car" → _(empty if no descriptive terms)_

4. **Determine locale** — Use format `en_US`, `es_MX`, `fr_FR` (default: `en_US`)

5. **Build the JSON payload** — Construct this exact structure:

```json
{
  "inputs": [{
    "searchKeyword": "keyword1 OR keyword2 OR keyword3",
    "taxonomyExpression": "{\"OR\": [\"Taxonomy1\", \"Taxonomy2\"]}",
    "searchLanguage": "en_US",
    "channelIds": "",
    "channelType": "PublicUnauthenticated",
    "contentTypeFqns": "sfdc_cms__image",
    "pageOffset": 0,
    "searchLimit": 5
  }]
}
```

**Field rules:**
- `searchKeyword`: Join keywords with ` OR ` (space-OR-space). Use empty string if no keywords.
- `taxonomyExpression`: Stringify JSON object `{"OR": ["term1", "term2"]}`. Use `"{}"` if no taxonomies.
- `searchLanguage`: Locale with underscore (e.g., `en_US`)
- `channelIds`: Always empty string
- `channelType`: Always `"PublicUnauthenticated"`
- `contentTypeFqns`: Always `"sfdc_cms__image"`
- `pageOffset`: Start at `0`, increment by `searchLimit` for pagination
- `searchLimit`: Default `5`, adjust if user requests more

**Examples:**

Query: "luxury apartment with river view"
```json
{
  "inputs": [{
    "searchKeyword": "apartment OR villa OR penthouse OR residence",
    "taxonomyExpression": "{\"OR\": [\"Luxury\", \"Premium\", \"Waterfront\", \"Riverside\"]}",
    "searchLanguage": "en_US",
    "channelIds": "",
    "channelType": "PublicUnauthenticated",
    "contentTypeFqns": "sfdc_cms__image",
    "pageOffset": 0,
    "searchLimit": 5
  }]
}
```

Query: "bright spacious room" (no concrete nouns)
```json
{
  "inputs": [{
    "searchKeyword": "",
    "taxonomyExpression": "{\"OR\": [\"Bright\", \"Spacious\", \"Open\", \"Airy\"]}",
    "searchLanguage": "en_US",
    "channelIds": "",
    "channelType": "PublicUnauthenticated",
    "contentTypeFqns": "sfdc_cms__image",
    "pageOffset": 0,
    "searchLimit": 5
  }]
}
```

Query: "car images" (no descriptive terms)
```json
{
  "inputs": [{
    "searchKeyword": "car OR automobile OR vehicle OR auto",
    "taxonomyExpression": "{}",
    "searchLanguage": "en_US",
    "channelIds": "",
    "channelType": "PublicUnauthenticated",
    "contentTypeFqns": "sfdc_cms__image",
    "pageOffset": 0,
    "searchLimit": 5
  }]
}
```

6. **Call the tool** with the exact JSON payload

### Search using Data 360 hybrid search

**Tool:** `search_electronic_media`

**Process:**

1. Use the user's query **as-is** — no keyword extraction or transformation needed
2. Call `search_electronic_media`
3. Pass the query to the tool's search parameter (check the tool's schema for the exact parameter name - likely `query` or `search_query`)

**Example:**
- User query: "modern luxury apartment with natural lighting"
- Tool call: `search_electronic_media(query="modern luxury apartment with natural lighting")`
  (Note: Check the tool's schema - parameter might be `query` or `search_query`)

### Unsplash

**Process:**

1. Extract simple, descriptive keywords from the user's query
2. Call the Unsplash MCP tool with the search query
3. Include photographer attribution in results

### Other (User-Provided URL)

Ask the user to provide:
- Direct URL to the image
- Asset library path
- Specific system/location to check

## Presenting Search Results

Parse the tool response and present **ALL** results as numbered options:

```
I found 4 images. Which one would you like to use?

1. **Luxury Apartment Exterior**
   URL: https://cms.example.com/media/luxury-apt-01.jpg
   Source: Salesforce CMS

2. **Modern High-Rise Building**
   URL: https://cms.example.com/media/highrise-02.jpg
   Source: Salesforce CMS

3. **Waterfront Residence**
   URL: https://cms.example.com/media/waterfront-03.jpg
   Source: Salesforce CMS

4. **Premium Condominium**
   URL: https://cms.example.com/media/condo-04.jpg
   Source: Salesforce CMS
```

**Never auto-select an image.** Always wait for user choice.

## Applying the Selected Image

After the user chooses:

1. **Confirm** the selection with image name and URL
2. **Apply** the URL to the user's code/component
3. **Show** what was changed (file path and line number)
4. **Offer** next steps:
   - Add alt text for accessibility
   - Adjust styling or dimensions
   - Find additional images
   - Optimize image loading

## Error Handling

| Error | Response |
|---|---|
| Tool unavailable | "The [source name] tool is unavailable. Would you like to try a different source?" |
| Tool returns error | Show error message, offer retry with different terms or alternative source |
| No results found | "No results found. Try broader keywords, removing descriptive terms, or a different source." |
| Invalid user selection | Re-display options and ask again |

**Never silently fail.** Always inform the user and offer alternatives.

## Search Behavior Notes

**Search using keywords:**
- Both keyword and taxonomy → results match keyword OR (keyword + taxonomy)
- Empty keyword → search by taxonomy only
- Empty taxonomy → search by keyword only
- Use `pageOffset` for pagination (increment by `searchLimit`)

**Search using Data 360 hybrid search:**
- Handles natural language queries
- Semantic similarity matching
- Searches across multiple connected systems

**Unsplash:**
- Free to use under Unsplash License
- Always include photographer credit
- Note license terms when presenting results

## Key Principles

1. **Always discover sources first** — Never assume a tool exists
2. **Present only available options** — Don't show unavailable sources
3. **Wait for user selection** — Never auto-select a source or image
4. **Show all results** — Let the user choose the best match
5. **Confirm before applying** — Verify the selection before modifying code
6. **Handle errors gracefully** — Provide clear feedback and alternatives
