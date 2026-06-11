# How This Was Built

**This is the only fully human-written file in the repo.** Everything else was produced or heavily edited by agents (Roo/Zoo).

## The idea

Github keeps going down lately. Like literally every other day at least. So I was like, you know what, what if I just built a github. I like gleam and use it regularly for contract / hobby projects but never really did the whole agentic workflow with it. So that's what I set out to do. Rebuild github but with gleam and memes.

The starting point was my own [gleam_wisp_lustre_template](https://github.com/nathanjohnson320/gleam_wisp_lustre_template): Clerk auth, a Wisp API, and a Lustre/Vite UI already wired together via a fork I have (current version doesn't have the clerk stuff that's privy). Gleamhub then forked that shell and grew outward with `git-ssh/`, Postgres, merge requests, CI worker, and the rest.

## How'd you get to this monstrosity of rule files

First off, I didn't want to spend a bajillion dollars on cursor and claude bucks. Those keep getting more and more expensive and I'm pretty sure if I rolled this out with either of those it would be $200-4000. Recently bought an old mac studio to host other small LLM projects on and so I figured I'd try doing the whole stack on that.

Also, building a full web app is a long tail of small, similar tasks. A route, a SQL migration, a Lustre page, a hook, tests blah blah blah rinse repeat. Doing this manually is tedious and using cursor or claude with a single long chat session tends to drift, context gets fuzzy, and the model starts "helpfully" redesigning things you already decided. With that in mind I had started by breaking this down into smaller units of work like I would for my normal day to day. In my normal day I pull up a jira, implement the jiras main context, then implement tests, then put up a PR and code review. I don't do TDD anymore not saying it's bad it's just not how I operate. But with this setup I ended up with the 3 main roles and one driver role.

- **Planner** only plans (markdown in `.roo/`, never app code).
- **Builder** only implements **one** task from `current_task.md`.
- **Reviewer** only approves or rejects against that task.
- **Orchestrator** runs the above three in sequence.

The human (me) runs a short script to advance the queue and switches modes. That's the whole loop. It's manual because I am too scared to let the AI fully drive which I know is probably bad but OH WELL but quite literally at one point when testing the git flow it nuked .git and force pushed because it thought that was the only way to fix pre commit hooks :facepalm: so pardon me if my fears are unjustified.

## How the workflow is implemented in Roo/Zoo

[Roo Code](https://github.com/RooCodeInc/Roo-Code) (I use "Zoo" interchangeably in config zoo is the forked version) supports **custom modes**: each mode gets its own system prompt, tool permissions, and rule files. Gleamhub's modes are defined in [`.roomodes`](.roomodes) at the repo root.

### Three helpers (+ one optional)

| Mode | Roo slug | What it may edit |
|------|----------|------------------|
| 🏗️ Planner | `/architect` | `.roo/plan.md`, `.roo/state.md`, `.roo/tasks/*.md` (backlog only not `done.md` or `completed/`) |
| 💻 Builder | `/code` | Application source (`server/`, `ui/`, etc.) |
| 🪲 Reviewer | `/debug` | Audit logs and workflow state on approve/reject |
| 🪃 Orchestrator | `/orchestrator` | Delegates to the three above; does not write app code |

Permissions are enforced in `.roomodes` via **file-regex edit groups** e.g. Planner literally cannot save a `.gleam` file, and Builder cannot rewrite the backlog. That matters more than polite instructions in the prompt.

### Rule files (what each mode "knows")

Rules live under `.roo/` and load per mode:

| Path | Loaded by | Purpose |
|------|-----------|---------|
| [`.roo/rules/01-context.md`](.roo/rules/01-context.md) | All modes | Repo layout, stack, conventions, pointer to workflow |
| [`.roo/rules-architect/`](.roo/rules-architect/) | Planner | Planning process, architecture constraints |
| [`.roo/rules-code/`](.roo/rules-code/) | Builder | Wisp routes, Lustre UI, Squirrel/pog SQL, BEAM/CI patterns |
| [`.roo/rules-debug/`](.roo/rules-debug/) | Reviewer | Review checklist and testing expectations |

Shared context in `01-context.md` stops every mode from re-deriving "what is Gleamhub." Mode-specific dirs keep the Builder from reading a novel about milestone planning and the Planner from pretending it knows Wisp handler patterns.

### Task files

Work is tracked as plain markdown, not tickets in Jira:

| File | Role |
|------|------|
| `.roo/tasks/backlog.md` | Queue; **top line = next** |
| `.roo/tasks/current_task.md` | The one task in flight |
| `.roo/tasks/completed/T{n}.{m}.md` | Full audit log per task |
| `.roo/tasks/done.md` | One-line index of approved tasks |
| `.roo/state.md` | Current mode and status (`IDLE` / `BUILD` / `REVIEW` / `DONE`) |

Shell scripts glue the human step to the files:

- `.roo/scripts/next_task.sh` pop backlog -> `current_task.md`
- `.roo/scripts/complete_task.sh` append to `done.md` after Reviewer approves

Task IDs look like `T5.3` (milestone 5, task 3). The format is one line in the backlog: verb, outcome, and usually target files.

### Models and code search

[`.roo/models.md`](.roo/models.md) maps Zoo provider profiles to modes (`architect`, `coding`, `default`). Stronger models on the Builder profile matter; Planner and Reviewer can run lighter.

[`.roo/mcp.json`](.roo/mcp.json) enables **Semble** semantic search for all modes that need to read code. Builder and Reviewer are instructed to search before editing or judging diffs it beats blind grep on a repo this size.

## What a typical iteration looks like

1. **Planner** "Break [feature] into tasks in the backlog." Updates `plan.md`, `backlog.md`, `state.md`.
2. **Human** run `next_task.sh`.
3. **Builder** "Implement the current task." Code, tests, audit file in `completed/`, state -> `REVIEW`.
4. **Reviewer** "Review the current task." `APPROVE` (index in `done.md`, state -> `DONE`) or `REJECT` (state -> `BUILD`, same `current_task.md`).
5. Repeat until the backlog is empty.

Prompts stay boring on purpose. The rules and file boundaries do the heavy lifting.

## What was I able to build

M0–M8 (auth through releases, MRs, CI, notifications) were built task-by-task through this loop. Each approved task left a trail in `.roo/tasks/completed/` — implementation notes, files touched, tests run which is how you audit agent work without re-reading every commit.

M9 and beyond are whatever remains in `.roo/tasks/backlog.md`. Unfinished things I may do later but who knows.

## If you're trying this yourself

First off, don't. This local agentic stuff is not near where it needs to be for a normal person to run it properly. If you're going enterprise just use your company's cursor/claude bucks. But if you're crazy and have an itch to tinker or hack on things like me then by all means go ahead fork and experiment with this setup.

1. Read [`.roo/workflow.md`](.roo/workflow.md) for the cheat sheet.
2. Copy the **mode split** and **one-task-at-a-time** discipline before copying file names.
3. Lock down **edit permissions** in `.roomodes` so roles cannot bleed into each other.
4. Keep human prompts short; invest in **rules** that describe your stack and patterns.
5. Treat `completed/` audit files as the source of truth for "what did the agent actually do?"

The Gleam stack (Wisp, Lustre, pog, Squirrel, git-ssh, Dagger CI) is documented in the README and in `.roo/rules/`. The workflow is stack-agnostic it just happened to be the lever that made a Gleam Git host feasible for one person with a queue and three modes.
