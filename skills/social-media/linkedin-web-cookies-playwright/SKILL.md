---
name: linkedin-web-cookies-playwright
description: Use LinkedIn with Playwright Chromium and authenticated cookies. Bootstraps from /opt/data/cookies/linkedin_cookies.json into a persistent Chromium profile and verifies login through the web UI with one single gentle load, never in a loop. Read/check only by default; do not perform LinkedIn write actions from Hermes after the 2026 account-restriction incident. Spoofs the macOS user-agent the cookies were exported from. Hard-stops on HTTP 429.
version: 1.0.0
author: Pascal
license: MIT
metadata:
  hermes:
    tags: [social, linkedin, playwright, chromium, cookies, browser]
    category: social-media
    related_skills: []
---

# LinkedIn Web Cookies (Playwright Chromium)

## When to Use

Use this skill when the user wants Hermes to access LinkedIn through the web
interface using existing authenticated cookies exported from their Mac.

Use cases:
- Open `https://www.linkedin.com/feed/` once to verify the session is alive.
- Check whether the feed is visible or whether the session is logged out / challenged.
- Read the feed, a profile, or notifications.
- Search for people / content using gentle browser/UI navigation.

Hard constraint from the user: **do not use LinkedIn internal APIs/voyager for requests or writes.** Use browser/UI only, cautiously and transparently. For the new LinkedIn account/cookies, the old `/opt/data/cookies/linkedin-chromium-profile` was intentionally deleted because the previous account was blocked; recreate a fresh browser profile from the new cookies rather than reusing old state.

Do not post, invite, comment, message, follow, like, or perform any other write action from Hermes unless the user explicitly asks for a specific UI-based experiment and accepts the risk. Never use voyager/internal LinkedIn endpoints for those actions.

## CRITICAL INCIDENT: do NOT use voyager write endpoints for automation

On 2026-06-06, using LinkedIn's internal `voyager` web endpoints for a post and
then a connection invitation resulted in a LinkedIn account restriction page:

```text
Nous avons temporairement restreint l’accès à votre compte
Pour réactiver l’accès à votre compte, veuillez présenter une pièce d’identité officielle.
```

Conclusion: **voyager write calls are NOT a safe bypass.** They may succeed at
HTTP level (`201`/`200`) and still trigger LinkedIn anti-abuse systems shortly
after. Treat successful HTTP responses as insufficient proof of account safety.

Hard rule from now on:
- **Do not use internal voyager endpoints to post, connect, message, comment,
  follow, like, or perform any other write action.**
- **Do not send connection invitations from Hermes.** Invitations are especially
  monitored and can restrict the account after a single automated request.
- Use LinkedIn automation only for low-volume reading/checking, or ask the user
to perform write actions manually in their own browser.
- If the account is currently restricted, stop all LinkedIn automation. Do not
  retry, reload repeatedly, or attempt alternative endpoints.

The earlier assumption that `voyager` writes were safer than the UI was wrong.
They avoid heavy UI JS, but they appear to be a strong signal for automation
when used outside the normal browser interaction flow.

## THE #1 FAILURE MODE: trial-and-error against live LinkedIn

The first time this skill was used, the request was just "post something" — but
the agent ran a whole debugging loop against live LinkedIn:

```
post_graphify.py → inspect_composer → patch ×2 → inspect_composer again
→ screenshot → api_probe → api_post_graphify
```

Every one of those scripts launched Chromium and loaded LinkedIn pages. ~6 full
loads in minutes = **429**. The single post did NOT cause it — the
**iteration** did.

Rules that prevent this:

1. **Use the known-good path directly. Do NOT re-probe.** Posting is solved:
   `post_share()` → `voyager/api/contentcreation/normShares`. Call it. Do not
   write `inspect_composer`, `api_probe`, or `_graphify` scripts to
   re-discover how to post — that work is already done and lives in this file.
2. **One Chromium launch per task.** Reuse the same `ctx`/`page` for verify +
   action. Do not spawn a fresh script (and fresh page loads) for each attempt.
