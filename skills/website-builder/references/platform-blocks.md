# Platform output blocks

Paste exactly one of these into the `{{PLATFORM_BLOCK}}` slot of the master template, matching the user's chosen target platform.
Each block defines the delivery format only - the rest of the prompt (content, sections, design system) stays identical across platforms, so the same answers produce consistent sites.

---

## WordPress

```
Output plain, self-contained HTML + CSS. Put all CSS in a single <style> block
(no external build step, no framework). Each page must be pasteable into a
WordPress "Custom HTML" block or saved as a page template. Do NOT use React,
Vue, or Liquid. Prefix all CSS class names with "wb-" so they do not collide
with the active theme. Avoid inline JavaScript beyond what a simple menu toggle
or form needs. If a page builder is preferred, also note how each section maps
to a Gutenberg block pattern.
```

Notes: most non-technical WordPress users paste into a Custom HTML block, so default to standalone HTML. Mention Elementor/Gutenberg mapping only if the user asks.

---

## Shopify

```
Output each section as a Shopify section file: valid Liquid markup plus a
{% schema %} block that exposes the section's headline, subtext, image, and CTA
as merchant-editable settings, and a matching {% stylesheet %} block. Use Liquid,
not React. Name each file and state where it goes (/sections for sections,
/snippets for shared partials). Keep settings simple and well-labeled so a
merchant can edit copy in the theme editor without touching code.
```

Notes: Shopify's unit is the section with a schema. If the user just wants a quick page, offer the fallback of plain HTML pasted into a custom Liquid section, but prefer proper sections.

---

## React / Next.js

```
Output a Next.js App Router project. One component per section under /components,
composed in app/page.tsx, with one route per page (app/about/page.tsx, etc.).
Use TypeScript and Tailwind CSS. Server components by default; add 'use client'
only where interactivity requires it (e.g. the contact form, a filter). Provide
the full file tree and each file's contents. Keep components small and reusable,
and share design tokens via Tailwind config.
```

Notes: default to App Router + Tailwind + TypeScript, the current idiomatic stack. If the user names Pages Router or plain Create-React-App, adapt.

---

## Astro

```
Output an Astro project. One .astro component per section under
src/components/, composed into pages under src/pages/ (src/pages/index.astro,
src/pages/about.astro, etc.). Ship zero client-side JavaScript by default - use
Astro's static rendering, and add a client:* directive only for genuinely
interactive islands (e.g. the contact form or a listings filter). Use scoped
<style> blocks in each component (or Tailwind if requested). Provide the full
file tree and each file's contents, including astro.config.mjs.
```

Notes: Astro's strength is content-heavy marketing sites with near-zero JS. Emphasize static output and islands. Use Tailwind only if the user asks; otherwise scoped component styles keep it simple.

---

## Claude design / standalone HTML

```
Produce a single, self-contained, responsive HTML file per page with all CSS in
a <style> block and any JS inline - no build step, no external dependencies
except Unsplash images and Google Fonts. Every <img> must pull a real Unsplash
photo via a stable CDN URL (images.unsplash.com/photo-..., NOT the retired
source.unsplash.com endpoint) and carry an onerror fallback to https://placehold.co
so no tag ever breaks.
Optimize for visual polish: strong
hero, generous whitespace, clear typographic hierarchy, and smooth section
rhythm. Treat this as a design artifact meant to be previewed and iterated
visually. Lead with the look and feel; describe the mood you are going for as
you build.
```

Notes: this is the best target for Claude design and for a quick visual prototype. Encourage the user to supply mood words and reference sites, and iterate section by section ("redo just the hero, warmer") rather than regenerating the whole page.
