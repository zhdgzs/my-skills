# Site Generator Output Layout

## Default path

Place generated site files at:

```text
/www/sites/<site-name>
```

## Notes

- Treat the directory as the final static site root unless the user asks for a different layout.
- If the generator emits a build directory, copy or publish the final built assets into `/www/sites/<site-name>`.
- Do not create companion backend directories here.
- Do not create Nginx config here.

## Handoffs

If the user asks for a domain:
- call `nginx-site-manager`

If the user asks for Feishu form submission:
- call `feishu-form-bridge`

If the user asks for both generation and deployment:
- call `site-deployer`
