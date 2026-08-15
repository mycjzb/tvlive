# TVLive

本仓库**只发布正式二进制与部署脚本**，不含源码。

程序名：`cms-pub`（本机 CMS + 切片源站 + tvapp）。VLC/IPTV 打开：

```text
http://<服务器IP>:9177/tvlive.m3u8
```

绑 Cloudflare 后（推荐）：

```text
https://<你的播放域名>/tvlive.m3u8
```

默认后台登录（装完立刻改密）：

| 项 | 值 |
| --- | --- |
| 地址 | `http://<服务器IP>:9188/cms_admin/` |
| 账号 | `admin` |
| 密码 | `admin888` |

---

## 1. 部署环境

| 项目 | 要求 |
| --- | --- |
| 系统 | Linux **x86_64**（Ubuntu 20.04+ / Debian 11+ / CentOS 7+ / Rocky / Alma） |
| 权限 | root（装 systemd、放行端口） |
| 内存 | 建议 ≥ 2 GB；切片目录默认 `/dev/shm/cms-pub`（内存盘） |
| 磁盘 | 配置与 SQLite 很小；切片走 tmpfs，重启会清空 |
| systemd | 一键脚本依赖 systemd |
| 端口 | **HLS** 默认 8900（后台可改成 80/8080 等给 Cloudflare）· **9177** VLC 列表 / tvapp · **9188** 管理后台 |
| 架构 | 仅 linux/amd64 二进制（容器也要 amd64） |

本机编译的 glibc 版本较高时，**CentOS 7 可能跑不起来**。优先 Ubuntu 22.04 / Debian 12 / Rocky 9。

安全建议：公网只给 Cloudflare 回源 **HLS 端口**（或改用 Tunnel 完全不开放）；**9188 后台不要对全世界开放**。9177 若只给局域网 VLC 用，也可限制来源。

---

## 2. 一键安装（物理机 / 云主机）

```bash
# 方式 A：在线安装
curl -fsSL https://raw.githubusercontent.com/mycjzb/tvlive/main/install.sh | bash

# 方式 B：先克隆本仓库（含二进制）再装
git clone https://github.com/mycjzb/tvlive.git
cd tvlive
sudo bash ./install.sh
```

安装位置：`/opt/tvlive`。服务名：`cms-pub`。

```bash
systemctl status cms-pub
journalctl -u cms-pub -f
```

常用参数（二进制自带）：

```text
./cms-pub -config ./cms-pub.json   前台运行
./cms-pub -d                       守护进程
./cms-pub -stop                    停止
./cms-pub -install / -uninstall    systemd 安装 / 卸载
./cms-pub -passwd NEWPASS          改后台密码后退出
```

浏览器：

- 后台：`http://IP:9188/cms_admin/`
- **默认账号 `admin`，默认密码 `admin888`**（首次登录后立刻改密）
- VLC：媒体 → 打开网络串流 → `http://IP:9177/tvlive.m3u8`
- 网页播放：`http://IP:9177/`

改密（明文新密码，进程会 MD5 后入库）：

```bash
cd /opt/tvlive && ./cms-pub -passwd '你的新密码'
systemctl restart cms-pub
```

---

## 3. 容器部署

需要：Docker + Compose，**linux/amd64**。把本仓库（含 `cms-pub` 二进制）放到服务器后：

```bash
git clone https://github.com/mycjzb/tvlive.git
cd tvlive
docker compose up -d --build
```

默认 `network_mode: host`（与物理机端口相同）。数据卷：`tvlive-data` → 容器 `/data`（`cms-pub.json`、`data.db`）。切片在 tmpfs `/dev/shm/cms-pub`。

macOS Docker 不支持 host 网络：编辑 `docker-compose.yml`，去掉 `network_mode: host`，打开注释里的 `ports`。

后台同样是 `http://IP:9188/cms_admin/`，默认账号 `admin`、密码 `admin888`。

停止 / 看日志：

```bash
docker compose logs -f
docker compose down
```

容器内改密：

```bash
docker exec -it tvlive cms-pub -config /data/cms-pub.json -passwd '新密码'
docker restart tvlive
```

---

## 4. 后台用法（频道 / 分类 / 图标）

1. 打开 `http://IP:9188/cms_admin/`，账号 `admin`、密码 `admin888`（登录后立刻改密）。
2. **节目分类**：建分类（卫视、体育…），可填分类 Logo。
3. **频道列表** → 添加频道：源地址、频道 ID、名称、**频道图标**（`https://...png`）、勾选分类。
   - 源地址若是 **DASH `.mpd`**，下方会出现「MPD 解密密钥」`KID:KEY`（ClearKey）。明文 MPD 可留空。