3. **No "let me try, screenshot, adjust, try again" loop against LinkedIn.** If
   the documented call fails, STOP and report — do not iterate live. Iterate
   logic offline, not by hammering the site.
4. **If you must discover a NEW endpoint** (search, invite, etc.), do it **once**,
   capture it (see "Capturing a new endpoint" below), write it into this skill,
   and never re-discover it on subsequent runs.

The mental shift: this skill is the *cache of what already works*. Reading it
should replace probing, not trigger more probing.

## Why This Setup (read before debugging)

LinkedIn ties the `li_at` session cookie to a bundle of signals far more
strictly than X does: **public IP**, **exact user-agent**, **device
fingerprint**, and request rhythm. A raw cookie injection that works for X will
get challenged on LinkedIn because the device looks brand new.

This host's situation removes the biggest risk factor:
- Cookies were exported from **Chrome on macOS**.
- Hermes runs on a **Raspberry Pi on the same home network** → **same public
  residential IP** as the Mac login. This is what keeps the session under the
  detection threshold.

The two gaps this skill closes:
1. **User-agent mismatch** — the Pi is Linux/ARM but the login was macOS. We
   force the exact macOS UA so the device stays coherent with the login.
2. **No persistent profile** — we use `launch_persistent_context` so the
   fingerprint stabilizes across runs instead of looking new every time.

## Important Preference

**Use Playwright Chromium with the existing LinkedIn cookies/profile, through the real browser UI only. Do not use Camoufox first unless Chromium fails. Do not use LinkedIn internal APIs/voyager for requests or writes.** Same reason as the X skill: Camoufox can fail because Firefox system libs (`libgtk-3.so.0`) may be missing and Hermes may lack `apt`.

## Files

```text
/opt/data/cookies/linkedin_cookies.json              # bootstrap cookie file
/opt/data/cookies/linkedin-chromium-profile/         # persistent Chromium profile
/opt/ms-playwright/chromium-1217/chrome-linux/chrome # known working Chromium on this host
```

Support files:
- `scripts/linkedin_probe.py` — safe login probe; prints only non-secret metadata and UI signals.
- `references/linkedin-runtime-validation.md` — expected healthy login-validation output and reporting style.
- `references/linkedin-invitations-voyager.md` — verified profile-URN lookup + invitation endpoint details and pitfalls.

Cookies to export from the Mac (all linkedin.com cookies, not just two):
- `li_at` — long-lived session (required).
- `JSESSIONID` — CSRF token, keep the quotes: `"ajax:1234..."` (required).
- `bcookie`, `bscookie`, `liap`, `lidc` — make the session look complete (recommended).

The `JSESSIONID` value doubles as the CSRF token sent in the `csrf-token`
header on voyager API calls. For **writes** (posting) we read it from the live
browser context and send it ourselves — see `get_csrf` / `post_share`. Strip the
surrounding quotes: the cookie is `"ajax:123..."`, the header must be `ajax:123...`.

Safety:
- Never print cookie values.
- Never paste `/opt/data/cookies/linkedin_cookies.json` or profile files into chat.

## User-Agent (must match the Mac login)

```text
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36
```

If the user re-exports cookies from a different machine/browser, update this UA
to match `navigator.userAgent` on that machine.

## Core Workflow — bootstrap once, then self-sustaining

The persistent profile is the real session. The JSON cookie file is only a
**seed** used the *first* time (or after the session breaks). On every later
run, LinkedIn refreshes the cookies and the profile saves them to disk — so the
session renews itself and `li_at` effectively never expires, exactly like the X
skill.

**Critical rule: do NOT re-inject the seed on every run.** Re-injecting would
overwrite the fresh cookies in the profile with the stale seed and *cause*
expiry. Only inject the seed when the profile is NOT already logged in.

