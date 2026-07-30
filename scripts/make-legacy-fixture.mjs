#!/usr/bin/env node
// Legacy-install fixture builder — reconstructs a machine as the OLD bootstrap
// left it, inside a sandbox, so the new one-paste setup prompt can be dry-run
// against a realistic migration target instead of a guess.
//
// Why this exists: 10+ school-community members are already installed the old
// way. The install-model overhaul (CORE-99) has to migrate them without
// re-onboarding them or eating their work. "It should be fine" is not a check —
// this builds the before-state so the migration can actually be run and
// observed. It is deliberately re-runnable: every future change to the setup
// prompt gets re-tested against the same before-state, so this is a standing
// check, not a one-off.
//
// The legacy end-state it reproduces is read straight off `docs/start/bootstrap.md`
// (steps 2-6) at the pinned ref:
//   ~/Desktop/my-assistant/CLAUDE.md          <- kit my-assistant/CLAUDE.md
//   ~/Desktop/my-assistant/.first-run-pending <- the retired orientation marker
//   ~/.loup/selr-ai/workshop-kit/             <- the kit itself (Loup path)
//   ~/.claude/skills/<one dir per kit skill>  <- flat copy, no SKILLS-LIST.md
//   ~/.claude/plugins/...                     <- marketplace + routine-installer
// and, definitionally, NO pointer block in ~/.claude/CLAUDE.md and NO
// selr-kit-manifest.json anywhere. Their absence is the thing under test.
//
// Isolation is HOME + CLAUDE_CONFIG_DIR. Verified: CLAUDE_CONFIG_DIR relocates
// the whole config tree (settings.json, plugins/, .claude.json), and `~` in the
// prompt's own shell commands follows HOME. Nothing touches the real machine.
//
// Usage:
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --ref 07d1ecf --force
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --global-claude-md user-content
//   node scripts/make-legacy-fixture.mjs --out /tmp/legacy --pristine --no-plugins
//
// Options:
//   --out <dir>            where to build the sandbox (required)
//   --ref <git-ref>        kit version to reconstruct from (default HEAD).
//                          Pin this to the version the attendees actually have.
//   --force                wipe --out if it already exists
//   --global-claude-md     none (default) | user-content
//                          `user-content` seeds a pre-existing hand-written
//                          ~/.claude/CLAUDE.md with no pointer block — the case
//                          where migration must add the block WITHOUT eating
//                          what the user already wrote.
//   --pristine             skip the user-made-content seeding (see below)
//   --no-plugins           skip the real `claude plugin` calls (offline / no CLI)
//
// By default the fixture is NOT pristine: it seeds the three things that make
// the interesting migration branches reachable at all —
//   1. a user-authored file in the workspace       (must survive untouched)
//   2. a user-authored skill not from the kit      (must survive untouched)
//   3. an EDITED copy of a real kit skill          (must trip keep-and-report,
//                                                   not be silently overwritten)
// A pristine fixture only ever exercises the happy path, which is the path
// least likely to break.
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

function git(args) {
  // 256 MB buffer comfortably holds the kit tarball (~tens of MB).
  return execFileSync("git", ["-C", ROOT, ...args], { maxBuffer: 256 * 1024 * 1024 });
}

function parseArgs(argv) {
  const opts = {
    out: null,
    ref: "HEAD",
    force: false,
    globalClaudeMd: "none",
    pristine: false,
    plugins: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--out") opts.out = argv[++i];
    else if (a === "--ref") opts.ref = argv[++i];
    else if (a === "--force") opts.force = true;
    else if (a === "--pristine") opts.pristine = true;
    else if (a === "--no-plugins") opts.plugins = false;
    else if (a === "--global-claude-md") opts.globalClaudeMd = argv[++i];
    else return { error: `unknown option: ${a}` };
  }
  if (!opts.out) return { error: "--out <dir> is required" };
  if (!["none", "user-content"].includes(opts.globalClaudeMd)) {
    return { error: `--global-claude-md must be none|user-content` };
  }
  return { opts };
}

// Unpack the kit at `ref` into destDir, exactly as Loup would have dropped it.
function materializeKit(ref, destDir) {
  mkdirSync(destDir, { recursive: true });
  const tar = git(["archive", "--format=tar", ref]);
  execFileSync("tar", ["-x", "-C", destDir], { input: tar, maxBuffer: 256 * 1024 * 1024 });
}

// Step 5 of the old bootstrap: every FOLDER from the kit's skills/, nothing else.
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

