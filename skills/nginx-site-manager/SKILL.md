---
name: nginx-site-manager
description: Create or update Nginx site configs under /etc/nginx/conf.d for domain bindings, reverse proxies, and static-site serving using the host's existing house style. Use only when the task is specifically about Nginx or domain configuration, such as binding a domain to a site, adding or modifying reverse proxy rules, serving a static directory, or generating an xxx.conf file and validating or reloading Nginx. Do not use for frontend generation or Feishu form backend creation.
---

# Nginx Site Manager

Use the host's existing `/etc/nginx/conf.d/*.conf` style as the default house style unless the user explicitly asks for something else.

## Core rules

- Write one file per site: `/etc/nginx/conf.d/<name>.conf`
- Match the existing local formatting and TLS/header conventions
- Reuse the local shared certificate paths by default
- Treat backend upstream ports as input values from the caller; do not assume a fixed port.
- Support these common modes:
  - full-site reverse proxy
  - static site root
  - static site + `/api/` reverse proxy

## Apply order

1. Generate the full conf content.
2. Sanity-check `server_name`, log name, and `root` or `proxy_pass`.
3. Write `/etc/nginx/conf.d/<name>.conf`.
4. Run `nginx -t`.
5. Run `nginx -s reload` only if validation passes.

## Notes

- Do not invent extra redirects, HTTP blocks, gzip, cache rules, or HSTS unless the user asks.
- For static site + API proxy setups, use the local pattern of server-level `root` plus `location ^~ /api/ { ... }`.
- If overwriting an unrelated existing site file is possible, pause and confirm.

Read `references/templates.md` and start from the closest template.