1. Use Playwright Chromium with persistent profile `/opt/data/cookies/linkedin-chromium-profile/`.
2. Force the macOS user-agent above and `locale='fr-FR'`.
3. Open `https://www.linkedin.com/feed/` **using only the profile** (no seed injection).
4. Check login state.
5. **Only if logged out** and the seed file exists: inject the seed cookies,
   reload, and re-check. On success the profile now owns a fresh session.
6. Launch with the known executable if Playwright's default path is missing:
   `/opt/ms-playwright/chromium-1217/chrome-linux/chrome`.
   On this ARM host, set `PLAYWRIGHT_NODEJS_PATH=/usr/local/bin/node` if the
   packaged `playwright/driver/node` raises `Exec format error`.
7. Accept/refuse the cookie banner if present.
8. Read/act as requested — slowly, like a human.

After the first successful bootstrap you can delete (or keep as backup) the seed
file; the profile keeps the session alive on its own as long as Hermes uses it
regularly.

## Cookie Bootstrap File

Write it once (values from the Mac export). The `tee` form is fine; the
important part is the skill, not the file format:

```bash
sudo tee /opt/data/cookies/linkedin_cookies.json > /dev/null <<'EOF'
{
  "cookies": [
    { "name": "li_at",      "value": "REMPLACE", "domain": ".linkedin.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "None" },
    { "name": "JSESSIONID", "value": "\"ajax:REMPLACE\"", "domain": ".linkedin.com", "path": "/", "secure": true, "sameSite": "None" },
    { "name": "bcookie",    "value": "REMPLACE", "domain": ".linkedin.com", "path": "/", "secure": true, "sameSite": "None" },
    { "name": "bscookie",   "value": "REMPLACE", "domain": ".www.linkedin.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "None" },
    { "name": "liap",       "value": "REMPLACE", "domain": ".linkedin.com", "path": "/", "secure": true, "sameSite": "None" },
    { "name": "lidc",       "value": "REMPLACE", "domain": ".linkedin.com", "path": "/", "secure": true, "sameSite": "None" }
  ]
}
EOF
```

## Chromium Script Pattern

