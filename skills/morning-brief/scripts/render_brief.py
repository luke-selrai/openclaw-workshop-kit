#!/usr/bin/env python3
"""
Render the morning-brief HTML email body.

Usage:
  python3 render_brief.py < data.json > body.html

Input JSON shape:
  {
    "business_name": "Acme Co" | null,     # optional; shown as header eyebrow + footer. Omit for a plain brief.
    "long_date": "MONDAY, 25 MAY 2026",
    "calendar_events": [{"start":ISO,"end":ISO,"summary":str,"location":str}],
    "calendar_error": null | str,
    "contacts": [{"name":str,"email":str,"phone":str,"source":str,"tags":str,"ago":str}],
    "contacts_error": null | str,
    "needs_action": [{"sender":str,"recipient":str|null,"subject":str,"snippet":str,"ago":str,"thread_size":int}],
    "fyi": [{"sender":str,"recipient":str|null,"subject":str,"ago":str,"thread_size":int}],
    "hidden_count": int,
    "inbox_error": null | str,
    "triage": {"pre":int,"post":int,"filed_total":int,"per_group":{group:int}}
  }
"""

import sys
import json
import html
from datetime import datetime


ACCENT = "#4F46E5"
BLACK = "#0A0A0A"
GRAPHITE = "#6E7180"
CLOUD = "#EDEFF7"
SMOKE = "#D3D6E0"
WHITE = "#FFFFFF"
PAGE_BG = "#F3F4F8"


def fmtTimeRange(startIso, endIso):
    s = datetime.fromisoformat(startIso).strftime("%H:%M")
    e = datetime.fromisoformat(endIso).strftime("%H:%M")
    return f"{s} – {e}"


def renderCalendarSection(events, error):
    if error:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"Could not load — {html.escape(error)}</div>"
        )
    elif not events:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"Nothing scheduled today.</div>"
        )
    else:
        items = []
        for ev in events:
            when = fmtTimeRange(ev["start"], ev["end"])
            summary = html.escape(ev["summary"])
            loc = ev.get("location") or ""
            locSuffix = ""
            if loc and not loc.startswith("http"):
                locSuffix = (
                    f' <span style="color:{GRAPHITE};font-size:13px;">· '
                    f"{html.escape(loc)}</span>"
                )
            items.append(
                f'<div style="display:table;width:100%;padding:10px 0;border-bottom:1px solid {CLOUD};">'
                f'<div style="display:table-cell;width:130px;color:{BLACK};font-size:15px;font-weight:600;font-variant-numeric:tabular-nums;">{when}</div>'
                f'<div style="display:table-cell;color:{BLACK};font-size:15px;">{summary}{locSuffix}</div>'
                f"</div>"
            )
        inner = "".join(items)
    return sectionCard("TODAY'S CALENDAR", inner)


def renderContactsSection(contacts, error):
    if error:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"Could not load — {html.escape(error)}</div>"
        )
    elif not contacts:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"No new contacts in the last 24 hours.</div>"
        )
    else:
        items = []
        for c in contacts:
            name = html.escape(c.get("name", "") or "Unknown")
            source = html.escape(c.get("source") or "unknown")
            ago = html.escape(c.get("ago", ""))
            contactInfo = c.get("email") or c.get("phone") or ""
            tags = c.get("tags") or ""
            secondary = html.escape(contactInfo)
            if tags:
                secondary += (
                    f' <span style="color:{GRAPHITE};">· {html.escape(tags)}</span>'
                )
            items.append(
                f'<div style="padding:12px 0;border-bottom:1px solid {CLOUD};">'
                f'<div style="font-size:16px;color:{BLACK};font-weight:700;">{name} '
                f'<span style="color:{GRAPHITE};font-size:13px;font-weight:500;">· {source} · {ago}</span></div>'
                f'<div style="font-size:14px;color:{BLACK};margin-top:3px;">{secondary}</div>'
                f"</div>"
            )
        inner = "".join(items)
    return sectionCard("NEW CONTACTS · LAST 24H", inner)


