---
name: Image Search Routing Protocol
description: Enforce consistent image search routing through MCP-based media sources
tags: vibe-coding, cms, image-search, mcp, routing
---

# Image Search Routing Protocol

## 🚨 STOP: READ THIS FIRST

**When a user mentions ANYTHING related to images, photos, pictures, media, visuals, or graphics:**

**YOU MUST IMMEDIATELY INVOKE THE `cms-media-search` SKILL.**

**DO NOT:**
- ❌ Present search options directly to the user
- ❌ Ask "Would you like to search CMS, Data Cloud, or Unsplash?"
- ❌ Respond with "I can help you search for images. Where would you like to search?"
- ❌ Make ANY assumptions about available sources
- ❌ Show ANY options before invoking the skill

**WHY:** You do not know which sources are available until the skill runs the availability check script. Presenting options without checking will show unavailable sources and create a broken user experience.

---

## Mandatory Execution Sequence

### Step 1: Detect Image Request
User mentions: search, find, get, fetch, retrieve, use, need, want + images/photos/pictures/media/visuals/graphics/logos/icons/hero image/banner

### Step 2: IMMEDIATELY Invoke Skill
**STOP ALL OTHER ACTIONS. Invoke `cms-media-search` skill NOW.**

Do NOT:
- Acknowledge the request first
- Ask clarifying questions about source
- Present any options
- Say anything about where to search

**Just invoke the skill immediately.**

### Step 3: Skill Executes
The skill will:
1. Run `check_mcp.py` to determine available sources
2. Present ONLY available options to the user
3. Wait for user selection
4. Route to the appropriate search skill

### Step 4: User Selects
User chooses from the options presented by the skill.

### Step 5: Execute Search
The skill routes to the correct search implementation.

---

## Absolute Prohibitions

### ❌ FORBIDDEN: Presenting Options Directly

**YOU CANNOT DO THIS:**
```
User: "Find me an apartment image"
Agent: "I can help! Would you like to search:
       1. CMS
       2. Data Cloud
       3. Unsplash
       Which would you prefer?"
```

**WHY FORBIDDEN:** You don't know if these sources are available. The skill must check first.

### ❌ FORBIDDEN: Delaying Skill Invocation

**YOU CANNOT DO THIS:**
```
User: "Find me an apartment image"
Agent: "I can help you find an apartment image. Let me check what's available..."
[Presents options]
[THEN invokes skill later]
```

**WHY FORBIDDEN:** The skill must run BEFORE any response to the user.

### ❌ FORBIDDEN: Making Assumptions

**YOU CANNOT DO THIS:**
```
User: "Find me an apartment image"
Agent: [Assumes CMS is available]
Agent: [Invokes cms-keyword-search directly without cms-media-search]
```

**WHY FORBIDDEN:** You don't know availability without running the check script.

---

## ✅ CORRECT Flow

**User Request:**
"Find me a modern luxury apartment image for the hero section"

**Your IMMEDIATE Action:**
[Invoke `cms-media-search` skill with NO prior response]

**What the skill does:**
1. Runs `check_mcp.py` → determines CMS and Unsplash are available
2. Presents to user:
   ```
   I can search for that image. Which source would you like to use?
   1. CMS Image Search
   2. Unsplash
   3. Other
   ```
3. User selects "1. CMS Image Search"
4. Skill invokes `cms-keyword-search`
5. Search executes and returns results

---

## Why This Strict Sequence Matters

**You cannot know availability without running the check script:**
- MCP servers may be disabled in settings
- MCP servers may be offline
- Tools may not be configured
- Environment variables may not be set

**The `cms-media-search` skill is the ONLY way to:**
- Determine actual availability
- Present accurate options
- Route correctly
- Provide consistent UX

---

## Rule Compliance Checklist

Before responding to ANY image request, verify:

- [ ] Did I invoke `cms-media-search` skill IMMEDIATELY?
- [ ] Did I avoid presenting any options directly?
- [ ] Did I avoid making assumptions about availability?
- [ ] Did I let the skill handle all routing and option presentation?

**If you answered NO to any question, you violated this rule.**

## Trigger Patterns

