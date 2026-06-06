---
name: x-web-cookies-playwright
description: Use X.com through the web interface with Playwright Chromium and authenticated cookies. Bootstraps from /opt/data/cookies/x_cookies.json into a persistent Chromium profile and posts/reads through the real web UI.
version: 2.1.0
author: Pascal
license: MIT
metadata:
  hermes:
    tags: [social, x, twitter, playwright, chromium, cookies, browser]
    category: social-media
    related_skills: [x-post-writer]
---

# X Web Cookies (Playwright Chromium)

## When to Use

Use this skill when the user wants Hermes to access X.com through the web interface using existing authenticated cookies.

Use cases:
- Open `https://x.com/home` while authenticated.
- Check whether the X feed is visible or whether the session is logged out.
- Read the feed or profile pages.
- Post to X through the web UI after explicit user confirmation.
- Post short threads through the web UI.
- Verify that X displayed the post/send toast.

## Important Preference

**Prefer Playwright Chromium with the existing X cookies/profile. Do not start with Camoufox. Do not fall back to `xurl` unless the user explicitly asks for API/OAuth posting.**

Reason: on this host Camoufox can fail because Firefox system libraries such as `libgtk-3.so.0` are missing and Hermes may not have `apt` permission to install them. Playwright Chromium already worked for posting with cookies.

## Files

```text
/opt/data/cookies/x_cookies.json             # bootstrap cookie file: auth_token + ct0
/opt/data/cookies/x-chromium-profile/        # persistent Chromium profile used by this skill
/opt/ms-playwright/chromium-1217/chrome-linux/chrome  # known working Chromium executable on this host (ARM/aarch64 path)
```

Required cookies for bootstrap:
- `auth_token` — long-lived session.
- `ct0` — CSRF, refreshes inside the browser profile.

Safety:
- Never print cookie values.
- Never paste `/opt/data/cookies/x_cookies.json` or profile files into chat.

## Core Workflow

1. Use Playwright Chromium with persistent profile `/opt/data/cookies/x-chromium-profile/`.
2. If cookies exist in `/opt/data/cookies/x_cookies.json`, normalize and inject them into the context before opening X.
3. Launch Chromium with the known executable if Playwright's default browser path is missing:
   `/opt/ms-playwright/chromium-1217/chrome-linux/chrome`.
   On this ARM/aarch64 host, set `PLAYWRIGHT_NODEJS_PATH=/usr/local/bin/node` when running Playwright if the packaged `playwright/driver/node` raises `Exec format error`.
4. Open `https://x.com/home`.
5. Accept/refuse cookie banner if present.
6. Verify login state from the page body and URL/title.
7. Post/read as requested.
8. For posting, require X's toast confirmation before claiming success.

Do not use `xurl` as a fallback for normal web-cookie posting. It needs separate OAuth/API setup and can waste time.

## Chromium Script Pattern

```python
import json, time, re
from pathlib import Path
from playwright.sync_api import sync_playwright

COOKIE_PATH = Path('/opt/data/cookies/x_cookies.json')
PROFILE_DIR = Path('/opt/data/cookies/x-chromium-profile')
CHROME = '/opt/ms-playwright/chromium-1217/chrome-linux/chrome'
PROFILE_DIR.mkdir(parents=True, exist_ok=True)

def normalize_cookies():
    if not COOKIE_PATH.exists():
        return []
    raw = json.loads(COOKIE_PATH.read_text())
    cookies = raw.get('cookies', raw) if isinstance(raw, dict) else raw
    if isinstance(cookies, dict):
        cookies = [
            {'name': k, 'value': v, 'domain': '.x.com', 'path': '/'}
            for k, v in cookies.items()
        ]
    out = []
    for c in cookies:
        if not isinstance(c, dict) or 'name' not in c or 'value' not in c:
            continue
        nc = {k: v for k, v in c.items()
              if k in ['name', 'value', 'domain', 'path', 'expires',
                       'httpOnly', 'secure', 'sameSite']}
        dom = nc.get('domain') or '.x.com'
        if dom in ['x.com', 'twitter.com']:
            dom = '.' + dom
        nc['domain'] = dom
        nc.setdefault('path', '/')
        if 'expires' in nc and (nc['expires'] is None or nc['expires'] == -1):
            nc.pop('expires', None)
        if 'sameSite' in nc:
            mapping = {
                'no_restriction': 'None', 'unspecified': 'Lax',
                'lax': 'Lax', 'strict': 'Strict', 'none': 'None',
            }
            ss = mapping.get(str(nc['sameSite']).lower(), str(nc['sameSite']).capitalize())
            if ss in ['Strict', 'Lax', 'None']:
                nc['sameSite'] = ss
            else:
                nc.pop('sameSite', None)
        out.append(nc)
    return out

def dismiss_cookie_banner(page):
    for label in [
        'Accept all cookies', 'Accepter tous les cookies', 'Aceptar todas las cookies',
        'Refuse non-essential cookies', 'Refuser les cookies non essentiels', 'Rechazar cookies no esenciales',
    ]:
        try:
            btn = page.get_by_role('button', name=re.compile(re.escape(label), re.I)).first
            if btn.count() and btn.is_visible(timeout=800):
                btn.click(timeout=3000)
                time.sleep(1)
                return True
        except Exception:
            pass
    return False

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        str(PROFILE_DIR),
        executable_path=CHROME,
        headless=True,
        viewport={'width': 1280, 'height': 900},
        args=['--no-sandbox', '--disable-blink-features=AutomationControlled'],
    )
    try:
        if COOKIE_PATH.exists():
            ctx.add_cookies(normalize_cookies())
        page = ctx.pages[0] if ctx.pages else ctx.new_page()
        page.goto('https://x.com/home', wait_until='domcontentloaded', timeout=60000)
        try:
            page.wait_for_load_state('networkidle', timeout=15000)
        except Exception:
            pass
        time.sleep(5)
        dismiss_cookie_banner(page)

        body = page.locator('body').inner_text(timeout=15000)
        logged_in = (
            re.search(r'For you|Following|Pour vous|Abonnements|What is happening', body)
            and not re.search(r'Email or username|Log in|Sign in|Create account|Continue with Google', body, re.I)
        )
        print({'url': page.url, 'title': page.title(), 'logged_in': bool(logged_in)})
        if not logged_in:
            raise RuntimeError('X session expired or cookies invalid. Refresh x_cookies.json if needed.')

        # --- read / post actions go here ---
    finally:
        ctx.close()
```

