# Source-grounded news research workflow for X drafts

Use this when the user asks to find new/current articles and draft a post for X.

## Candidate discovery

- Use a fresh-news aggregator query to collect candidates, e.g. Google News RSS with `when:7d` for the last week.
- Prefer queries that include the topic, geography, and key market terms, e.g. `immobilier France marché immobilier logement prix immobilier France when:7d`.
- Capture title, publisher/source, date, and aggregator URL.

## Canonical source verification

- Do not rely on aggregator snippets for specific numbers when a publisher page can be reached.
- Resolve aggregator URLs by searching the exact headline, preferably with DuckDuckGo or the publisher’s own site search/listing.
- If Google News RSS links do not expose the canonical URL and web search is sparse, query the publisher’s own newsroom/search page directly. Example pattern from French real-estate monitoring: a guessed `groupebpce.com/...` article URL returned 404, but `https://newsroom.groupebpce.fr/?s=immobilier%202026` exposed the canonical BPCE press-room article and its full facts.
- Verify facts from at least one primary/publisher page before drafting: title, publication date, named source, figures, and cautious language.
- If the canonical page is blocked, paywalled, mismatched, or redirects to unrelated content, label the limitation and avoid using unsupported numbers.
- For audio/article hybrids such as Radio France/ICI, the site search result can expose the canonical episode URL even when external search is noisy. Search the exact headline on the publisher site, open the result, then verify from the episode/article body: title/date, intro, section headings, paragraphs, and quoted expert lines. Good facts for X drafts often come from the body summary rather than the audio itself.
- For TF1 Info real-estate / succession topics, Google News RSS may show only aggregator URLs, but `https://www.tf1info.fr/recherche/?query=<urlencoded query>` exposes canonical article URLs in the search results. Once opened, TF1 article pages usually include rich JSON-LD `NewsArticle` metadata (`headline`, `datePublished`, `description`, `articleBody`) that can be parsed for source-grounded figures and quotes without relying on visible-page scraping.
- If multiple candidates appear but only one publisher page is fully verifiable, use that one for the draft and list the other fresh candidates as context rather than treating their snippets as confirmed evidence.

## Drafting

- Combine only verified, high-signal facts that fit one clear point.
- Preserve uncertainty from sources: “fragile”, “stable”, “slight rebound”, “expected/anticipated”, etc.
- Keep the X draft under 280 characters and include a character count in the validation message.
- In scheduled jobs, do not try to post or send separately; the final response is the validation message. Include sources, proposed text, character count, and a clear “not posted yet” note.