```python
import json, time, re
from pathlib import Path
from playwright.sync_api import sync_playwright

COOKIE_PATH = Path('/opt/data/cookies/linkedin_cookies.json')
PROFILE_DIR = Path('/opt/data/cookies/linkedin-chromium-profile')
CHROME = '/opt/ms-playwright/chromium-1217/chrome-linux/chrome'
UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36')
PROFILE_DIR.mkdir(parents=True, exist_ok=True)

def normalize_cookies():
    if not COOKIE_PATH.exists():
        return []
    raw = json.loads(COOKIE_PATH.read_text())
    cookies = raw.get('cookies', raw) if isinstance(raw, dict) else raw
    out = []
    for c in cookies:
        if not isinstance(c, dict) or 'name' not in c or 'value' not in c:
            continue
        nc = {k: v for k, v in c.items()
              if k in ['name', 'value', 'domain', 'path', 'expires',
                       'httpOnly', 'secure', 'sameSite']}
        nc.setdefault('domain', '.linkedin.com')
        nc.setdefault('path', '/')
        if 'expires' in nc and (nc['expires'] is None or nc['expires'] == -1):
            nc.pop('expires', None)
        if 'sameSite' in nc:
            mapping = {'no_restriction': 'None', 'unspecified': 'Lax',
                       'lax': 'Lax', 'strict': 'Strict', 'none': 'None'}
            ss = mapping.get(str(nc['sameSite']).lower(),
                             str(nc['sameSite']).capitalize())
            nc['sameSite'] = ss if ss in ['Strict', 'Lax', 'None'] else None
            if nc['sameSite'] is None:
                nc.pop('sameSite')
        out.append(nc)
    return out

def dismiss_cookie_banner(page):
    for label in ['Accept', 'Accepter', 'Tout accepter', 'Accept all',
                  'Refuse', 'Refuser', 'Reject']:
        try:
            btn = page.get_by_role('button', name=re.compile(re.escape(label), re.I)).first
            if btn.count() and btn.is_visible(timeout=800):
                btn.click(timeout=3000)
                time.sleep(1)
                return True
        except Exception:
            pass
    return False

class RateLimited(Exception):
    """HTTP 429 from LinkedIn. STOP. Never retry in the same run."""

def check_state(page):
    """ONE feed load. Classify: logged_in / logged_out / challenged / rate_limited.
    Never call this in a loop — repeated UI loads are what trigger 429."""
    resp = page.goto('https://www.linkedin.com/feed/',
                     wait_until='domcontentloaded', timeout=60000)
    if resp is not None and resp.status == 429:
        raise RateLimited('429 on /feed/. Back off (minutes/hours). Do NOT retry.')
    try:
        page.wait_for_load_state('networkidle', timeout=15000)
    except Exception:
        pass
    time.sleep(5)
    dismiss_cookie_banner(page)
    url = page.url
    body = page.locator('body').inner_text(timeout=15000)
    challenged = bool(re.search(r'/checkpoint/|/uas/login', url))
    logged_out = bool(
        re.search(r'Sign in|S.identifier|Join now|Welcome Back', body, re.I)
        and not re.search(r'Start a post|Commencer un post|Accueil|My Network|Mon r.seau', body)
    )
    return url, ('challenged' if challenged else
                 'logged_out' if logged_out else 'logged_in')

def get_csrf(ctx):
    """CSRF token = JSESSIONID value WITHOUT the surrounding double quotes.
    Cookie is "ajax:123..."  ->  header must be  ajax:123..."""
    for c in ctx.cookies('https://www.linkedin.com'):
        if c['name'] == 'JSESSIONID':
            return c['value'].strip('"')
    raise RuntimeError('JSESSIONID cookie missing; cannot build CSRF token.')

def post_share(page, text):
    """Publish a text post via the internal voyager web endpoint (verified 201).
    Uses page.request so the browser context's cookies + UA are reused."""
    csrf = get_csrf(page.context)
    resp = page.request.post(
        'https://www.linkedin.com/voyager/api/contentcreation/normShares',
        headers={
            'csrf-token': csrf,
            'accept': 'application/vnd.linkedin.normalized+json+2.1',
            'content-type': 'application/json; charset=UTF-8',
            'x-restli-protocol-version': '2.0.0',
            'x-li-lang': 'fr_FR',
            'origin': 'https://www.linkedin.com',
            'referer': 'https://www.linkedin.com/feed/',
        },
        data=json.dumps({
            'visibleToConnectionsOnly': False,
            'externalAudienceProviders': [],
            'commentaryV2': {'text': text, 'attributes': []},
            'origin': 'FEED',
            'allowedCommentersScope': 'ALL',
            'postState': 'PUBLISHED',
            'media': [],
        }),
    )
    if resp.status == 429:
        raise RateLimited('429 on normShares. Back off. Do NOT retry.')
    if resp.status not in (200, 201):
        raise RuntimeError(f'normShares failed: HTTP {resp.status} {resp.text()[:300]}')
    share_urn = resp.headers.get('x-restli-id', '')
    return {'posted': True, 'status': resp.status, 'share_urn': share_urn}

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        str(PROFILE_DIR),
        executable_path=CHROME,
        headless=True,
        user_agent=UA,
        locale='fr-FR',
        timezone_id='Europe/Paris',
        viewport={'width': 1280, 'height': 900},
        args=['--no-sandbox', '--disable-blink-features=AutomationControlled'],
    )
    try:
        page = ctx.pages[0] if ctx.pages else ctx.new_page()

        # 1) Verify the session with ONE feed load (profile only, no seed).
        url, state = check_state(page)

        # 2) Bootstrap from the seed ONLY if logged out. This is the one case
        #    that costs a second load — it happens on first run, not steady state.
        if state == 'logged_out' and COOKIE_PATH.exists():
            print({'info': 'profile logged out, bootstrapping from seed once'})
            ctx.add_cookies(normalize_cookies())
            url, state = check_state(page)

        print({'url': url, 'state': state})
        if state == 'challenged':
            raise RuntimeError('LinkedIn checkpoint/challenge. Validate the new-login '
                               'email on the account, then retry once later. Do not hammer.')
        if state != 'logged_in':
            raise RuntimeError('LinkedIn session invalid even after seed. '
                               'Re-export linkedin_cookies.json from the Mac.')

        # Session is alive. WRITES go through the voyager API, not the UI.
        # Only after explicit user confirmation:
        # result = post_share(page, 'Texte du post validé par l’utilisateur')
        # print(result)  # -> {'posted': True, 'status': 201, 'share_urn': 'urn:li:share:...'}

    except RateLimited as e:
        # 429 = rate-limited. Surface and STOP. Retrying makes the lock worse.
        print({'rate_limited': True, 'detail': str(e)})
        raise
    finally:
        ctx.close()  # persists refreshed cookies to the profile on disk
```

