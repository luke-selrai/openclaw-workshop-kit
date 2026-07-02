---
name: skill-creator
description: Guide for creating, updating, validating, and packaging Claude Code skills. Scaffolds new skills and ensures correct skill structure.
allowed-tools: Read, Write, Edit, Bash
license: Complete terms in LICENSE.txt
metadata:
  category: Productivity & Meta
  tags:
    - creation
    - templates
    - documentation
    - beginner-friendly
    - selr-ai
    - claude-workshop
  pairs-with:
    - skill: prompt-engineer
      reason: Skill descriptions and trigger phrases benefit from prompt engineering optimization
---

# Skill Creator

This skill provides guidance for creating, validating, and packaging effective Claude Code skills within the Selr AI / Claude Code Workshop Kit ecosystem.

---

## About Skills

Skills are modular, self-contained packages that extend Claude's capabilities by providing specialized knowledge, workflows, and tools. Think of them as "onboarding guides" for specific domains or tasks - they transform Claude from a general-purpose agent into a specialized agent equipped with procedural knowledge.

### What Skills Provide

1. **Specialized workflows** - Multi-step procedures for specific domains
2. **Tool integrations** - Instructions for working with specific file formats or APIs
3. **Domain expertise** - Company-specific knowledge, schemas, business logic
4. **Bundled resources** - Scripts, references, and assets for complex and repetitive tasks

### Anatomy of a Skill

Every skill consists of a required SKILL.md file and optional bundled resources:

```
skill-name/
├── SKILL.md                  (required)
│   ├── YAML frontmatter      (name + description required)
│   └── Markdown instructions (required)
└── Bundled Resources         (optional)
    ├── scripts/              Executable code (Python/Bash/etc.)
    ├── references/           Docs loaded into context as needed
    └── assets/               Files used in output (templates, icons, fonts)
```

### Selr AI Skill Directory Convention

When installing skills locally for Claude Code, always use the cross-platform path:

```
~/.claude/skills/<skill-name>/
```

For the Claude Code Workshop Kit repository, skills live under:

```
skills/
├── skill-name/
│   ├── SKILL.md
│   └── scripts/
```

Never hardcode a local machine path (e.g. `/Users/username/...`) in any skill file. Always use relative or `~`-based paths so skills work across Mac, Windows (WSL), and Linux.

---

## Bundled Resources

### scripts/

Executable code for tasks that require deterministic reliability or are repeatedly rewritten.

- **When to include**: When the same code is rewritten repeatedly, or reliability is critical
- **Example**: `scripts/rotate_pdf.py` for PDF rotation tasks
- **Benefits**: Token-efficient, deterministic, can be executed without loading into context

### references/

Documentation loaded into context to inform Claude's process and thinking.

- **When to include**: For detailed documentation Claude should reference while working
- **Examples**: `references/schema.md`, `references/api_docs.md`, `references/policies.md`
- **Best practice**: If files exceed 10k words, include grep search patterns in SKILL.md

### assets/

Files used within the output Claude produces - not loaded into context.

- **When to include**: When the skill needs templates, images, fonts, or boilerplate
- **Examples**: `assets/logo.png`, `assets/slides.pptx`, `assets/hello-world/`

---

## Scripts in This Skill

This skill includes three automation scripts. Always use them in this order:

| Script | When to Run | Command |
|---|---|---|
| `scripts/init_skill.py` | Creating a new skill from scratch | `python scripts/init_skill.py <skill-name> --path <output-dir>` |
| `scripts/quick_validate.py` | Before packaging, to catch errors early | `python scripts/quick_validate.py <path/to/skill>` |
| `scripts/package_skill.py` | After validation passes, to zip for distribution | `python scripts/package_skill.py <path/to/skill>` |

> **Never skip quick_validate.py.** package_skill.py runs validation internally, but running it separately first gives clearer error messages.

---

## Skill Creation Process

Follow these steps in order. Skip a step only if there is a clear reason it does not apply.

### Step 1: Understand the Skill with Concrete Examples

Clarify how the skill will be used before writing anything. Ask the user:

- "What should this skill enable Claude to do?"
- "Can you give 2-3 examples of how a user would trigger it?"
- "What would a user say that should activate this skill?"

Conclude this step when the functionality and trigger phrases are clear.

### Step 2: Plan Reusable Contents

Analyse each example to identify what bundled resources would help:

- Repeated code → `scripts/`
- Reference documentation → `references/`
- Templates or boilerplate → `assets/`

### Step 3: Initialise the Skill

Run `init_skill.py` to generate the folder structure:

```bash
python scripts/init_skill.py <skill-name> --path skills/
```

This creates:
- `SKILL.md` with frontmatter and TODO placeholders
- Example files in `scripts/`, `references/`, and `assets/`

Delete any example files not needed for the skill.

### Step 4: Edit the Skill

Write for another Claude instance - include what is non-obvious and procedurally important.

**Writing style rules:**
- Use **imperative/infinitive form** - verb-first instructions
- Avoid second person ("you should") - use "To do X, run Y"
- Keep SKILL.md under 500 lines; move detailed content to `references/`

**Description quality checklist:**
- [ ] Specific trigger phrases included
- [ ] Clear "when to use" and "when NOT to use"
- [ ] No angle brackets (`<` or `>`) in the description field
- [ ] Name is hyphen-case, lowercase only

### Step 5: Validate

Run validation before packaging:

```bash
python scripts/quick_validate.py <path/to/skill>
```

Fix any errors reported, then proceed.

### Step 6: Package

```bash
python scripts/package_skill.py <path/to/skill>
# Optional: specify output directory
python scripts/package_skill.py <path/to/skill> ./dist
```

This produces a `<skill-name>.zip` file ready for sharing or installation.

### Step 7: Iterate

After real-world testing:

1. Use the skill on actual tasks
2. Note where Claude struggled or skipped steps
3. Update SKILL.md or bundled resources accordingly
4. Re-validate and re-package