// Steps 6: the real CLI calls, run against the sandbox. Faithful by construction —
// hand-forging plugins/*.json would drift the moment the CLI's format changes.
function installPlugins(home, kitDir) {
  const env = { ...process.env, HOME: home, CLAUDE_CONFIG_DIR: join(home, ".claude") };
  const run = (args) =>
    execFileSync("claude", args, { env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  run(["plugin", "marketplace", "add", kitDir]);
  run(["plugin", "install", "routine-installer-plugin@selrai-workshop-kit"]);
}

// The user-made content that makes migration's hard branches reachable.
// Returns descriptors the FIXTURE.json records, so a dry-run can assert against
// them without re-deriving what was planted.
function seedUserContent(home, skillsDir) {
  const seeded = { workspaceFile: null, ownSkill: null, editedKitSkill: null };

  const workspaceFile = join(home, "Desktop", "my-assistant", "my-notes.md");
  writeFileSync(
    workspaceFile,
    "# My notes\n\nQuotes for the Tuesday job. Do not lose this file.\n",
  );
  seeded.workspaceFile = "Desktop/my-assistant/my-notes.md";

  const ownSkillDir = join(skillsDir, "my-own-skill");
  mkdirSync(ownSkillDir, { recursive: true });
  writeFileSync(
    join(ownSkillDir, "SKILL.md"),
    "---\nname: my-own-skill\ndescription: A skill the user wrote themselves. Must survive migration untouched.\n---\n\nMine, not the kit's.\n",
  );
  seeded.ownSkill = ".claude/skills/my-own-skill";

  // Edit a real kit skill in place so its hash no longer matches the receipt —
  // this is what keep-and-report has to catch. Pick deterministically (first
  // kit skill alphabetically) so the fixture is reproducible.
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
    console.error("Usage: node scripts/make-legacy-fixture.mjs --out <dir> [--ref <git-ref>]");
    process.exit(2);
  }

  let commit;
  try {
    commit = git(["rev-parse", opts.ref]).toString("utf8").trim();
  } catch (e) {
    console.error(`make-legacy-fixture: could not resolve ref "${opts.ref}": ${e.message}`);
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
  const kitDir = join(home, ".loup", "selr-ai", "workshop-kit");
  const workspace = join(home, "Desktop", "my-assistant");
  const claudeDir = join(home, ".claude");
  const skillsDir = join(claudeDir, "skills");

  try {
    mkdirSync(workspace, { recursive: true });
    mkdirSync(claudeDir, { recursive: true });

    // Step 2 — the kit, as the Loup install dropped it.
    materializeKit(opts.ref, kitDir);

    // Step 3 — the persona, copied into the workspace (NOT imported globally).
    cpSync(join(kitDir, "my-assistant", "CLAUDE.md"), join(workspace, "CLAUDE.md"));

    // Step 4 — the marker that the new model retires. It must not retrigger
    // orientation after migration; that is one of the things being verified.
    writeFileSync(join(workspace, ".first-run-pending"), "");

    // Step 5 — skills, flat, at the global path.
    const skillCount = installSkills(join(kitDir, "skills"), skillsDir);

    // A pre-existing hand-written global CLAUDE.md, with no pointer block.
    if (opts.globalClaudeMd === "user-content") {
      writeFileSync(
        join(claudeDir, "CLAUDE.md"),
        "# My own global instructions\n\nAlways call me Sam.\nNever send email without asking me first.\n",
      );
    }

    const seeded = opts.pristine ? null : seedUserContent(home, skillsDir);

    // Step 6 — plugin marketplace + routine packager, via the real CLI.
    let pluginsInstalled = false;
    if (opts.plugins) {
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
      builtFrom: { ref: opts.ref, commit },
      options: {
        globalClaudeMd: opts.globalClaudeMd,
        pristine: opts.pristine,
        pluginsRequested: opts.plugins,
      },
      state: { skillCount, pluginsInstalled, seeded },
      // Absences are the point of the fixture — record them so a dry-run can
      // assert the migration created them rather than assuming it did.
      absent: [
        "~/.claude/CLAUDE.md pointer block",
        "~/.claude/selr-assistant.md",
        "selr-kit-manifest.json",
      ],
      run: {
        HOME: home,
        CLAUDE_CONFIG_DIR: claudeDir,
        cwd: workspace,
      },
    };
    writeFileSync(join(out, "FIXTURE.json"), JSON.stringify(record, null, 2) + "\n");

    console.log(`Legacy-install fixture built at ${out}`);
    console.log(`  kit ref        ${opts.ref} (${commit.slice(0, 9)})`);
    console.log(`  skills         ${skillCount} at ~/.claude/skills/`);
    console.log(`  global CLAUDE  ${opts.globalClaudeMd}`);
    console.log(`  plugins        ${pluginsInstalled ? "installed" : "not installed"}`);
    console.log(`  user content   ${opts.pristine ? "none (pristine)" : "seeded"}`);
    console.log("");
    console.log("Dry-run the new setup prompt against it with:");
    console.log("");
    console.log(`  HOME="${home}" \\`);
    console.log(`  CLAUDE_CONFIG_DIR="${claudeDir}" \\`);
    console.log(`  claude --add-dir "${home}"`);
    console.log("");
    console.log(`  (start it in ${workspace} to reproduce the attendee's own starting folder,`);
    console.log(`   or anywhere else to test the "works from any folder" claim)`);
    process.exit(0);
  } catch (e) {
    console.error(`make-legacy-fixture: build failed: ${e.message}`);
    process.exit(1);
  }
}

main();
