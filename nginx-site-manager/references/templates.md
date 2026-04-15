# Nginx local templates

Use these templates as the starting point and substitute the placeholders.

## 1) Full-site reverse proxy

```nginx
server {
    listen      443 ssl;

    server_name {{DOMAIN}};

    access_log  /www/wwwlogs/{{NAME}}.access.log main;
    error_log  /www/wwwlogs/{{NAME}}.error.log;

    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404; 
    }
    if ( $uri ~ "^/\.well-known/.*\.(php|jsp|py|js|css|lua|ts|go|zip|tar\.gz|rar|7z|sql|bak)$" ) {
        return 403; 
    }
    ssl_certificate /opt/proxy/150524/cert.crt;
    ssl_certificate_key /opt/proxy/150524/cert.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_http_version 1.1;

        proxy_pass http://127.0.0.1:{{PORT}};
    }
    
}
```

## 2) Static site only

```nginx
server {
    listen      443 ssl;

    server_name {{DOMAIN}};

    root {{ROOT_PATH}};
    index index.html index.htm default.htm default.html;

    access_log  /www/wwwlogs/{{NAME}}.access.log main;
    error_log  /www/wwwlogs/{{NAME}}.error.log;

    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404; 
    }
    if ( $uri ~ "^/\.well-known/.*\.(php|jsp|py|js|css|lua|ts|go|zip|tar\.gz|rar|7z|sql|bak)$" ) {
        return 403; 
    }

    ssl_certificate /opt/proxy/150524/cert.crt;
    ssl_certificate_key /opt/proxy/150524/cert.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_prefer_server_ciphers on;
    
}
```

## 3) Static site + /api/ reverse proxy

```nginx
server {
    listen      443 ssl;

    server_name {{DOMAIN}};

    root {{ROOT_PATH}};
    index index.html index.htm default.htm default.html;

    access_log  /www/wwwlogs/{{NAME}}.access.log main;
    error_log  /www/wwwlogs/{{NAME}}.error.log;

    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404; 
    }
    if ( $uri ~ "^/\.well-known/.*\.(php|jsp|py|js|css|lua|ts|go|zip|tar\.gz|rar|7z|sql|bak)$" ) {
        return 403; 
    }

    ssl_certificate /opt/proxy/150524/cert.crt;
    ssl_certificate_key /opt/proxy/150524/cert.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_prefer_server_ciphers on;
    
    location ^~ /api/ {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_http_version 1.1;

        proxy_pass http://127.0.0.1:{{API_PORT}}/;
    }
}
```

## Placeholder rules

- `{{NAME}}`: conf file base name, e.g. `fuye`
- `{{DOMAIN}}`: full domain, e.g. `fuye.150524.xyz`
- `{{ROOT_PATH}}`: static site directory, e.g. `/www/sites/fuye`
- `{{PORT}}`: upstream port for full reverse proxy
- `{{API_PORT}}`: upstream API port for `/api/`

## Apply commands

```bash
nginx -t
nginx -s reload
```

If `nginx -t` fails, fix the file before reloading.
