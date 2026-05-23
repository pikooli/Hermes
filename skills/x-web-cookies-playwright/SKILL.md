---
name: x-web-cookies-playwright
description: Use X.com through the web interface with Camoufox (stealth Firefox). Bootstraps from /opt/data/cookies/x_cookies.json into a persistent profile so the session self-maintains and is much less likely to be flushed by X's bot detection than headless Chromium.
version: 2.0.0
author: Pascal
license: MIT
metadata:
  hermes:
    tags: [social, x, twitter, camoufox, stealth, cookies, browser]
    category: social-media
    related_skills: [x-post-writer]
---

# X Web Cookies (Camoufox)

## When to Use

Use this skill when the user wants Hermes to access X.com through the web interface using existing authenticated cookies, **without getting the session flushed every few days by X's bot detection**.

Use cases:
- Open `https://x.com/home` while authenticated.
- Check whether the X feed is visible or whether the session is logged out.
- Read the feed or profile pages.
- Post to X through the web UI after explicit user confirmation.
- Verify that a post appears on the user's profile.

## Why Camoufox instead of Playwright Chromium

X aggressively fingerprints automated browsers. Plain headless Chromium leaks `navigator.webdriver`, missing browser APIs, predictable timing, and WebGL/Canvas signatures — X spots this and silently invalidates the session even when the cookies are valid.

