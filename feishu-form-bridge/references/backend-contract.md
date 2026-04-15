# Backend contract

## Purpose

Expose a small Node backend that accepts form submissions from a website and writes the data into Feishu.

## Default runtime

- bind `127.0.0.1:<random-free-port>`
- choose a random free local port that does not conflict with existing services
- expose:
  - `GET /api/health`
  - `POST /api/submit`
- store runtime config in `config.json`
- reuse or create Feishu resources as needed

## Default path

```text
/www/sites/<site-name>-server
```

## Files

Required by default:
- `server.js`
- `config.json`

## Important rule

Do not create this backend unless the user explicitly asked for form submission into Feishu.