## Staying Under Detection

- **Same IP**: Hermes (Raspberry Pi) and the Mac login share the home public IP.
  Keep it that way — do not route Hermes through a VPN/datacenter proxy, that
  would *break* the very thing keeping you safe.
- **Same UA**: the forced macOS UA above. Update it only if cookies are re-exported elsewhere.
- **Persistent profile**: never delete `linkedin-chromium-profile/` unless the
  session is truly broken — it carries the stable fingerprint.
- **Human pace**: space out actions, no burst scraping, no pagination loops.
- **New-login email**: if LinkedIn emails "new sign-in detected", approve it —
  that whitelists the device.

## Searching & reading (gentle UI is fine)

Reading and searching do NOT have to avoid the UI — they just must not loop it.
A single navigation, read, scroll like a human = no problem. This is more robust
than the internal search API, whose `graphql` `queryId`s change constantly.

```python
# One load, no retry loop. Read results from the rendered page.
page.goto('https://www.linkedin.com/search/results/people/'
          '?keywords=cto%20fintech%20paris',
          wait_until='domcontentloaded', timeout=60000)
page.wait_for_load_state('networkidle', timeout=15000)
# extract result cards from the DOM here — do NOT reload in a loop to paginate;
# if you need more, scroll the existing page slowly.
```

Rule: **one page per thing you want to see.** Need page 2 of results? Scroll,
don't re-`goto` in a tight loop.

## Adding connections (the most monitored action — handle with care)

A 429 on a post is harmless and temporary. **Mass-inviting is what gets accounts
actually restricted or suspended** — this is the riskiest thing the skill can do.

Hard limits to respect:
- **Max ~100–200 invitations per WEEK** (LinkedIn enforces this server-side,
  cumulative across ALL runs — not per session). Stay conservative.
- **Never burst** — space invites by minutes, not seconds.
- Watch the **acceptance rate**: inviting many people who don't accept flags you faster.
- **Invitations WITH a personalized note are capped to ~5 per MONTH on a free
  account** (no Premium). Beyond that, send WITHOUT a note or the request fails.

### Autonomous (criteria-based) invites

The user wants to give a **search criterion**, not hand-pick each profile — the
bot finds and invites within bounds, without per-profile approval. This is the
**highest-risk mode**: the bot now controls the volume, so the guardrails are
what protect the account. Two things make it safe:

1. **Conservative caps, enforced by a PERSISTENT counter.** A weekly cap is
   useless if every run starts from zero — the bot would blow past it across
   runs. Track every sent invite on disk and refuse once the rolling 7-day or
   daily cap is hit. Start LOW (e.g. 15/day, 80/week) and only raise if
   acceptance stays healthy.
2. **Campaign-level confirmation, not per-profile.** The user approves the
   criterion + caps ONCE ("invite up to 15/day of CTOs in fintech in Paris").
   The bot then runs within that mandate and reports what it sent — it does not
   ask per profile, but it also does not invent new criteria on its own.

