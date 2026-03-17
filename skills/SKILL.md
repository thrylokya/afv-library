---
name: cms-media-options
description: REQUIRED entry point for ALL media and image searches. Every request to find, search, locate, retrieve, browse, get, look up, or use images, photos, pictures, media, icons, illustrations, hero images, banners, thumbnails, logos MUST go through this skill first. Checks which search sources are available, presents only those options, and delegates to the appropriate search skill based on the user's choice. Never search for media directly — always start here.
license: Apache-2.0
compatibility: Python 3.x or Python 2.7+ recommended, bash 3.2+ (Git Bash/WSL on Windows). Cross-platform: Mac, Windows (Git Bash/WSL), Linux, POSIX.
metadata:
  author: afv-library
  version: "1.0"
---

# CMS Media Search — Source Selection

**This is the mandatory entry point for ALL media searches.** When the user asks to **find**, **search for**, **locate**, **retrieve**, **browse**, **get**, **look up**, or **use** any kind of visual content — **always start here**. Do not assume a source or call a search tool directly. Check what is available, present only those options, and delegate to the matching search skill.

## When to Use This Skill

Activate whenever the user's request involves any visual content, including but not limited to:

- Images, photos, pictures, media, visuals, graphics
- Icons, illustrations, banners, thumbnails, logos
- Hero images, background images, feature images, cover images
- Any asset described as visual (e.g. "something for the carousel", "a picture for the header")

Example triggers:

- "Find a modern luxury apartment exterior and use it in the hero section"
- "I need a hero image for the landing page"
- "Search for family lifestyle photos for the carousel"
- "Get me a logo for the about page"
- "Look up some banner graphics"
- "Can you find product images?"

---

## Step 1: Check Source Availability

**Before presenting any options**, run the MCP availability check script:

```bash
python3 scripts/check_mcp.py
```

Or if Python is not available:

```bash
bash scripts/check_mcp.sh
```

The script returns JSON:
```json
{"cms_search": true, "data_cloud": false, "unsplash": true}
```

**Only present sources that are `true` in the output**, plus **Other** (always available).

### Example: All sources available
> I can help you find that image. Where would you like to search?
> 1. **Data Cloud – AI Hybrid Search (Salesforce CMS + 3rd-party DAMs)**
> 2. **CMS Keyword Search (Salesforce CMS)**
> 3. **Unsplash**
> 4. **Other** (please specify)

### Example: Only CMS available
> I can help you find that image. Where would you like to search?
> 1. **CMS Keyword Search (Salesforce CMS)**
> 2. **Other** (please specify)

## Step 2: Delegate to Search Skill

Only after the user selects an option, follow the matching skill by **source name** (not number — numbers change based on availability):

| User selects | Action |
|---|---|
| **CMS Keyword Search (Salesforce CMS)** | Read and follow `../cms-keyword-search/SKILL.md` |
| **Data Cloud – AI Hybrid Search (Salesforce CMS + 3rd-party DAMs)** | Read and follow `../cms-d360-search/SKILL.md` |
| **Unsplash** | Invoke the Unsplash MCP tools
| **Other** | Ask the user for the source URL or asset library details, then retrieve accordingly |

## Step 3: Present Results

After the delegated skill returns results:

- Display returned assets with preview thumbnails when available.
- Include asset title, source system, and relevance score or tags.
- Let the user confirm which asset to use before inserting it into the page or component.
- Do **not** automatically use the first result — user selection is required.
