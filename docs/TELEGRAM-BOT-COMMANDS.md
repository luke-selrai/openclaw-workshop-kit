# Telegram Bot Commands — BotFather Setup

**Purpose:** Register skill shortcuts as Telegram bot commands so users can tap them from the menu instead of typing free text. This dramatically improves intent matching.

---

## How to Set Up Bot Commands

1. Open Telegram and search for **@BotFather**
2. Send: `/mybots`
3. Select your bot
4. Tap **Edit Bot** → **Edit Commands**
5. Paste ALL of the text below as a single message:

```
social - Write a social media post
ad - Create ad copy for Facebook, Google, Instagram
copy - Write or improve website copy
email - Draft a professional email
emailsequence - Build an automated email sequence
research - Deep research on any topic
brainstorm - Generate ideas and strategies
competitors - Analyze your competitors
pricing - Help with pricing and monetization
ads - Plan an ad campaign (strategy and budget)
content - Content strategy, blog posts, SEO
salescopy - High-converting sales copy
skills - Show all available skills
sales - Cold emails, outreach, and sales templates
reddit - Search Reddit for insights and feedback
appeal - Evaluate your product positioning
finance - Tax, investing, and financial advice
humanize - Remove AI writing patterns, make it natural
plan - Break a project into steps
coach - Business and founder coaching
analyst - Market research and industry analysis
prompt - Improve AI prompts and instructions
```

6. BotFather will confirm: "Success! Command list updated."

---

## How It Works

After setting up commands, users will see a **/** menu button in the Telegram chat. Tapping it shows all available skills as a list. Tapping a command sends it as a message.

**Example flow:**
1. User taps `/` menu → sees list of commands
2. User taps `/social` → sends "/social" to the bot
3. Assistant receives the message and invokes the `social-content` skill
4. Assistant asks: "What platform and topic? I'll write you a post."

---

## Command-to-Skill Mapping

The CLAUDE.md channel routing section handles translating these commands to skills:

| Telegram Command | Skill Invoked | What It Does |
|------------------|---------------|--------------|
| `/social` | social-content | Social media posts for any platform |
| `/ad` | ad-creative | Ad headlines and copy for paid platforms |
| `/copy` | copywriting | Website and marketing copy |
| `/email` | email-composer | Professional email drafting |
| `/emailsequence` | email-sequence | Automated email campaigns |
| `/research` | deep-research | In-depth research reports |
| `/brainstorm` | brainstorming | Structured idea generation |
| `/competitors` | competitor-alternatives | Competitor analysis and comparison |
| `/pricing` | indie-monetization-strategist | Pricing models and monetization |
| `/ads` | paid-ads | Ad campaign strategy and targeting |
| `/content` | content-marketer | Content strategy, blogs, SEO |
| `/salescopy` | direct-response-copy | High-converting sales copy |
| `/skills` | skills-discovery | Show all skills with recommendations |
| `/sales` | sales-automator | Cold emails, outreach templates |
| `/reddit` | reddit-insights | Reddit customer insights |
| `/appeal` | product-appeal-analyzer | Product desirability analysis |
| `/finance` | personal-finance-coach | Tax, investing, financial advice |
| `/humanize` | avoid-ai-writing | Remove robotic AI patterns |
| `/plan` | writing-plans | Step-by-step project planning |
| `/coach` | tech-entrepreneur-coach-adhd | Founder coaching |
| `/analyst` | research-analyst | Market research and trends |
| `/prompt` | prompt-engineer | AI prompt optimization |

---

## Adding to CLAUDE.md

The channel routing section in CLAUDE.md already handles these commands because:
- `/social` contains "social" → matches the social-content row in the routing table
- `/ad` contains "ad" → matches ad-creative
- etc.

No additional CLAUDE.md changes needed — the routing table covers both casual messages AND slash commands.

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