```python
import time

QUOTA_LOG  = Path('/opt/data/cookies/linkedin_invite_log.json')  # timestamps of sent invites
WEEKLY_CAP = 80
DAILY_CAP  = 15
DELAY_SECONDS = 120  # minutes-scale spacing between invites

def _load_log():
    try:
        return json.loads(QUOTA_LOG.read_text())
    except Exception:
        return []

def quota_budget():
    """How many invites are still allowed right now (min of daily/weekly room)."""
    now = time.time()
    log = [t for t in _load_log() if now - t < 7 * 86400]   # prune > 7 days
    QUOTA_LOG.write_text(json.dumps(log))
    week = len(log)
    day  = len([t for t in log if now - t < 86400])
    return max(0, min(WEEKLY_CAP - week, DAILY_CAP - day)), week, day

def _record_invite():
    log = _load_log()
    log.append(time.time())
    QUOTA_LOG.write_text(json.dumps(log))

def run_invite_campaign(page, keywords, note=None):
    budget, week, day = quota_budget()
    print({'quota': {'week': week, 'day': day, 'budget_now': budget}})
    if budget <= 0:
        raise RuntimeError(f'Invite quota reached (week={week}, day={day}). Stop for now.')

    targets = search_people_urns(page, keywords)   # gentle UI search, ONE load + scroll
    sent = []
    for urn in targets[:budget]:
        res = send_invite(page, urn, note=note)    # note honored only within the ~5/month cap
        _record_invite()
        sent.append(res)
        time.sleep(DELAY_SECONDS)                   # human-scale spacing
    print({'campaign_done': True, 'sent': len(sent), 'criterion': keywords})
    return sent
```

`search_people_urns` does ONE search load and reads `urn:li:fsd_profile:...`
from the result cards (capture the exact DOM/endpoint via DevTools the first
time — see below — then store it here). Do **not** re-search in a loop to
paginate; scroll the loaded page.

Stop immediately on 429 / challenge / restriction — `send_invite` already raises
`RateLimited`. On any of those, the campaign halts and reports; it does not retry.

Invite via the voyager endpoint. A successful single-profile invite flow is documented in `references/linkedin-invitations-voyager.md`.

Resolve a profile URL's public identifier to a `urn:li:fsd_profile:...` with:

```text
GET https://www.linkedin.com/voyager/api/identity/dash/profiles?q=memberIdentity&memberIdentity=<publicIdentifier>&decorationId=com.linkedin.voyager.dash.deco.identity.profile.FullProfileWithEntities-111
```

Use `elements[0].entityUrn` as the `profile_urn`. Do **not** rely on rendered profile text alone for relationship state: a profile can show `Message` + `Suivre` without being already connected, and scraping the page HTML may not expose the `fsd_profile` URN reliably.

Then send through the voyager endpoint:

```python
def send_invite(page, profile_urn):
    """profile_urn like 'urn:li:fsd_profile:ACoAAB...' from the dash profile endpoint."""
    csrf = get_csrf(page.context)
    resp = page.request.post(
        'https://www.linkedin.com/voyager/api/voyagerRelationshipsDashMemberRelationships'
        '?action=verifyQuotaAndCreateV2',
        headers={
            'csrf-token': csrf,
            'accept': 'application/vnd.linkedin.normalized+json+2.1',
            'content-type': 'application/json; charset=UTF-8',
            'x-restli-protocol-version': '2.0.0',
            'origin': 'https://www.linkedin.com',
            'referer': 'https://www.linkedin.com/feed/',
        },
        data=json.dumps({'invitee': {'inviteeUnion': {'memberProfile': profile_urn}}}),
    )
    if resp.status == 429:
        raise RateLimited('429 on invite. STOP. You are likely near the quota.')
    if resp.status not in (200, 201):
        raise RuntimeError(f'invite failed: HTTP {resp.status} {resp.text()[:300]}')
    return {'invited': profile_urn, 'status': resp.status}
```

