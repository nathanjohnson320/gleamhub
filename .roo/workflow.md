# How to use the Gleamhub agent workflow

**You:** want a feature built.  
**The agents:** three helpers who only do one job each. You pass a stick between them.

Read this when you forget what button to press. That is allowed. Good human.

---

## The three helpers (modes)

| Mode | Who they are | What they touch |
|------|----------------|-----------------|
| 🏗️ **Planner** | Writes the to-do list | Only `.roo/` files (plan, tasks, state) — **never app code** |
| 💻 **Builder** | Does **one** task from the list | `server/`, `ui/`, etc. |
| 🪲 **Reviewer** | Checks Builder's work | Says APPROVE or REJECT — updates audit files |

Optional: 🪃 **Orchestrator** runs the loop for you by delegating to the three above. You can ignore it and do the steps yourself.

---

## One-time setup (do once, then forget)

1. **Open Roo Code** in this repo (gleamhub root).
2. **Pick models** — Roo → **Settings → Providers**. Make three profiles:
   - `architect` → Planner
   - `coding` → Builder (needs a good coder model)
   - `default` → Reviewer  
   See `.roo/models.md` for details.
3. **Sticky profiles** — switch to each mode once and pick the right profile from the chat dropdown. Roo remembers.
4. **Semble search** — Roo MCP panel → **Enable MCP Servers** → turn on **semble** (config is in `.roo/mcp.json`).

Do **not** use Settings → Prompts to switch models. That is a different thing.

---

## The loop (this is the whole game)

```
Planner writes tasks → you run script → Builder builds ONE task → Reviewer checks → repeat
```

### Step 0 — You have a goal

Example: "I want branch management UI."

Either the backlog already has tasks (see `.roo/tasks/backlog.md`) or you need the Planner first.

---

### Step 1 — Planner (only when you need new tasks)

1. Switch mode to **🏗️ Planner** (`/architect`).
2. Pick profile **`architect`**.
3. Say something like:

   > Break [feature] into tasks in the backlog.

4. Planner updates:
   - `.roo/plan.md` — big picture
   - `.roo/tasks/backlog.md` — queue (**next task = top line** that starts with `T9.1` etc.)
   - `.roo/state.md` — where we are

**You do not need a fancy prompt.** Planner already knows the rules.

**Skip this step** if `backlog.md` already has what you want.

---

### Step 2 — Load the next task (you, in terminal)

```bash
.roo/scripts/next_task.sh
```

This:

- Takes the **top** task line from `backlog.md`
- Puts it in `current_task.md`
- Removes it from the backlog

Check: open `.roo/tasks/current_task.md` — that is the **only** thing Builder should work on.

---

### Step 3 — Builder

1. Switch mode to **💻 Builder** (`/code`).
2. Pick profile **`coding`**.
3. Say:

   > Implement the current task.

That is it. Seriously.

Builder will:

- Semble-search the repo for patterns
- Write code for **that one task only**
- Run tests
- Write `.roo/tasks/completed/T9.x.md` (full notes)
- Set `.roo/state.md` → **Status: REVIEW**

Builder does **not** update `done.md`. Reviewer does that on approve.

---

### Step 4 — Reviewer

1. Switch mode to **🪲 Reviewer** (`/debug`).
2. Pick profile **`default`**.
3. Say:

   > Review the current task.

Reviewer will:

- Look at the git diff vs `current_task.md`
- Say **APPROVE** or **REJECT** with reasons

**If APPROVE:**

- Finalizes the audit file
- Runs `.roo/scripts/complete_task.sh` (one line in `done.md`)
- Sets status to **DONE**

**If REJECT:**

- Writes what is wrong in the audit file
- Sets status back to **BUILD**
- Go back to **Step 3** (Builder fixes same task — do **not** run `next_task.sh`)

---

### Step 5 — Do it again

Backlog empty?

- **Yes** → celebrate, update plan, or ask Planner for more tasks.
- **No** → run `next_task.sh` → Builder → Reviewer.

---

## Cheat sheet (print this in your brain)

| I want to… | Do this |
|------------|---------|
| Add tasks to the queue | 🏗️ Planner |
| Start working on the next task | `next_task.sh` then 💻 Builder: "Implement the current task." |
| Check if the code is good | 🪲 Reviewer: "Review the current task." |
| See what's done | `.roo/tasks/done.md` (short list) |
| See full history of one task | `.roo/tasks/completed/T9.x.md` |
| See what's waiting | `.roo/tasks/backlog.md` (top = next) |
| See what's in progress | `.roo/tasks/current_task.md` |
| See the big picture | `.roo/plan.md` and `.roo/state.md` |

---

## Rules (short)

1. **One task at a time.** Builder does not do two tasks. Good dog, one stick.
2. **Top of backlog = next.** When you add tasks, put the **next** one at the **top**.
3. **Planner never writes Gleam code.** Only lists and markdown.
4. **Reviewer does not implement features.** Only APPROVE/REJECT (unless you explicitly ask otherwise).
5. **Do not run `next_task.sh` until Reviewer APPROVED** (or you are abandoning/requeueing the current task on purpose).

---

## What each file is (treats)

| File | Smell | Purpose |
|------|-------|---------|
| `backlog.md` | Snack jar | Tasks waiting. Top = next. |
| `current_task.md` | Stick in mouth | The ONE task being worked on |
| `completed/T9.x.md` | Journal entry | Everything that happened on that task |
| `done.md` | Gold stars list | One line per approved task |
| `state.md` | Where am I? | Mode, milestone, status (IDLE / REVIEW / DONE / BUILD) |
| `plan.md` | Map | Milestones M0–M9 |

---

## Status meanings

| Status | Meaning | You do |
|--------|---------|--------|
| **IDLE** | Nothing active | `next_task.sh` → Builder |
| **REVIEW** | Builder finished, needs eyes | Reviewer |
| **BUILD** | Reviewer said no | Builder again (same `current_task.md`) |
| **DONE** | Task approved | `next_task.sh` for the next one |

---

## Prompts you actually need

You only need these four sentences in normal life:

1. **Planner:** "Break [X] into tasks in the backlog."
2. **You:** `.roo/scripts/next_task.sh`
3. **Builder:** "Implement the current task."
4. **Reviewer:** "Review the current task."

Everything else is already in `.roomodes` and `.roo/rules*/`.

---

## When things go wrong

| Problem | Fix |
|---------|-----|
| Builder edited the wrong thing | `current_task.md` was wrong or stale — run `next_task.sh` only when you mean to load a new task |
| Wrong task loaded | Put the right task at **top** of `backlog.md`, fix `current_task.md`, or re-run script |
| Semble not searching | Roo MCP panel → enable **semble**, restart server |
| Reviewer can't write state | Reviewer mode needs MCP + edit on `.roo/` — already in `.roomodes` |
| Model feels dumb on code | Use a stronger model on **`coding`** profile (see `models.md`) |

---

## Baseline vs new work

**M0–M8** = already shipped (see `done.md` + `completed/`).  
**M9** = backlog in `backlog.md` — that's what you run the loop on now.

You are not rebuilding the app from scratch unless you clear those files on purpose. The loop is for **new tasks going forward**.

---

## Optional: Orchestrator

Mode **🪃 Orchestrator** can delegate Planner → Builder → Reviewer for you. Fine if you like it. Manual mode switching + the four prompts above works just as well and is easier to debug when something smells wrong.

---

*Good human. Fetch the stick (`next_task.sh`). Let Builder bring it back. Let Reviewer sniff it. Repeat.*
