# Deployment: from generated output to a live site

The one idea that bridges every platform: the build step never produces "a website" - it produces **code in a shape**. Each platform ingests a **different shape**. Match the shape to the platform's ingestion path and going live is mechanical.

Use this reference for Step 5 of the skill (offering to take a built site live).

## The four lanes

| Platform | Native unit | How the output goes live | Deploy / host | Best when… |
|---|---|---|---|---|
| **WordPress** | Blocks / PHP templates | Paste the HTML into a Custom HTML block, or rebuild the sections as blocks / page-builder sections | Kinsta, WP Engine, SiteGround | The client is already on WordPress or needs a familiar CMS |
| **React / Next.js** | Components you own | Scaffold the project, split into one component per section, build | **Vercel** (one click) | An app-like site with full control - the best coding-agent fit |
| **Shopify** | Liquid sections + schema | Build sections on a base theme (Dawn), push with the Shopify CLI | Shopify (managed) | Selling products - commerce is the point |
| **Astro** | `.astro` components + pages | Scaffold, drop section components in, ship static | Vercel, Netlify, Cloudflare Pages | A fast marketing / content site with minimal JS |

## Which deploy skill to hand off to

For a site built in this session, route to the matching capability:

- **Standalone HTML, Astro, or React/Next.js → `deploy-to-vercel`.** Vercel serves static HTML, Astro output, and Next.js natively, and gives a live URL in minutes. This is the highest-impact finish - the user goes from answers to a shareable link in one sitting.
- **Static sites as a Cloudflare alternative → `cloudflare-deployment`** (Cloudflare Pages). Equivalent path for HTML/Astro output when the user prefers Cloudflare.
- **WordPress →** no generic one-click deploy. The output installs on the user's own WordPress host: paste the HTML into a Custom HTML block, or import the sections into their theme / page builder (Elementor, Bricks, a block theme).
- **Shopify →** deploy into the user's existing store. From the theme directory: `shopify theme dev` to preview, then `shopify theme push`. Product and collection data comes from Liquid objects, not hardcoded markup.

## Recommended default lane

Don't run four lanes. Standardize on **Astro or Next.js on Vercel** unless there's a reason not to:

- **Default:** Astro or Next on Vercel. A coding agent builds these natively and best, they deploy in minutes, and they stay maintainable.
- **Only when needed:** WordPress or Shopify - reach for these when the client is already on that platform.
- **Always:** let the website-builder skill own the brief; the platform block picks the lane.

The biggest single upgrade for realistic output is a proper image source - an **Unsplash API key** (or Cloudinary for optimization + CDN) instead of relying on generic placeholder endpoints.