Camoufox is a patched Firefox bundled by the [scrapling](https://github.com/D4Vinci/Scrapling) library (already installed in this image). It:
- Hides automation markers at the C++ level (not just JS shims).
- Spoofs Canvas / WebGL / fonts / audio fingerprints to look like a real Firefox.
- Supports `humanize=True` for realistic cursor movement.
- Has GeoIP-aware locale/timezone matching.

Net result: cookies tend to survive weeks/months instead of hours/days.

## Files

```text
/opt/data/cookies/x_cookies.json        # bootstrap-only cookie file
/opt/data/cookies/camoufox-profile/     # persistent Camoufox/Firefox profile (auto-managed)
```

**Bootstrap file** is only read on the first run (profile dir empty). After that, Firefox maintains cookies itself, including `ct0` rotation.

Required cookies for bootstrap:
- `auth_token` — long-lived session.
- `ct0` — CSRF, refreshes inside the profile.

Permissions (Hermes runs as UID 10000):

```bash
sudo chown 10000:10000 /opt/data/cookies/x_cookies.json
sudo chmod 600 /opt/data/cookies/x_cookies.json
```

The parent `/opt/data/cookies/` must also be owned by 10000 so the profile directory can be created.

## Core Workflow

1. If `camoufox-profile/` exists and is non-empty → use directly.
2. Otherwise → read & normalize `x_cookies.json`, inject into a fresh persistent profile.
3. Launch Camoufox via `Camoufox(persistent_context=True, user_data_dir=...)`.
4. Open `https://x.com/home`.
5. Verify login state.
6. If logged out → raise an explicit error (cookies dead, refresh + delete profile).
7. Read / post as requested.

## Camoufox Script Pattern

```python
import json, time, re
from pathlib import Path
from camoufox.sync_api import Camoufox

COOKIE_PATH = Path('/opt/data/cookies/x_cookies.json')
PROFILE_DIR = Path('/opt/data/cookies/camoufox-profile')
PROFILE_DIR.mkdir(parents=True, exist_ok=True)

bootstrap = not any(PROFILE_DIR.iterdir())

normalized = []
if bootstrap:
    if not COOKIE_PATH.exists():
        raise RuntimeError(
            f"Profile is empty and {COOKIE_PATH} is missing. "
            "Provide auth_token + ct0 to bootstrap the session."
        )
    raw = json.loads(COOKIE_PATH.read_text())
    cookies = raw.get('cookies', raw) if isinstance(raw, dict) else raw
    if isinstance(cookies, dict):
        cookies = [
            {'name': k, 'value': v, 'domain': '.x.com', 'path': '/'}
            for k, v in cookies.items()
        ]
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
            ss = mapping.get(str(nc['sameSite']).lower(),
                             str(nc['sameSite']).capitalize())
            if ss in ['Strict', 'Lax', 'None']:
                nc['sameSite'] = ss
            else:
                nc.pop('sameSite', None)
        normalized.append(nc)

# Camoufox returns a BrowserContext directly when persistent_context=True
with Camoufox(
    persistent_context=True,
    user_data_dir=str(PROFILE_DIR),
    headless=True,
    humanize=True,         # realistic cursor movement
    block_webrtc=True,     # prevent IP leak
    geoip=True,            # match locale/timezone to outbound IP
    i_know_what_im_doing=True,
) as ctx:
    if bootstrap:
        ctx.add_cookies(normalized)

    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto('https://x.com/home', wait_until='domcontentloaded', timeout=60000)
    try:
        page.wait_for_load_state('networkidle', timeout=15000)
    except Exception:
        pass
    time.sleep(3)

    text = page.locator('body').inner_text(timeout=10000)
    logged_in = (
        page.title() == 'Home / X'
        and re.search(r'For you|Following', text)
        and not re.search(
            r'Email or username|Log in|Sign in|Create account|Continue with Google',
            text, re.I)
    )
    print({'url': page.url, 'title': page.title(), 'logged_in': bool(logged_in)})

    if not logged_in:
        raise RuntimeError(
            "X session expired or cookies invalid. "
            "Re-extract auth_token + ct0 from a logged-in browser, update "
            "/opt/data/cookies/x_cookies.json, then delete "
            "/opt/data/cookies/camoufox-profile to force re-bootstrap."
        )

    # --- read / post actions go here, reusing `page` ---
```

## Posting Pattern

```python
text = "Hello from Hermes"  # confirmed final text

page.goto('https://x.com/home', wait_until='domcontentloaded')
page.locator('[data-testid="tweetTextarea_0"]').click()
page.locator('[data-testid="tweetTextarea_0"]').fill(text)
page.locator('[data-testid="tweetButtonInline"]').click()

toast = page.wait_for_selector('[data-testid="toast"]', timeout=15000)
print({'posted': True, 'toast': toast.inner_text()})
```

If the toast does not appear within 15 s, the post failed (rate limit, duplicate, or session issue). Do not claim success.

## Verification Checklist

Before reporting success:

- **Login**: `page.title() == 'Home / X'` AND body contains `For you` / `Following` AND no login indicators.
- **Post**: `[data-testid="toast"]` appeared within 15 s after clicking the button.
- **Optional**: navigate to the user's profile and confirm the new post text is the top entry.

## Safety Rules

- Never print cookie values or contents of `x_cookies.json`.
- Never paste profile files into chat.
- Do not claim to be connected unless Camoufox verifies the feed is visible.
- If the session check fails, surface the error immediately. Do not retry silently.
- Confirm before posting, replying, liking, following, DMing, or deleting — unless the user gave a direct final command (e.g. "post hello").
- After posting, verify via the toast before reporting success.

## Maintenance

- The profile self-maintains as long as `auth_token` stays valid. With Camoufox, this is typically weeks to months instead of days.
- If Hermes hits the login screen and raises:
  1. Re-extract fresh `auth_token` + `ct0` from a logged-in browser.
  2. Overwrite `/opt/data/cookies/x_cookies.json` (ideally edit on the VPS via `nano`, never paste cookies in chat).
  3. Delete `/opt/data/cookies/camoufox-profile/` to force re-bootstrap.
- The bootstrap file becomes safe to delete after the first successful run.

## Troubleshooting

**`ModuleNotFoundError: No module named 'camoufox'`** — scrapling install didn't pull Camoufox properly. Run inside the container:
```bash
pip install camoufox && python -m camoufox fetch
```

**Camoufox crashes immediately** — Firefox may need extra libs. Run:
```bash
apt-get install -y libdbus-glib-1-2 libxt6
```

**Still flushed despite Camoufox** — check if the profile dir is being recreated empty between runs (perm issue). Also confirm `humanize=True` and `geoip=True` are set.
