# Workflow mapping

## Routing table

### Website only
User intent examples:
- 生成网站
- 做个官网
- 做个落地页

Call:
- `site-generator`

### Website + domain
User intent examples:
- 生成网站并配置域名
- 做个官网并绑定域名

Call:
- `site-generator`
- `nginx-site-manager`

### Website + form + Feishu + domain
User intent examples:
- 做个带表单的网站并把数据记到飞书
- 生成网站并配置域名，表单提交到飞书

Call:
- `site-generator`
- `feishu-form-bridge`
- `nginx-site-manager`

## Required inputs

At minimum try to infer or collect:
- site name
- domain if domain setup is requested
- whether form-to-Feishu is explicitly required
- site content / style direction