def renderNeedsActionSection(needsAction, error):
    n = len(needsAction) if needsAction else 0
    title = f"NEEDS ACTION · {n}"

    if error:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"Could not load — {html.escape(error)}</div>"
        )
        return sectionCard(title, inner)

    if not needsAction:
        inner = (
            f'<div style="color:{BLACK};font-size:16px;padding:6px 0;font-weight:500;">'
            f"All clear. Nothing waiting on you right now."
            f"</div>"
        )
        return sectionCard(title, inner)

    parts = []
    for r in needsAction:
        sender = html.escape(r.get("sender", "") or "?")
        recipient = r.get("recipient")
        subject = html.escape(r.get("subject", "") or "")
        if not subject:
            subject = '<span style="color:#999;">(no subject)</span>'
        snippet = html.escape(r.get("snippet", "") or "")
        ago = html.escape(r.get("ago", ""))
        # Needs Action items are addressed to you — only show recipient if explicitly set
        recipBlock = (
            f' <span style="color:{GRAPHITE};font-weight:400;">→ {html.escape(recipient)}</span>'
            if recipient else ""
        )
        snippetBlock = (
            f'<div style="font-size:14px;color:{BLACK};margin-top:6px;line-height:1.5;opacity:0.85;">{snippet}</div>'
            if snippet else ""
        )
        parts.append(
            f'<div style="padding:16px 0;border-bottom:1px solid {CLOUD};">'
            f'<div style="font-size:17px;color:{BLACK};font-weight:700;">{sender}{recipBlock} '
            f'<span style="color:{GRAPHITE};font-size:13px;font-weight:500;">· {ago}</span></div>'
            f'<div style="font-size:15px;color:{BLACK};margin-top:4px;font-weight:500;">{subject}</div>'
            f"{snippetBlock}"
            f"</div>"
        )
    return sectionCard(title, "".join(parts))


def renderFyiSection(fyi, hiddenCount, error=None):
    n = len(fyi) if fyi else 0
    title = f"FYI · {n} TO BE ACROSS"

    if error:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"Could not load — {html.escape(error)}</div>"
        )
        return sectionCard(title, inner)

    if not fyi:
        inner = (
            f'<div style="color:{GRAPHITE};font-style:italic;font-size:14px;font-weight:500;">'
            f"No FYI threads to flag.</div>"
        )
        return sectionCard(title, inner)

    parts = []
    for r in fyi:
        sender = html.escape(r.get("sender", "") or "?")
        recipient = r.get("recipient") or ""
        subject = html.escape(r.get("subject", "") or "")
        if not subject:
            subject = '<span style="color:#999;">(no subject)</span>'
        ago = html.escape(r.get("ago", ""))
        threadSize = r.get("thread_size", 0)
        threadBadge = (
            f' <span style="color:{GRAPHITE};font-size:12px;font-weight:500;">· {threadSize} msgs</span>'
            if threadSize and threadSize > 1 else ""
        )
        # "sender → recipient" if recipient exists, else just sender
        senderLine = (
            f'<strong>{sender}</strong> '
            f'<span style="color:{ACCENT};font-weight:600;">→ {html.escape(recipient)}</span>'
            if recipient
            else f'<strong>{sender}</strong>'
        )
        parts.append(
            f'<div style="padding:13px 0;border-bottom:1px solid {CLOUD};">'
            f'<div style="font-size:15px;color:{BLACK};">'
            f"{senderLine}"
            f'<span style="color:{GRAPHITE};font-size:13px;font-weight:500;"> · {ago}</span>'
            f"{threadBadge}"
            f"</div>"
            f'<div style="font-size:14px;color:{BLACK};margin-top:3px;opacity:0.8;">{subject}</div>'
            f"</div>"
        )

    # Hidden tally line if any
    if hiddenCount and hiddenCount > 0:
        parts.append(
            f'<div style="margin-top:14px;padding:12px 16px;background:{CLOUD};border-radius:6px;'
            f'font-size:13px;color:{GRAPHITE};font-weight:500;">'
            f"<strong style=\"color:{BLACK};font-weight:700;\">{hiddenCount}</strong> stale thread{'s' if hiddenCount != 1 else ''} hidden "
            f"(you replied last, or no longer addressed)."
            f"</div>"
        )

    return sectionCard(title, "".join(parts))


