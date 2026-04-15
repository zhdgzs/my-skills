---
name: feishu-form-bridge
description: Create and manage a Node form backend that accepts website form submissions and writes them into Feishu, then run it with pm2. Use only when the user explicitly asks for a website form to submit into Feishu, a Node /api submit endpoint, a form bridge, or form data storage in Feishu. Do not use for pure website generation, pure domain binding, or generic Nginx work.
---

# Feishu Form Bridge

Create the backend only when the user explicitly wants form submission data stored in Feishu.

## Core rules

- Create a small Node backend.
- Expose `/api/submit` and `/api/health`.
- Store runtime config in `config.json`.
- Run the service with pm2.
- Unless the user explicitly asks otherwise, use `/www/sites/<site-name>-server`.
- Use pm2 process name `<site-name>-server`.
- Choose a random free local port.
- Do not reuse a port that is already occupied.
- Write the chosen port into runtime config and pass that upstream value to Nginx.
## Out of scope

Do not do these things here:
- frontend site generation
- Nginx config
- domain binding

## Validation

Always verify:
- local `/api/health`
- one real submit path
- successful Feishu write

Read:
- `references/backend-contract.md`
- `references/pm2-and-validation.md`