When inviting several people, loop with a real delay and a per-run cap:

```python
MAX_PER_RUN = 15            # stay well under the weekly limit
DELAY_SECONDS = 90         # minutes-scale spacing, not seconds
for i, urn in enumerate(targets[:MAX_PER_RUN]):
    print(send_invite(page, urn))
    if i < len(targets[:MAX_PER_RUN]) - 1:
        time.sleep(DELAY_SECONDS)
```

## Capturing a new endpoint (when LinkedIn changes one)

This is exactly how `normShares` was found. Do it ONCE, then write the result
into this skill so no future run has to re-probe.

1. In a real desktop browser, open DevTools → **Network** tab, filter `voyager`.
2. Do the action **by hand** (post / search / invite).
3. Click the request → copy the **URL**, the **request headers** (especially
   `csrf-token`), and the **request payload** (JSON body).
4. Translate it into a `page.request.post/get(...)` call like the ones above.
5. **Save it into this SKILL.md.** The skill is the cache of working endpoints —
   capturing belongs here, not in throwaway `tmp_*_probe.py` scripts rerun every time.

## Rate-limit rules (non-negotiable)

These are what keep the session alive. Breaking them is what caused the first 429.

- **One** `/feed/` load to verify login. Never poll, never loop it.
- **Never retry on 429.** A 429 means back off — minutes to hours. Retrying
  while limited extends the lock and can escalate to a challenge.
- **No burst.** Space actions out. One post is one request; don't batch-post.
- **Writes via voyager API, reads/verify via one UI load.** Don't click the UI
  composer to post — full UI interactions are the heavily-throttled path.
- If `post_share` raises `RateLimited`, surface it and **stop the run**.

## Safety Rules

- Confirm before posting, commenting, connecting, messaging, liking, or following
  — unless the user gave a direct final command such as "ok publie".
- Never print cookie values or the contents of `linkedin_cookies.json`.
- Never paste profile files into chat.
- Do not claim to be connected unless the feed/login verification passed.
- On a checkpoint/challenge, stop and surface it — do not retry in a loop.
- A successful post returns HTTP 201 with `x-restli-id: urn:li:share:...`. Do
  not claim a post succeeded without that — report the share URN.

## Troubleshooting

**HTTP 429 (Too Many Requests)** — the session is rate-limited, almost always
from repeated UI page loads or retries. The cookies are probably still fine.
**Stop. Back off** several minutes to a few hours. Do not retry, do not reload
`/feed/` again — that prolongs the lock. When you resume, do a single verify
load, then post via `post_share` (voyager), not via the UI. If 429 persists for
hours, the IP/session may be flagged — leave it alone for a day.

**`post_share` returns HTTP 4xx other than 429** — the voyager schema may have
changed, or the CSRF token is wrong. Re-check that `csrf-token` equals the
JSESSIONID value WITHOUT quotes (`ajax:...`). LinkedIn occasionally changes the
`normShares` payload shape; inspect a real browser post's request body and
realign the JSON.

**Lands on `/checkpoint/` or a login challenge** — the device looked
inconsistent (often a UA/IP mismatch) or LinkedIn wants verification. Confirm
the UA matches the Mac, confirm Hermes is on the home network, validate the
new-login email, then retry once.

**Lands on the logged-out page** — cookies are stale. Re-export all linkedin.com
cookies from the Mac into `linkedin_cookies.json`. If still stuck, delete
`linkedin-chromium-profile/` to force a clean bootstrap.

**Playwright says Chromium executable does not exist** — use
`executable_path='/opt/ms-playwright/chromium-1217/chrome-linux/chrome'`. Avoid
`playwright install`.

**`Exec format error` for `playwright/driver/node` on ARM** — run with
`PLAYWRIGHT_NODEJS_PATH=/usr/local/bin/node python your_linkedin_script.py`.

**Camoufox missing `libgtk-3.so.0`** — ignore, use the Chromium workflow above.