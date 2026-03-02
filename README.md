# LinkLock

LinkLock is a strict single-link iOS viewer that opens a URL in an in-app `WKWebView` and blocks all navigation beyond the original resource. Users can scroll, play media, and interact with the page — but cannot move to other pages, domains, or external apps.

The goal: open what you need, not the entire internet.

---

## Philosophy

LinkLock is **not**:
- A browser
- A filtered browser
- A parental control system

LinkLock **is**:
- A locked single-resource viewer
- A containment layer for web access
- A tool for distraction-aware users

Every session is bound to one canonical URL. There are no exits.

---

## Core Features (v1)

- Paste and open a URL
- In-app browsing via `WKWebView`
- Strict navigation enforcement
- Blocks:
  - All main-frame navigation changes
  - Domain changes
  - Path/query/fragment changes
  - `target="_blank"` and `window.open`
  - Non-http(s) schemes
  - Universal links
  - External browser redirects
- Session tracking:
  - Original URL
  - Canonical URL
  - Duration
  - Blocked navigation count
- Structured developer logging

No URL bar.  
No tabs.  
No search.  
No bookmarks.

---

## How It Works

1. User pastes a URL.
2. The app resolves initial redirects.
3. The final canonical URL is locked.
4. All further navigation attempts are intercepted and blocked.
5. Users may interact within the page, but cannot leave it.

If a navigation attempt is blocked, an overlay appears:

> This action would leave the current link.

Options:
- Stay
- End Session

No override.

---

## Architecture

- Swift + SwiftUI
- `WKWebView`
- Custom `WKNavigationDelegate`
- Strict navigation decision tree
- Structured logging for blocked events
- Session state model

Navigation rule (simplified):

```

Initial load → Allow
Subresource load → Allow
Main-frame navigation to different URL → Block

```

The app never:
- Calls `UIApplication.shared.open`
- Opens Safari
- Opens external apps
- Creates additional web views

---

## Developer Logging

Each blocked event logs:

- Session ID
- Attempted URL
- Reason for block
- Timestamp

Designed to help refine navigation policies and detect edge cases.

---

## Roadmap

- Persistent history
- Usage dashboard
- Focus analytics
- Optional unlock timer (strictly opt-in)

---

## Product Statement

A web view without exits.
