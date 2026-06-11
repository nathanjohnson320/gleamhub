# Model & profile mapping

Zoo Code models are **not** configured in `.roomodes` or rule files. They live in **Settings → Providers** as **Configuration Profiles**. Zoo remembers the last profile used per mode ("sticky profiles").

## Profiles

| Profile | Provider | Model | Purpose |
|---------|----------|-------|---------|
| `architect` | Ollama | *(set in Zoo UI)* | Planner — milestones, task breakdown |
| `coding` | Ollama | `qwen3-coder:30b` | Builder — Gleam implementation |
| `default` | Ollama | *(set in Zoo UI)* | Reviewer / general |

Update this table when you change models in Zoo.

## Mode → profile

| Zoo mode | Slash command | Profile | Rules |
|----------|---------------|---------|-------|
| 🏗️ Planner | `/architect` | `architect` | `.roo/rules-architect/` |
| 💻 Builder | `/code` | `coding` | `.roo/rules-code/` |
| 🪲 Reviewer | `/debug` | `default` | `.roo/rules-debug/` |
| 🪃 Orchestrator | `/orchestrator` | *(inherits from subtasks)* | delegates only |

## Setup (one time)

1. **Settings → Providers** — create/configure each profile (provider, model, context size).
2. Switch to each mode and select the matching profile from the **chat API Configuration** dropdown.
3. Zoo remembers per mode after that.

**Do not use Settings → Prompts** for profile switching — that tab is for quick actions (Enhance Prompt, Explain Code, etc.) only.

## Recommendations

- **Builder** needs a strong coder model. Local `qwen3-coder:30b` is fine for experiments; cloud models (Claude Sonnet, GPT-4o) work better for complex agent prompts.
- **Planner** can use a smaller/faster model — planning is markdown-only (`.roo/plan.md`, `.roo/tasks/`).
- **Reviewer** can share the Builder model or use a cheaper one for diff review.

## Ollama: pull models

```bash
ollama pull qwen3-coder:30b    # coding profile
ollama pull qwen3.6:35b-a3b   # architect (if desired)
```

Only models from `ollama list` appear in Zoo's model dropdown.
