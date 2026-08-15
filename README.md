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

默认后台账号：`admin` / `admin888`（装完立刻改密）。

---

## 1. 部署环境

| 项目 | 要求 |
| --- | --- |
| 系统 | Linux **x86_64**（Ubuntu 20.04+ / Debian 11+ / CentOS 7+ / Rocky / Alma） |
| 权限 | root（装 systemd、放行端口） |
| 内存 | 建议 ≥ 2 GB；切片目录默认 `/dev/shm/cms-pub`（内存盘） |
| 磁盘 | 配置与 SQLite 很小；切片走 tmpfs，重启会清空 |
| systemd | 一键脚本依赖 systemd |
| 端口 | **8900** HLS 源站（Cloudflare 回源）· **9177** VLC 列表 / tvapp / Tracker · **9188** 管理后台 |
| 架构 | 仅 linux/amd64 二进制（容器也要 amd64） |

本机编译的 glibc 版本较高时，**CentOS 7 可能跑不起来**。优先 Ubuntu 22.04 / Debian 12 / Rocky 9。

安全建议：公网只给 Cloudflare 回源 **8900**；**9188 后台不要对全世界开放**（安全组只放你的办公 IP）。9177 若只给局域网 VLC 用，也可限制来源。

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
cd /opt/tvlive && ./cms-pub -passwd '你的新密码'
systemctl restart cms-pub
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
- VLC：媒体 → 打开网络串流 → `http://IP:9177/tvlive.m3u8`
- 网页播放：`http://IP:9177/`

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

1. 登录后台 → **节目分类**：建分类（卫视、体育…），可填分类 Logo。
2. **频道列表** → 添加频道：源地址、频道 ID、名称、**频道图标**（`https://...png`）、勾选分类。
3. 频道要 **运行中** 才会进 VLC 列表。
4. 页头 **VLC 列表** 可复制 `http://IP:9177/tvlive.m3u8`。
5. 设置 → **EPG 地址**（可选 XMLTV），写入列表头 `x-tvg-url`。

列表格式与常见 IPTV 一致：

```text
#EXTM3U x-tvg-url="https://epg.example.com/t.xml.gz"
#EXTINF:-1 tvg-id="jiangsu" tvg-name="JS-TV" tvg-logo="https://.../js.png" group-title="卫视",江苏卫视
https://播放域名/live/jiangsu.php
```

VLC 左侧按 `group-title` 显示分类；图标来自频道 `tvg-logo`，没填则用分类 Logo。

伪装关闭时播放路径是 `/live/<id>.m3u8`；开启 PNG 伪装则是 `/live/<id>.php`。

---

## 5. 绑定 Cloudflare 域名

目标：观众走 `https://tv.example.com/...`，源站仍是这台机器的 **8900**。

### 5.1 DNS

1. Cloudflare 添加站点，把域名 NS 指到 CF。
2. 添加 **A 记录**：
   - 名称：`tv`（或 `@`）
   - IPv4：服务器公网 IP
   - 代理状态：**已代理（橙云）**
3. SSL/TLS 建议 **Full**（源站若只开 HTTP 8900，用 **Flexible** 也能通，但不如源站自备证书稳）。

### 5.2 源站端口

Cloudflare 橙云对外是 80/443。回源默认打你记录的 IP:**80**。本程序 HLS 在 **8900**，任选其一：

- **推荐**：本机 nginx/防火墙把 `80 → 8900`（或源站监听 80，需 root，改 `cms-pub.json` 的 `http_port`）。
- 或 Cloudflare **源站规则 / Transform** 把回源端口改成 8900（视你的 CF 套餐而定）。
- 或用 Cloudflare Spectrum / 灰色云 + 自备 443（本程序 `https_port`）。

安全组：只允许 **Cloudflare IP 段** 访问 8900，避免源站 IP 被扫。

### 5.3 后台填域名（必须）

登录后台 → **设置 → 对外 URL**：

| 字段 | 填什么 |
| --- | --- |
| CDN 域名 | `https://tv.example.com`（预热走这条，必须是 CF 域名） |
| 对外访问前缀 | `https://tv.example.com`（VLC 列表里每条频道的播放地址） |

保存后列表里的频道 URL 会变成 `https://tv.example.com/live/<id>.php`（或 `.m3u8`）。

同一份列表也会写到源站根路径，绑 CF 后可直接：

```text
https://tv.example.com/tvlive.m3u8
```

源站已输出 CORS 与缓存头：播放列表约 2 秒，切片 7 天。CF 橙云按源站 `Cache-Control` 缓存即可，一般**不用再加 Page Rule**。

### 5.4 验证

```bash
curl -I https://tv.example.com/tvlive.m3u8
curl -I https://tv.example.com/live/<频道ID>.php
```

应看到 CF 命中头（`cf-cache-status`）以及源站 CORS。VLC 打开该 https 列表，能看到分类、图标、可播。

---

## 6. 自动预热怎么开

预热 = 新切片先写盘、**暂不进播放列表**，同时对 **CDN 域名** 发 GET，让 Cloudflare 边缘先缓存，再把片放进 m3u8。观众就不会打到冷源。

要同时满足：

1. **设置 → 切片 / 预热**
   - 预热延迟（片）≥ 1（默认 3）。延迟 0 = 不等边缘，等于没预热窗口。
2. **每个频道**「CDN 预热」= 开启（添加频道时可关）。
3. **CDN 域名** 填 Cloudflare 播放域名（见上一节）。留空则不会对外 GET，预热不生效。

原理简述：切片进列表前，进程对  
`https://tv.example.com/live/<频道ID>/<文件>.png`（或 `.ts`）发最多 3 次 GET。全局 `prewarm` 默认开；频道开关可单独关掉。

改切片参数或 CDN 域名后，正在运行的频道会按新配置重启。

---

## 7. 配置文件要点

路径：`/opt/tvlive/cms-pub.json`（容器：`/data/cms-pub.json`）。首次运行自动生成。

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `cms_port` | 9188 | 后台 |
| `tvapp_port` | 9177 | tvapp + VLC 列表 |
| `http_port` | 8900 | HLS nginx |
| `play_domain` | 空 | CF 域名，预热用 |
| `public_base_url` | 空 | 列表/播放前缀 |
| `epg_url` | 空 | XMLTV，后台设置可改 |
| `prewarm` | true | 全局预热 |
| `list_delay` | 3 | 预热窗口（片数） |
| `mem_dir` | `/dev/shm/cms-pub` | 切片目录（内存） |
| `db_driver` / `db_dsn` | sqlite / `data.db` | 本机 SQLite；正式可改 mysql |

改完 json 后 `systemctl restart cms-pub`。日常改域名/预热/伪装用后台设置页即可。

---

## 8. 常见问题

**VLC 能看到频道但播不了**  
列表地址是 9177，真正的流在 8900 或 CF 域名。检查频道是否运行中、源地址能否拉到、`public_base_url` 是否填成观众能访问的地址。

**没有分类**  
频道要勾选「节目分类」。未勾选的进「未分类」。停用的分类不会出现。

**没有图标**  
频道图标填 `https://` 图片；不填则用分类 Logo。VLC 对部分 PNG/SVG 支持不一，优先小尺寸 PNG。

**预热不生效**  
CDN 域名必须是 CF 的 https 域名；频道预热开关要开；`list_delay` 不要为 0。

**CentOS 跑不起来**  
换 Ubuntu 22+ / Debian 12，或用本仓库 Docker（debian bookworm）。

---

禁止提交：`cms-pub.json`、`data.db`、日志、pid、密钥。本仓库只跟踪二进制与脚本。
