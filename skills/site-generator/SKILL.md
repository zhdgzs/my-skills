---
name: site-generator
description: Generate or revise static website files by delegating the frontend build work to ui-ux-pro-max, then place the output under /www/sites by default. Use only for pure website generation tasks, such as creating a landing page, official site, single-page site, or marketing page, when the user wants the site files themselves and has not asked for domain binding, Nginx config, Node backend, pm2, or Feishu form storage.
---

# Site Generator

Generate website files only.

## Core rules

- Call `ui-ux-pro-max` for the actual site generation work.
- Unless the user explicitly asks otherwise, place the final output under `/www/sites/<site-name>`.
- Treat `/www/sites/<site-name>` as the default static site root.
- Use concise English site names in lowercase-hyphen style.

## Inputs

Collect or infer:
- site name
- site purpose
- target audience
- style direction
- required sections

If the user already gave enough direction, do not re-ask unnecessarily.

## Out of scope

Do not do these things here:
- Nginx or domain config
- Node backend creation
- pm2 setup
- Feishu form storage setup

Use `references/output-layout.md` only for default path conventions.
