---
name: x-post-writer
description: Write short, neutral, informative posts for X.com, with optional thread splitting.
version: 1.0.0
author: Pascal
license: MIT
metadata:
  hermes:
    tags: [social, x, twitter, writing, thread]
    category: writing
    related_skills: [x-web-cookies-playwright]
---

# X Post Writer

## When to Use

Use this skill when the user wants to write, rewrite, shorten, split, or prepare content for X.com / Twitter.

The goal is to produce posts that are:
- short
- clear
- neutral in tone
- mainly informative
- direct
- easy to read
- suitable for a single X post or a short thread

## Core Rules

1. Keep each post short.
2. Prefer one clear idea per post.
3. Avoid hype, clickbait, exaggerated claims, or emotional wording.
4. Do not use a promotional tone unless the user explicitly asks for it.
5. Use neutral, factual language.
6. Avoid unnecessary emojis.
7. Avoid long introductions.
8. Avoid filler sentences.
9. Avoid vague endings like:
   - “What do you think?”
   - “Let me know”
   - “Follow for more”
   unless explicitly requested.
10. Prioritize useful information over style.

## Source-Grounded Drafting

When drafting from an article URL:

0. If the user says the proposed topic/source was already posted or complains that you are “doing the same thing again” (e.g. “tu me refais le même”), immediately pivot to a clearly different angle rather than paraphrasing the same broad story. Identify the specific angle they ask for and make it the lead — e.g. if they ask to talk about “créer un Paris plus grand avec la banlieue”, foreground the Paris + banlieue / Grand Paris institutional change, not a generic urban-policy summary.

1. Extract the most specific facts available from the source, title, subtitle, snippets, metadata, RSS, or reputable aggregators before writing.
2. If the article itself is paywalled or access-restricted, do not invent details. Draft only from visible snippets/metadata and label the result as based on the accessible article summary if needed.
3. Prefer concrete drivers, numbers, named actors, dates, and consequences over generic summaries.
4. Preserve uncertainty when the source is cautious: use wording like “reste fragile”, “incertain”, or “inquiète” rather than stronger claims.
5. Include the source link in the final X post whenever a canonical source URL is available. Prefer appending `Source: <publisher> <URL>` at the end of a single post. If that makes the post too dense, shorten the prose first while preserving the key figures; only move the source link to a reply/thread post if a single-post source link would materially reduce the value of the main post or the user asked for a thread. When posting via X web, remember X shortens URLs in the composer, so verify the submit button is enabled rather than rejecting long raw URLs by Python `len()` alone.
6. If the user asks to “show me before” or similar, output the draft and character count only; do not publish until the user confirms the exact text.
7. For “find new articles and draft a post” tasks, first collect recent source candidates (RSS/search/news aggregators are acceptable), then verify at least one primary/source article or official publisher page before using specific numbers. If a publisher page is not directly reachable from an aggregator URL, try the publication’s own listing/search page for the headline before relying on snippets.
   - Practical workflow note: Google News RSS with `when:7d` is useful for fresh candidates; DuckDuckGo/exact-title search can resolve some Google News/aggregator URLs to the publisher’s canonical page. If that fails, search the publisher’s own site/newsroom listing directly (e.g. site search query pages) before relying on aggregator snippets. Prefer publisher pages for facts, dates, and links in the validation message.
   - For URL-included character counts, report the approximate X count using t.co shortening semantics (URL ≈ 23 chars) rather than raw string length; still keep the prose compact.
   - See `references/news-research-workflow.md` for a compact source-grounded research pattern.
8. In scheduled/cron contexts where the final response is delivered to the user, treat the final response as the validation message. Do not attempt to post to X or use a separate delivery channel; include sources, the proposed post with the canonical source link included when feasible, and character count, and explicitly say it has not been posted.

## Character Limit

X posts can be up to 280 characters. URLs are shortened by X in the composer, so raw Python `len(text)` can exceed 280 when a long URL is included. Still keep the human-readable text concise, then verify in the X composer that the submit button is enabled before posting rather than relying only on raw character count.

Target length:
- Ideal: 120–220 characters per post
- Maximum: 260 characters when possible
- Never exceed 280 characters

When content is too long:
- Split it into multiple posts
- Keep the main post readable alone
- Add extra details in replies/thread posts

## Thread Strategy

When the user provides too much content for one post:

1. Write a strong but neutral main post.
2. Make the first post fully standalone: introduce the topic directly, as if the reader has zero prior context. Avoid phrasing that sounds like an ongoing conversation or a reply to something already known (e.g. “pas juste…”, “ce n’est pas…” unless clearly necessary). Prefer openings like “Le projet X : l’idée…” or “X propose…” that name the subject first.
3. Put the most important information first.
4. Add details in follow-up posts.
5. Keep the thread short.
6. Do not create a long thread unless needed.
6. The assistant can draft multi-post threads (“multi-thread” / “thread en plusieurs réponses”) when the subject needs more than one X post. Split information across replies instead of forcing everything into one post.
7. For this user, a “continuer dans le thread” / “nouveau thread avec plus d’info à la suite” / “plusieurs réponses dans le thread” request means: draft a complete multi-post thread, not a single post with a continuation teaser.
8. If the user says the draft is too long but asks to keep “les infos intéressantes et chiffres”, compress the thread by removing generic framing first; preserve concrete facts, numbers, named places/actors, dates, comparisons, and consequences.
9. Prefer dense posts with one or two high-value facts each over many broad explanatory posts.

Preferred structure:

```text
Post 1:
Main information / key point.

Post 2:
Context or explanation.

Post 3:
Extra detail, example, or consequence.
```

## Output Format

For one post:

```text
Post:
<text>

Characters: <count>/280
```

For a thread:

```text
Thread:

Post 1:
<text>
Characters: <count>/280

Post 2:
<text>
Characters: <count>/280
```

If the user asks for multiple variants, provide concise labeled variants.

## Posting Safety

This skill is for writing and preparation. If the user asks to publish directly to X.com, confirm the exact final text before posting unless the user has explicitly provided the final text and clearly requested immediate posting.