#!/usr/bin/env node
// Legacy-install fixture builder — reconstructs a machine as an OLD bootstrap
// left it, inside a sandbox, so the new one-paste setup prompt can be dry-run
// against a realistic migration target instead of a guess.
//
// Why this exists: people are already installed the old way, across more than
// one old way. The install-model overhaul (CORE-99) has to migrate all of them
// without re-onboarding them or eating their work. "It should be fine" is not a
// check. This builds the before-state so the migration can be run and observed,
// and it is deliberately re-runnable: every future change to the setup prompt
// gets re-tested against the same before-states, so this is a standing check,
// not a one-off.
//
// THREE SHAPES, because the kit was distributed three ways. Each is read off
// `docs/start/bootstrap.md` at that era's own ref, so the fixture is derived
// from the kit's own record of what it did rather than from memory:
//
//   shape            kit home                      workspace              marker  plugins
//   ---------------  ----------------------------  ---------------------  ------  -------
//   loup             ~/.loup/selr-ai/workshop-kit  ~/Desktop/my-assistant  yes     yes
//   github-desktop   ~/workshop-kit                ~/Desktop/my-assistant  yes     yes
//   github-home      ~/workshop-kit                ~/my-assistant          NO      NO
//
// `loup` is a LEGACY SHAPE, not a live one. ADR-0003 retired Loup as a delivery
// channel; the shape stays because the before-states it reconstructs are still
// sitting on attendee laptops, and migration has to find that kit home, rebuild
// fingerprints from it, and then remove it exactly as it removes ~/workshop-kit.
// Nothing here means the Loup door still exists.
//
// `github-home` is the ancient pre-revive shape and the awkward one: its
// workspace is in the home folder, not the Desktop, and it predates both the
// `.first-run-pending` marker and the plugin marketplace step. Anything that
// hardcodes `~/Desktop/my-assistant` will silently skip it. (The short-lived
// local-zip era has the same end-state as `github-home`; only how the kit
// arrived differed, and nothing reads that.)
//
// In every shape three things are ABSENT — no pointer block in
// `~/.claude/CLAUDE.md`, no `~/.claude/selr-assistant.md`, no
// `selr-kit-manifest.json`. Their absence is what migration has to fix, so the
// fixture records it and the dry-run asserts it rather than assuming.
//
// ISOLATION IS **HOME ALONE** — deliberately not CLAUDE_CONFIG_DIR. Redirecting
// CLAUDE_CONFIG_DIR does relocate the whole config tree, but it also breaks
// auth: the CLI reports "Not logged in" because it can no longer reach the
// stored credentials, so nothing can actually be dry-run. With HOME sandboxed
// and CLAUDE_CONFIG_DIR left unset, the config dir resolves to the fixture's
// own `~/.claude` anyway — same isolation, and auth still works. `~` in the
// prompt's own shell commands follows HOME too. Nothing touches the real
// machine. (Headless runs additionally need CLAUDE_CODE_OAUTH_TOKEN in the
// environment; see docs/agents/legacy-install-fixture.md.)
//
// GIT CREDENTIALS ARE ALWAYS NEUTRALISED, and this matters more than it looks.
// The prompt decides what to do with an unauthenticated `git ls-remote` probe.
// A developer machine reads the CLOSED repo just fine, because the real global
// gitconfig routes github.com through `gh auth git-credential`, so an
// un-neutralised probe SUCCEEDS, and the dry-run silently tests the clone
// branch while claiming to test a closed room: a false pass either way. An
// attendee has no credentials, gets refused, and is told the kit is not open
// yet. The sandbox therefore ships a `.gitconfig` with an empty
// `credential.helper`, clearing the inherited helper list.
//
// Since ADR-0003 there is only one door, so a refused probe now DRY-RUNS TO A
// STOP: the prompt waits for the room to open and touches nothing. To exercise
// the clone and everything after it, run the fixture while the repo is actually
// PUBLIC, during a drop window, which is exactly when attendees run it. Do NOT
// try to smuggle credentials in; a sandboxed HOME drops gh's own config and
// keyring access, so the probe is refused regardless.
//
// Usage:
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --shape github-home
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --shape loup --global-claude-md user-content
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --shape loup --ref <sha> --force
//
// Options:
//   --out <dir>            where to build the sandbox (required)
//   --shape <name>         loup (default) | github-desktop | github-home
//   --ref <git-ref>        override the era's pinned default ref
//   --force                wipe --out if it already exists
//   --global-claude-md     none (default) | user-content
//                          `user-content` seeds a pre-existing hand-written
//                          ~/.claude/CLAUDE.md with no pointer block — the case
//                          where migration must add the block WITHOUT eating
//                          what the user already wrote.
//   --pristine             skip the user-made-content seeding (see below)
//   --no-plugins           skip the real `claude plugin` calls (offline / no CLI)
//
// By default the fixture is NOT pristine. It plants the three things that make
// the interesting migration branches reachable at all:
//   1. a user-authored file in the workspace       (must survive untouched)
//   2. a user-authored skill not from the kit      (must survive untouched)
//   3. an EDITED copy of a real kit skill          (must trip keep-and-report,
//                                                   not be silently overwritten)
// A pristine fixture only exercises the happy path, which is the path least
// likely to break.
//
// Exit codes: 0 = fixture built, 1 = build failed, 2 = bad usage / git unreadable.

import { execFileSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Era boundaries, resolved from this repo's own history. Each default ref is the
// last commit where that era's bootstrap was the live one.
const SHAPES = {
  loup: {
    ref: "ad124f1",
    kitHome: [".loup", "selr-ai", "workshop-kit"],
    workspace: ["Desktop", "my-assistant"],
    marker: true,
    plugins: true,
    note: "Loup delivery (retired by ADR-0003); the most recent legacy shape.",
  },
  "github-desktop": {
    ref: "6265b8e",
    kitHome: ["workshop-kit"],
    workspace: ["Desktop", "my-assistant"],
    marker: true,
    plugins: true,
    note: "git clone to ~/workshop-kit, Desktop workspace.",
  },
  "github-home": {
    ref: "ddb68ec",
    kitHome: ["workshop-kit"],
    workspace: ["my-assistant"],
    marker: false,
    plugins: false,
    note: "ancient pre-revive: home-folder workspace, no marker, no plugins.",
  },
};

function git(args) {
  // 256 MB buffer comfortably holds the kit tarball (~tens of MB).
  return execFileSync("git", ["-C", ROOT, ...args], { maxBuffer: 256 * 1024 * 1024 });
}

function parseArgs(argv) {
  const opts = {
    out: null,
    shape: "loup",
    ref: null,
    force: false,
    globalClaudeMd: "none",
    pristine: false,
    plugins: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--out") opts.out = argv[++i];
    else if (a === "--shape") opts.shape = argv[++i];
    else if (a === "--ref") opts.ref = argv[++i];
    else if (a === "--force") opts.force = true;
    else if (a === "--pristine") opts.pristine = true;
    else if (a === "--no-plugins") opts.plugins = false;
    else if (a === "--global-claude-md") opts.globalClaudeMd = argv[++i];
    else return { error: `unknown option: ${a}` };
  }
  if (!opts.out) return { error: "--out <dir> is required" };
  if (!SHAPES[opts.shape]) {
    return { error: `--shape must be one of: ${Object.keys(SHAPES).join(", ")}` };
  }
  if (!["none", "user-content"].includes(opts.globalClaudeMd)) {
    return { error: "--global-claude-md must be none|user-content" };
  }
  return { opts };
}

// Unpack the kit at `ref` into destDir, as that era's install would have left it.
// Content only, no `.git`: the new prompt never reads the old kit directory, it
// acquires a fresh copy at its own kit home.
function materializeKit(ref, destDir) {
  mkdirSync(destDir, { recursive: true });
  const tar = git(["archive", "--format=tar", ref]);
  execFileSync("tar", ["-x", "-C", destDir], { input: tar, maxBuffer: 256 * 1024 * 1024 });
}

// Every FOLDER from the kit's skills/, nothing else — all three eras did this.
function installSkills(kitSkillsDir, destSkillsDir) {
  mkdirSync(destSkillsDir, { recursive: true });
  let n = 0;
  for (const entry of readdirSync(kitSkillsDir)) {
    const src = join(kitSkillsDir, entry);
    if (!statSync(src).isDirectory()) continue; // drops SKILLS-LIST.md
    cpSync(src, join(destSkillsDir, entry), { recursive: true });
    n++;
  }
  return n;
}

// The real CLI calls, run against the sandbox. Faithful by construction —
// hand-forging plugins/*.json would drift the moment the CLI's format changes.
function installPlugins(home, kitDir) {
  const env = { ...process.env, HOME: home, CLAUDE_CONFIG_DIR: join(home, ".claude") };
  const run = (args) =>
    execFileSync("claude", args, { env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  run(["plugin", "marketplace", "add", kitDir]);
  run(["plugin", "install", "routine-installer-plugin@selrai-workshop-kit"]);
}

// The user-made content that makes migration's hard branches reachable.
// Returned descriptors go into FIXTURE.json so a dry-run can assert against
// them without re-deriving what was planted.
function seedUserContent(workspace, workspaceRel, skillsDir) {
  const seeded = { workspaceFile: null, ownSkill: null, editedKitSkill: null };

  writeFileSync(
    join(workspace, "my-notes.md"),
    "# My notes\n\nQuotes for the Tuesday job. Do not lose this file.\n",
  );
  seeded.workspaceFile = `${workspaceRel}/my-notes.md`;

  const ownSkillDir = join(skillsDir, "my-own-skill");
  mkdirSync(ownSkillDir, { recursive: true });
  writeFileSync(
    join(ownSkillDir, "SKILL.md"),
    "---\nname: my-own-skill\ndescription: A skill the user wrote themselves. Must survive migration untouched.\n---\n\nMine, not the kit's.\n",
  );
  seeded.ownSkill = ".claude/skills/my-own-skill";

  // Edit a real kit skill in place so its fingerprint no longer matches — this
  // is what keep-and-report has to catch. Pick deterministically (first kit
  // skill alphabetically) so the fixture stays reproducible.
  const kitSkills = readdirSync(skillsDir)
    .filter((e) => e !== "my-own-skill" && statSync(join(skillsDir, e)).isDirectory())
    .sort();
  if (kitSkills.length > 0) {
    const target = join(skillsDir, kitSkills[0], "SKILL.md");
    if (existsSync(target)) {
      writeFileSync(
        target,
        readFileSync(target, "utf8") + "\n\n<!-- user edit: do not silently overwrite me -->\n",
      );
      seeded.editedKitSkill = `.claude/skills/${kitSkills[0]}/SKILL.md`;
    }
  }
  return seeded;
}

function main() {
  const { opts, error } = parseArgs(process.argv.slice(2));
  if (error) {
    console.error(`make-legacy-fixture: ${error}`);
    console.error(
      "Usage: node scripts/make-legacy-fixture.mjs --out <dir> [--shape loup|github-desktop|github-home]",
    );
    process.exit(2);
  }

  const shape = SHAPES[opts.shape];
  const ref = opts.ref || shape.ref;

  let commit;
  try {
    commit = git(["rev-parse", ref]).toString("utf8").trim();
  } catch (e) {
    console.error(`make-legacy-fixture: could not resolve ref "${ref}": ${e.message}`);
    process.exit(2);
  }

  const out = resolve(opts.out);
  if (existsSync(out)) {
    if (!opts.force) {
      console.error(`make-legacy-fixture: ${out} already exists (pass --force to replace it)`);
      process.exit(2);
    }
    rmSync(out, { recursive: true, force: true });
  }

  const home = join(out, "home");
  const kitDir = join(home, ...shape.kitHome);
  const workspace = join(home, ...shape.workspace);
  const workspaceRel = shape.workspace.join("/");
  const claudeDir = join(home, ".claude");
  const skillsDir = join(claudeDir, "skills");

  try {
    mkdirSync(workspace, { recursive: true });
    mkdirSync(claudeDir, { recursive: true });

    // The kit, as that era's install dropped it.
    materializeKit(ref, kitDir);

    // The persona, copied into the workspace (NOT imported globally).
    cpSync(join(kitDir, "my-assistant", "CLAUDE.md"), join(workspace, "CLAUDE.md"));

    // The marker the new model retires. It must not retrigger orientation after
    // migration — one of the things being verified. Absent in the ancient shape.
    if (shape.marker) writeFileSync(join(workspace, ".first-run-pending"), "");

    // Skills, flat, at the global path — the same in every era.
    const skillCount = installSkills(join(kitDir, "skills"), skillsDir);

    // A pre-existing hand-written global CLAUDE.md, with no pointer block.
    if (opts.globalClaudeMd === "user-content") {
      writeFileSync(
        join(claudeDir, "CLAUDE.md"),
        "# My own global instructions\n\nAlways call me Sam.\nNever send email without asking me first.\n",
      );
    }

    // A real attendee has used Claude Code already (they installed the kit through
    // it), so `~/.claude.json` exists. A fresh sandbox HOME has none, and the CLI
    // aborts at startup rather than creating one — seeding it is both the fix and
    // the more faithful state.
    writeFileSync(join(home, ".claude.json"), "{}\n");

    // Make the acquisition probe behave like an attendee's machine, not a dev's.
    // Note both branches write a .gitconfig: a sandboxed HOME inherits NEITHER
    // the real global config nor its credential helpers, so "keep" has to copy
    // them forward explicitly — omitting the file would silently neutralise
    // credentials just the same and quietly test the wrong door.
    writeFileSync(join(home, ".gitconfig"), "[credential]\n\thelper =\n");

    const seeded = opts.pristine ? null : seedUserContent(workspace, workspaceRel, skillsDir);

    // Plugin marketplace + routine packager, via the real CLI. The ancient shape
    // predates this step entirely.
    let pluginsInstalled = false;
    const wantPlugins = opts.plugins && shape.plugins;
    if (wantPlugins) {
      try {
        installPlugins(home, kitDir);
        pluginsInstalled = true;
      } catch (e) {
        console.error(
          `make-legacy-fixture: WARNING - plugin install failed, fixture built without it.\n  ${e.message.split("\n")[0]}`,
        );
      }
    }

    const record = {
      shape: opts.shape,
      builtFrom: { ref, commit },
      layout: {
        kitHome: `~/${shape.kitHome.join("/")}`,
        workspace: `~/${workspaceRel}`,
        marker: shape.marker ? `~/${workspaceRel}/.first-run-pending` : null,
      },
      options: {
        globalClaudeMd: opts.globalClaudeMd,
        pristine: opts.pristine,
        pluginsRequested: opts.plugins,
        gitCredentialsNeutralised: true,
      },
      state: { skillCount, pluginsInstalled, seeded },
      // Absences are the point of the fixture — record them so a dry-run can
      // assert the migration created them rather than assuming it did.
      absent: [
        "~/.claude/CLAUDE.md pointer block",
        "~/.claude/selr-assistant.md",
        "~/.claude/selr-kit-manifest.json",
      ],
      run: { HOME: home, CLAUDE_CONFIG_DIR: claudeDir, cwd: workspace },
    };
    writeFileSync(join(out, "FIXTURE.json"), JSON.stringify(record, null, 2) + "\n");

    console.log(`Legacy-install fixture built at ${out}`);
    console.log(`  shape          ${opts.shape} — ${shape.note}`);
    console.log(`  kit ref        ${ref} (${commit.slice(0, 9)})`);
    console.log(`  kit home       ~/${shape.kitHome.join("/")}`);
    console.log(`  workspace      ~/${workspaceRel}`);
    console.log(`  marker         ${shape.marker ? ".first-run-pending" : "none (predates it)"}`);
    console.log(`  skills         ${skillCount} at ~/.claude/skills/`);
    console.log(`  global CLAUDE  ${opts.globalClaudeMd}`);
    console.log(
      `  plugins        ${pluginsInstalled ? "installed" : shape.plugins ? "not installed" : "n/a (predates them)"}`,
    );
    console.log(`  user content   ${opts.pristine ? "none (pristine)" : "seeded"}`);
    console.log("  git creds      neutralised (attendee-like)");
    console.log("");
    console.log("Dry-run the new setup prompt against it with:");
    console.log("");
    console.log(`  cd "${workspace}"`);
    console.log(`  env -u CLAUDE_CONFIG_DIR HOME="${home}" claude`);
    console.log("");
    console.log("  (CLAUDE_CONFIG_DIR must stay UNSET or auth breaks — see the header.");
    console.log(`   Start in ${workspace} to reproduce the attendee's own`);
    console.log('   starting folder, or anywhere else to test "works from any folder".)');
    process.exit(0);
  } catch (e) {
    console.error(`make-legacy-fixture: build failed: ${e.message}`);
    process.exit(1);
  }
}

main();