4. 频道要 **运行中** 才会进 VLC 列表。
5. 页头 **VLC 列表** 可复制 `http://IP:9177/tvlive.m3u8`。
6. 设置 → **EPG 地址**（可选 XMLTV），写入列表头 `x-tvg-url`。

列表格式与常见 IPTV 一致：

```text
#EXTM3U x-tvg-url="https://epg.example.com/t.xml.gz"
#EXTINF:-1 tvg-id="jiangsu" tvg-name="JS-TV" tvg-logo="https://.../js.png" group-title="卫视",江苏卫视
https://播放域名/live/jiangsu.php
```

VLC 左侧按 `group-title` 显示分类；图标来自频道 `tvg-logo`，没填则用分类 Logo。

伪装关闭时播放路径是 `/live/<id>.m3u8`；开启 PNG 伪装则是 `/live/<id>.php`。

---

## 5. Cloudflare 绑定播放域名

观众打开 `https://tv.example.com/tvlive.m3u8`，源站是本机内置 nginx（后台 **设置 → 源站 / 端口** 的 HLS 端口，默认 8900）。

**DNS A 记录本身不能写端口。** 橙云对外永远是 80/443；回源端口要么改成 CF 白名单，要么用 Origin Rule / Tunnel 指定。

先在后台改口并保存（nginx 热加载，防火墙会跟）：

1. 登录 `http://IP:9188/cms_admin/` → **设置 → 源站 / 端口**
2. 点快捷端口或手填，保存
3. 再去 **对外 URL** 填流域名、tvapp 域名（见 5.4）

下面三种绑法选一种即可。

### 5.1 方案 A：A 记录橙云 + 源站用兼容端口（最常见）

Cloudflare **已代理（橙云）** 回源 HTTP **只认**这些口：

`80` · `8080` · `8880` · `2052` · `2082` · `2086` · `2095`

默认 **8900 不在名单里**，橙云会打不通。把 HLS 端口改成 **8080**（或 80，需 root）。

1. Cloudflare 添加站点，域名 NS 指到 CF。
2. DNS → 添加记录：
   - 类型：**A**
   - 名称：`tv`（完整名 `tv.example.com`）或 `@`（根域）
   - IPv4：**服务器公网 IP**（不要填端口）
   - 代理状态：**已代理（橙色云朵）**
