---
name: website-builder
description: Interactively generate a ready-to-paste website-build prompt (or the site itself) by asking the user a short set of intake questions (industry, business name, goal, services, pages, brand, style) and assembling them into a structured master prompt targeted at WordPress, Shopify, React/Next.js, Astro, or Claude design. Use when the user wants to build, scaffold, or design a landing page or multi-page marketing website, asks for a "website builder", "website prompt", "landing page prompt", or "generate a site for my business", says they want to be asked questions that fill in a website template, or wants to restyle, redesign, or deploy/publish a site they just built. Do NOT use for editing an existing production codebase, backend/API work, or non-website prompt engineering.
metadata:
  version: 1.0.0
---

# Website Builder

## Overview

This skill turns a few answers into a complete, structured website-build prompt.
Ask the user the intake questions, fill the master template in `assets/master-prompt-template.md` with their answers, splice in the correct platform block from `references/platform-blocks.md`, and hand back a single prompt they can paste into Claude, Claude design, or any coding agent - or offer to build the site directly.

The goal: the user only answers questions; the skill does the assembly.

## Workflow

Follow these steps in order.

### Step 1: Gather the answers

Ask the intake questions below. Prefer a structured multiple-choice question tool where the host supports it (offer sensible defaults as options plus a free-text choice); otherwise ask them as a short numbered list in one message so the user can answer all at once.

Do not interrogate one question at a time unless the user prefers it. Group them, offer defaults, and let the user override only what they care about.

**Intake questions (with defaults):**

1. **Industry / niche** - e.g. real estate, dental clinic, SaaS, coffee roaster. (required)
2. **Business name** - the brand to use throughout. (required)
3. **Primary goal / call to action** - the single action a visitor should take. Default: "contact us / request a quote". This becomes the main CTA.
4. **Services / offerings** - the 3-6 things they sell or the items that fill the listing grid. (required)
5. **Pages** - default: Home, Services (or Listings), About, Testimonials, Contact. Accept "just a one-page landing" to collapse to a single scrolling page.
6. **Landing-page sections** - default: Hero, Services/Listings grid, Testimonials, About teaser, Contact band. Let the user add or drop sections.
7. **Brand look** - colors and fonts. Default: "propose a professional palette and font pairing and state your choice."
8. **Style / vibe** - e.g. modern and trustworthy, bold and playful, luxury minimal. Optionally ask for 1-2 reference sites they admire.
9. **Target platform** - one of: WordPress, Shopify, React/Next.js, Astro, or Claude design / standalone HTML. (required - drives the output format)
10. **Output mode** - either "give me the ready-to-paste prompt" (default) or "build it here now".

If the user gives a vague brief up front (for example "a real estate site with the usual sections"), fill every field with the defaults above and only ask for the required ones still missing (industry, business name, services, platform).

### Step 2: Assemble the prompt

1. Read `assets/master-prompt-template.md`.
2. Replace every `{{PLACEHOLDER}}` with the user's answer (or the stated default).
3. Read `references/platform-blocks.md` and paste the block matching the chosen platform into the `{{PLATFORM_BLOCK}}` slot. For "Claude design / standalone HTML", use the Claude-design block.
4. Leave no `{{...}}` markers behind. Every slot must be resolved to a concrete value; if a value was defaulted, write the default's concrete instruction, not the word "default".

### Step 3: Deliver

- **If output mode is "give me the prompt"** (default): present the fully assembled prompt in a single fenced code block so the user can copy it in one action. Add one short line noting the platform it is tuned for and the highest-leverage tip (build the Home page first, then approve, before generating the rest).
- **If output mode is "build it here now"**: use the assembled prompt as your own working brief and build the site, honoring the platform block's output format. Build and show the Home page first, get approval, then continue.

### Step 4: Offer iteration hooks

After delivering, offer these follow-ups. Each reuses the identical intake answers so every version stays consistent - only the named part changes.

- **(a) Retarget a different platform** - swap only the platform block; all content, sections, and design stay identical.
- **(b) Tighten one section** - regenerate a single section (e.g. "redo just the hero, warmer") without touching the rest.
- **(c) Restyle** - change the look while keeping all content and structure. Only the DESIGN SYSTEM inputs move: `{{COLORS}}`, `{{FONTS}}`, `{{STYLE}}`, and optional `{{REFERENCES}}`. Ask for the new palette / font pairing / vibe (or reference sites), reassemble with every other answer unchanged, and regenerate. Because structure and copy are held fixed, a restyle is cheap and repeatable - the user can try several looks against the same site. This is the right tool when they say "same site, different style", "make it feel more premium", "try a darker theme", or "change the colors and fonts".

### Step 5: Offer to take it live

Once a site is actually built (output mode "build it here now"), offer to deploy it. Match the target platform to its deploy path - see `references/deployment.md` for the full four-lane guide:

- **Standalone HTML, Astro, or React/Next.js** - offer to publish it now. Invoke the **`deploy-to-vercel`** skill for a live URL in minutes (Vercel handles static HTML, Astro, and Next natively); **`cloudflare-deployment`** is the equivalent for Cloudflare Pages. This is the highest-impact finish: the user goes from answers to a shareable live link in one session.
- **WordPress** - the output installs on the user's own WordPress host (paste the HTML block, or import the sections into their theme/page builder). There is no generic one-click deploy; point them at their host.
- **Shopify** - push the section files to their store theme with `shopify theme dev` then `shopify theme push`. Deployment is into their existing Shopify store.

Only offer deploy for a site that was actually built here; if the output was a paste-ready prompt, deployment happens after they run that prompt.

## Design guidance to bake into every prompt

These are already encoded in the template and platform blocks; keep them intact when assembling:

- **Realistic, industry-specific placeholder copy - never lorem ipsum.** Include real-sounding names, prices, and 3+ testimonials.
- **Responsive, mobile-first, accessible** (semantic HTML5, alt text, focus states, WCAG AA contrast).
- **Name the design system up front** (colors, font pairing, spacing) rather than leaving styling vague.
- **Checkpoint after the Home page** so design direction can be approved before five pages are generated.
- **Images from Unsplash** so the mockup looks real: use stable Unsplash CDN URLs (`https://images.unsplash.com/photo-XXXX?auto=format&fit=crop&w=1600&q=80`), NOT the retired `source.unsplash.com` keyword endpoint. When no specific curated photo is available, fall back to a keyword photo service that needs no API key, e.g. `https://loremflickr.com/1600/900/real-estate,house`. Derive the `{{IMAGE_KEYWORDS}}` from the industry and each section (no need to ask the user). Always attach an error fallback to `https://placehold.co` (HTML `onerror`, or a JSX `onError` handler) so an image tag never breaks. Every image needs descriptive alt text.

## Claude design note

This skill is often used to feed **Claude design**. For that target, lean visual in the assembled prompt: describe mood, emotional impression, and reference sites, and let the tool own styling decisions. For code-agent targets (WordPress/Shopify/React/Astro), be strict about file format and framework as specified in each platform block.

## Resources

- `assets/master-prompt-template.md` - the fillable master prompt. The `{{PLATFORM_BLOCK}}` slot receives one platform block.
- `references/platform-blocks.md` - the five swappable output blocks (WordPress, Shopify, React/Next.js, Astro, Claude design / standalone HTML) plus per-platform notes.
- `references/deployment.md` - how each platform's output goes live (the four lanes), which deploy skill to hand off to, and the recommended default lane. Read this for Step 5.
