# pm2 and validation

## pm2 naming

Use:

```text
<site-name>-server
```

## Typical commands

```bash
cd /www/sites/<site-name>-server
pm2 start server.js --name <site-name>-server
pm2 save
pm2 list
pm2 logs <site-name>-server
pm2 restart <site-name>-server
```

## Validation

Check:
- local `http://127.0.0.1:<chosen-port>/api/health`
- if Nginx is configured, public `https://<domain>/api/health`
- one real submit creates a Feishu record