**IMMEDIATE skill invocation required when user mentions:**

### Primary Triggers (Image/Media Requests)
- "search for" + [images/photos/pictures/media/visuals/graphics]
- "find" + [images/photos/pictures/media/visuals]
- "get" + [images/photos/pictures/media]
- "fetch" + [images/photos/media/visuals]
- "retrieve" + [images/photos/content/media]
- "use" + [images/photos/pictures] + "from [CMS/anywhere]"
- "need" + [hero image/logo/banner/icon/visual/graphic]
- "want" + [image/photo/picture/visual]
- "show me" + [images/photos/pictures]
- "I need" + [image/photo/visual/graphic]
- "add" + [image/photo/picture]
- "insert" + [image/photo/visual]

### Context-Based Triggers
- User mentions "hero section" or "hero image"
- User mentions "logo" or "branding" in context of adding visuals
- User mentions "banner" or "header" in context of visuals
- User mentions "carousel" or "gallery" in context of content
- User mentions "thumbnail" or "preview image"

### Content Type Triggers
- Any mention of: apartment/car/product/person/landscape/office/kitchen images
- Any mention of: lifestyle/corporate/professional photos
- Any mention of: stock photos or stock imagery

---

## Detailed Examples

### ✅ CORRECT: Immediate Skill Invocation

**Example 1:**
```
User: "Find me a luxury apartment image for the hero"
Agent: [Immediately invokes cms-media-search skill - NO text response first]
Skill: [Runs check_mcp.py]
Skill: "I can search for that. Which source?
       1. CMS Image Search
       2. Unsplash
       3. Other"
User: [Selects option]
Skill: [Executes search]
```

**Example 2:**
```
User: "I need a professional office photo"
Agent: [Immediately invokes cms-media-search skill]
Skill: [Checks availability and presents options]
User: [Selects]
Skill: [Executes]
```

**Example 3:**
```
User: "Can you get me some car images?"
Agent: [Immediately invokes cms-media-search skill]
Skill: [Handles everything]
```

---

### ❌ WRONG: Presenting Options Without Skill

**Example 1 - VIOLATION:**
```
User: "Find me an apartment image"
Agent: "I can help! Where would you like to search?
       - CMS
       - Data Cloud
       - Unsplash"
❌ WRONG: Presented options without checking availability
```

**Example 2 - VIOLATION:**
```
User: "I need a hero image"
Agent: "Sure! Let me help you search for a hero image.
       Would you like to search CMS or Unsplash?"
❌ WRONG: Responded to user before invoking skill
```

**Example 3 - VIOLATION:**
```
User: "Get me a logo"
Agent: "I can search for logos. Let me check what's available..."
Agent: "You can search CMS, Data Cloud, or Unsplash"
[Later invokes cms-media-search]
❌ WRONG: Delayed skill invocation and presented options too early
```

**Example 4 - VIOLATION:**
```
User: "Find kitchen images"
Agent: [Invokes cms-keyword-search directly]
❌ WRONG: Bypassed cms-media-search routing, assumed CMS availability
```

---

### ✅ CORRECT: Immediate Invocation Even With Context

**Example:**
```
User: "I'm building a real estate page. Find me a luxury apartment exterior."
Agent: [Immediately invokes cms-media-search skill]
Skill: [Handles availability check and options]
```

**Not:**
```
User: "I'm building a real estate page. Find me a luxury apartment exterior."
Agent: "Great! For a real estate page, I can search for luxury apartment images.
       Would you like CMS or Unsplash?"
❌ WRONG: Responded without invoking skill first
```

---

## No Exceptions

**Even if user specifies a source:**

```
User: "Search CMS for apartment images"
Agent: [Still invokes cms-media-search skill]
Skill: [Verifies CMS is available]
Skill: [If available, proceeds with CMS search]
Skill: [If unavailable, informs user and shows alternatives]
```

**The skill MUST still validate availability.**

---

## Summary: The One Rule

**When user wants images → Immediately invoke `cms-media-search` skill.**

**Do NOT:**
- Talk first
- Present options first
- Check anything first
- Ask questions first
- Make assumptions

**Just invoke the skill.** The skill handles everything correctly.
