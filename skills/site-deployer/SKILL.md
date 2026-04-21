---
name: site-deployer
description: Orchestrate end-to-end website delivery by deciding whether to call site-generator only, site-generator plus nginx-site-manager, or site-generator plus feishu-form-bridge plus nginx-site-manager. Use when the user asks for the final outcome in plain language, such as generating a website, generating a website and configuring a domain, deploying a site online, or generating a website with a form that writes into Feishu and is reachable from a domain. Do not use for standalone Nginx-only tasks or standalone frontend-only edits when no workflow routing is needed.
---

# Site Deployer

Use this skill as the default entry point for website delivery work.

## Global conventions

- Prefer this skill first when the user asks for a website outcome in plain language.
- Keep directories under `/www/sites`.
- Keep site names extremely short, English, and lowercase-hyphen style.
- If a form backend is needed, use a random free local port instead of a fixed port.

## Routing

### 1. Website only
Call:
- `site-generator`

### 2. Website + domain
Call:
- `site-generator`
- `nginx-site-manager`

### 3. Website + form to Feishu + domain
Call:
- `site-generator`
- `feishu-form-bridge`
- `nginx-site-manager`

## Rule

If the user did not explicitly ask for form data to be written into Feishu, do not create the Node backend.

## Default paths

- site output: `/www/sites/<site-name>`
- backend: `/www/sites/<site-name>-server`

## Naming rule

Use concise English names only.
Preferred style:
- lowercase
- short
- words joined with hyphens only when needed

Examples:
- `fuye`
- `coach`
- `resume-lab`

Read `references/workflow-mapping.md` for the compact mapping table.