## Posting Pattern

Single post:

```python
text = 'Hello from Hermes'  # final user-approved text

editor = page.locator('[data-testid="tweetTextarea_0"]').first
editor.wait_for(state='visible', timeout=20000)
editor.click()
page.keyboard.insert_text(text)  # do not use fill(); X may not enable submit

enabled = page.locator(
    '[data-testid="tweetButtonInline"]:not([aria-disabled="true"]), '
    '[data-testid="tweetButton"]:not([aria-disabled="true"])'
)
enabled.last.click(timeout=10000)

toast = page.wait_for_selector('[data-testid="toast"]', timeout=25000)
print({'posted': True, 'toast': toast.inner_text()})
```

Thread posting:

```python
posts = ['First post text', 'Reply/source text']

editor0 = page.locator('[data-testid="tweetTextarea_0"]').first
editor0.wait_for(state='visible', timeout=20000)
editor0.click()
page.keyboard.insert_text(posts[0])

def click_add_post(page):
    selectors = [
        '[data-testid="addButton"]',
        '[aria-label="Add post"]', '[aria-label="Ajouter un post"]',
        '[aria-label="Add another post"]', '[aria-label="Ajouter un autre post"]',
    ]
    for sel in selectors:
        try:
            loc = page.locator(sel).first
            if loc.count() and loc.is_visible(timeout=1500):
                loc.click(timeout=5000)
                return True
        except Exception:
            pass
    return False

if not click_add_post(page):
    raise RuntimeError('Could not find X add-post/thread button; do not post a standalone single post by mistake.')

time.sleep(1)
editor1 = page.locator('[data-testid="tweetTextarea_1"]').first
editor1.wait_for(state='visible', timeout=10000)
editor1.click()
page.keyboard.insert_text(posts[1])

enabled = page.locator(
    '[data-testid="tweetButtonInline"]:not([aria-disabled="true"]), '
    '[data-testid="tweetButton"]:not([aria-disabled="true"])'
)
if enabled.count() == 0:
    raise RuntimeError('No enabled submit button; inspect composer instead of retrying blindly.')
enabled.last.click(timeout=10000)

toast = page.wait_for_selector('[data-testid="toast"]', timeout=25000)
print({'posted': True, 'toast': toast.inner_text()})
```

Important posting pitfalls:
- `fill()` may not trigger X's composer state; use `page.keyboard.insert_text()`.
- In a thread composer, the first `[data-testid="tweetButtonInline"]` may be disabled. Select an enabled button with `:not([aria-disabled="true"])` and click `.last`.
- If the add-post button is not found, stop rather than posting only the first tweet.
- If the toast does not appear, do not claim success.

## Verification Checklist

Before reporting success:

- **Login**: page body contains `For you` / `Following` / `Pour vous` / `Abonnements` and no login indicators.
- **Post/thread**: `[data-testid="toast"]` appeared after clicking submit.
- Successful toast example seen on this host: `Your posts were sent.\nView`.
- Optional: capture or print the final URL, but do not expose cookies.

## Safety Rules

- Confirm before posting, replying, liking, following, DMing, or deleting — unless the user gave a direct final command such as “ok publie”.
- Never print cookie values or contents of `x_cookies.json`.
- Never paste profile files into chat.
- Do not claim to be connected unless the feed/login verification passed.
- If the session check fails, surface the error immediately.
- After posting, verify via the toast before reporting success.

## Troubleshooting

**Playwright says Chromium executable does not exist** — use the known local executable:
```python
executable_path='/opt/ms-playwright/chromium-1217/chrome-linux/chrome'
```
Avoid running `playwright install` first; it can hang or download an incompatible browser while a working one already exists.

**Playwright raises `Exec format error` for `playwright/driver/node` on ARM/aarch64** — run the script with the system Node path:
```bash
PLAYWRIGHT_NODEJS_PATH=/usr/local/bin/node python your_x_script.py
```

**X shows the logged-out landing page** — cookies/profile are stale. Refresh `/opt/data/cookies/x_cookies.json` with `auth_token` and `ct0`, then retry. If needed, remove `/opt/data/cookies/x-chromium-profile/` to force a clean bootstrap.

**Submit button disabled** — use `keyboard.insert_text()`, wait briefly, then select only enabled submit buttons with `:not([aria-disabled="true"])`.

**Thread button not found** — stop and inspect buttons; do not post the first tweet alone.

**Camoufox missing `libgtk-3.so.0` or other system libs** — do not waste time unless the user explicitly wants Camoufox. Use the Chromium workflow above.

**`xurl` not found or unauthenticated** — ignore for this skill. This skill is web-cookie based, not API/OAuth based.