def renderTriageCallout(triage):
    LABEL_PRETTY = {
        "hubstaff": "Hubstaff",
        "github": "GitHub",
        "notion": "Notion",
        "calendar": "Calendar invites",
        "morning-briefs": "Past briefs",
        "noreply": "Noreply/promo",
    }
    parts = []
    for key, val in triage.get("per_group", {}).items():
        if val > 0:
            label = LABEL_PRETTY.get(key, key)
            parts.append(f"{val} {label}")
    breakdown = " · ".join(parts) if parts else "no noise found"
    pre = triage.get("pre", 0)
    post = triage.get("post", 0)
    filedTotal = triage.get("filed_total", 0)
    line = (
        f"Triaged <strong>{pre}</strong> emails — filed <strong>{filedTotal}</strong> "
        f"as noise ({breakdown}) — <strong>{post}</strong> remain for your attention."
    )
    return (
        f'<div style="background:{CLOUD};border:1px solid {SMOKE};border-radius:8px;'
        f'padding:18px 22px;margin-bottom:16px;color:{BLACK};font-size:15px;line-height:1.55;">'
        f"{line}</div>"
    )


def sectionCard(title, innerHtml):
    return (
        f'<div style="background:{WHITE};border:1px solid {SMOKE};border-radius:8px;'
        f'padding:18px 22px;margin-bottom:16px;">'
        f'<div style="font-size:13px;font-weight:700;color:{ACCENT};letter-spacing:1.6px;'
        f'margin-bottom:12px;font-family:Helvetica,Arial,sans-serif;">{title}</div>'
        f"{innerHtml}</div>"
    )


def renderBody(data):
    longDate = data.get("long_date", "")
    business = (data.get("business_name") or "").strip()

    calendarCard = renderCalendarSection(
        data.get("calendar_events") or [], data.get("calendar_error")
    )
    contactsCard = renderContactsSection(
        data.get("contacts") or [], data.get("contacts_error")
    )
    actionCard = renderNeedsActionSection(
        data.get("needs_action") or [],
        data.get("inbox_error"),
    )
    fyiCard = renderFyiSection(
        data.get("fyi") or [],
        data.get("hidden_count") or 0,
        data.get("inbox_error"),
    )
    triageCallout = renderTriageCallout(data.get("triage") or {})

    # Header eyebrow + footer carry the attendee's business name when provided.
    eyebrow = ""
    if business:
        eyebrow = (
            f'<div style="font-size:13px;font-weight:700;color:{ACCENT};letter-spacing:1.6px;'
            f'margin-bottom:10px;text-transform:uppercase;font-family:Helvetica,Arial,sans-serif;">'
            f"{html.escape(business)}</div>"
        )

    footer = ""
    if business:
        footer = (
            f'<div style="max-width:680px;margin:22px auto 0;padding:0 12px;color:{GRAPHITE};'
            f'font-size:12px;line-height:1.7;font-weight:500;">{html.escape(business)}</div>'
        )

    return (
        f'<div style="background:{PAGE_BG};padding:24px 12px;font-family:Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">'
        f'<div style="max-width:680px;margin:0 auto;background:{WHITE};border:1px solid {SMOKE};border-radius:12px;padding:32px 32px 28px;">'
        f"{eyebrow}"
        f'<h1 style="margin:0 0 6px;font-size:32px;font-weight:700;color:{BLACK};line-height:1.15;font-family:Helvetica,Arial,sans-serif;letter-spacing:-0.5px;">Morning Briefing</h1>'
        f'<div style="font-size:14px;font-weight:700;color:{ACCENT};letter-spacing:1.6px;margin-bottom:28px;">{longDate}</div>'
        f"{calendarCard}{actionCard}{fyiCard}{triageCallout}{contactsCard}"
        f'<div style="margin-top:24px;color:{BLACK};font-size:14px;">Have a good one,</div>'
        f'<div style="color:{BLACK};font-size:14px;">Your morning briefing agent</div>'
        f"</div>"
        f"{footer}"
        f"</div>"
    )


def main():
    data = json.load(sys.stdin)
    sys.stdout.write(renderBody(data))


if __name__ == "__main__":
    main()