3. SSL/TLS → 加密模式：**Flexible**（源站 HTTP）即可。源站若自己上 443 证书可用 Full。
4. 云厂商安全组 / 本机防火墙放行该 HLS 端口（建议只放 [Cloudflare IP 段](https://www.cloudflare.com/ips/)）。
5. 后台「源站 / 端口」选 `8080` 并保存。

验证：

```bash
curl -I http://服务器IP:8080/tvlive.m3u8
curl -I https://tv.example.com/tvlive.m3u8
```

第二条应有 `cf-cache-status` 和 CORS。

### 5.2 方案 B：A 记录橙云 + Origin Rule 指定回源端口

源站继续用 **8900**（或任意口），让 CF 回源时改打这个端口。

1. DNS 仍按 5.1 做 **A + 橙云 + 公网 IP**（记录里仍然没有端口）。
2. Cloudflare → **规则 → Origin Rules** → 创建规则，例如：
   - 条件：Hostname 等于 `tv.example.com`
   - 动作：**Destination Port**（目标端口）= `8900`
3. SSL/TLS：**Flexible**
4. 安全组放行 **8900**（仅 CF IP 更稳）
5. 后台 HLS 端口保持 8900

适合不想改监听口、套餐又支持 Origin Rule 的情况。

灰云（DNS only）时浏览器必须写端口：`http://tv.example.com:8900/tvlive.m3u8`，没有 CF 缓存/HTTPS，只适合临时排障。

### 5.3 方案 C：Cloudflare Tunnel（不开放公网端口）

机器在 NAT 后面、或不想把 80/8080/8900 打到公网时用隧道。CF 边缘连上 `cloudflared`，再转到本机 `127.0.0.1:HLS端口`。

1. 在 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → Networks → Tunnels → Create，记下 Token。
2. 源站安装并登录（Ubuntu 示例）：

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
sudo cloudflared service install <你的TUNNEL_TOKEN>
```

3. 隧道 Public Hostname：
   - Subdomain：`tv`　Domain：`example.com`
   - Type：`HTTP`
   - URL：`http://127.0.0.1:8900`（**改成后台当前 HLS 端口**，例如改成 8080 就填 `http://127.0.0.1:8080`）
4. Cloudflare 会自动加 CNAME，**不要再给这个主机名做橙云 A 到源站 IP**（会和隧道抢）。
5. SSL 用 CF 默认即可。本机安全组可以不开放 HLS 端口。

`~/.cloudflared/config.yml` 手写等价配置：

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: tv.example.com
    service: http://127.0.0.1:8900
  - service: http_status:404
```

然后 `cloudflared tunnel route dns <TUNNEL_ID> tv.example.com` 与 `cloudflared tunnel run`。

### 5.4 后台填流域名 / tvapp 域名（三种方案都要）

**设置 → 对外 URL**：

| 字段 | 填什么 |
| --- | --- |
| 流域名 | `https://hs.example.com`（HLS / 预热 / VLC 列表里每条频道） |
| tvapp 域名 | `https://play.example.com`（网页播放器，回源 9177） |

保存后频道 URL 为 `https://hs.example.com/live/<id>.php`（伪装关闭则 `.m3u8`）。

列表同时写在源站根路径：

```text
https://hs.example.com/tvlive.m3u8
```

网页播放器：

```text
https://play.example.com/
```

源站已带 CORS 与缓存头（列表约 2 秒、切片 7 天），橙云按源站 `Cache-Control` 即可，一般不用 Page Rule。tvapp 域名另做一条 DNS/Tunnel 回源 **9177**，不要和流域名共用 HLS 口。

### 5.5 验证

```bash
curl -I https://hs.example.com/tvlive.m3u8
curl -I https://hs.example.com/live/<频道ID>.php
```

应看到 `cf-cache-status` 与 CORS。VLC 打开该 https 列表，能看到分类、图标、可播。

---

## 6. 自动预热怎么开

预热 = 新切片先写盘、**暂不进播放列表**，同时对 **流域名** 发 GET，让 Cloudflare 边缘先缓存，再把片放进 m3u8。观众就不会打到冷源。

要同时满足：

1. **设置 → 切片 / 预热**
   - 预热延迟（片）≥ 1（默认 3）。延迟 0 = 不等边缘，等于没预热窗口。
2. **每个频道**「CDN 预热」= 开启（添加频道时可关）。
3. **流域名** 填 Cloudflare 的 HLS 域名（见上一节）。留空则不会对外 GET，预热不生效。

原理简述：切片进列表前，进程对  
`https://tv.example.com/live/<频道ID>/<文件>.png`（或 `.ts`）发最多 3 次 GET。全局 `prewarm` 默认开；频道开关可单独关掉。

改切片参数或流域名后，正在运行的频道会按新配置重启。

---

## 7. 配置文件要点

路径：`/opt/tvlive/cms-pub.json`（容器：`/data/cms-pub.json`）。首次运行自动生成。

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `cms_port` | 9188 | 后台 |
| `tvapp_port` | 9177 | tvapp + VLC 列表 |
| `http_port` | 8900 | HLS nginx（后台「源站 / 端口」可改，保存即热加载） |
| `play_domain` | 空 | 流域名（HLS / 预热） |
| `public_base_url` | 空 | tvapp 网页播放器域名 |
| `epg_url` | 空 | XMLTV，后台设置可改 |
| `prewarm` | true | 全局预热 |
| `list_delay` | 3 | 预热窗口（片数） |
| `mem_dir` | `/dev/shm/cms-pub` | 切片目录（内存） |
| `db_driver` / `db_dsn` | sqlite / `data.db` | 本机 SQLite；正式可改 mysql |

改完 json 后 `systemctl restart cms-pub`。日常改域名/预热/伪装用后台设置页即可。

---

## 8. 常见问题

**默认账号密码是什么？**  
账号 `admin`，密码 `admin888`。后台地址 `http://IP:9188/cms_admin/`。装完立刻改密：`./cms-pub -passwd '新密码'`（容器见 §3）。

**VLC 能看到频道但播不了**  
列表地址是 9177（或 tvapp 域名），真正的流在 HLS 端口（默认 8900）或流域名。检查频道是否运行中、源地址能否拉到、**流域名**是否填成观众能访问的 HLS 地址。橙云打不通时先看端口是否在 CF 白名单（见 §5.1）。

**没有分类**  
频道要勾选「节目分类」。未勾选的进「未分类」。停用的分类不会出现。

**没有图标**  
频道图标填 `https://` 图片；不填则用分类 Logo。VLC 对部分 PNG/SVG 支持不一，优先小尺寸 PNG。

**预热不生效**  
流域名必须是 CF 的 https 域名；频道预热开关要开；`list_delay` 不要为 0。

**CentOS 跑不起来**  
换 Ubuntu 22+ / Debian 12，或用本仓库 Docker（debian bookworm）。

---

禁止提交：`cms-pub.json`、`data.db`、日志、pid、密钥。本仓库只跟踪二进制与脚本。
