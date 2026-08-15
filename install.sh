#!/usr/bin/env bash
# TVLive 一键安装：下载正式二进制到 /opt/tvlive，生成默认配置，安装 systemd。
# 用法（root）：
#   curl -fsSL https://raw.githubusercontent.com/mycjzb/tvlive/main/install.sh | bash
# 或：
#   git clone https://github.com/mycjzb/tvlive.git && cd tvlive && bash ./install.sh
set -euo pipefail

REPO_RAW="${TVLIVE_RAW:-https://raw.githubusercontent.com/mycjzb/tvlive/main}"
DEST="${TVLIVE_DIR:-/opt/tvlive}"
die() { echo "错误: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[ "$(id -u)" -eq 0 ] || die "请用 root 运行（sudo bash install.sh）"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64|Linux-amd64) ;;
  *) die "仅支持 Linux x86_64。当前: $(uname -s) $(uname -m)" ;;
esac

command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || die "需要 curl 或 wget"
command -v systemctl >/dev/null 2>&1 || die "需要 systemd"

mkdir -p "$DEST"
cd "$DEST"

fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 -o "$out" "$url"
  else
    wget -O "$out" "$url"
  fi
}

if [ -x "$DEST/cms-pub" ] && [ "${TVLIVE_FORCE:-0}" != "1" ] && [ -f "$(dirname "$0")/cms-pub" ]; then
  # 从 git clone 目录执行时，优先用旁边的二进制
  SRC="$(cd "$(dirname "$0")" && pwd)"
  if [ "$SRC" != "$DEST" ]; then
    log "从本地目录复制二进制: $SRC/cms-pub"
    cp -f "$SRC/cms-pub" "$DEST/cms-pub"
    chmod +x "$DEST/cms-pub"
  fi
elif [ -f "$(dirname "$0")/cms-pub" ] && [ -x "$(dirname "$0")/cms-pub" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
  if [ "$SRC" != "$DEST" ]; then
    log "从本地目录复制二进制: $SRC/cms-pub"
    cp -f "$SRC/cms-pub" "$DEST/cms-pub"
  fi
  chmod +x "$DEST/cms-pub"
else
  log "下载二进制 $REPO_RAW/cms-pub"
  fetch "$REPO_RAW/cms-pub" "$DEST/cms-pub"
  chmod +x "$DEST/cms-pub"
fi

[ -x "$DEST/cms-pub" ] || die "二进制不可执行"

if [ ! -f "$DEST/cms-pub.json" ]; then
  log "首次生成默认配置 cms-pub.json"
  (cd "$DEST" && ./cms-pub -config ./cms-pub.json) || true
  [ -f "$DEST/cms-pub.json" ] || die "未能生成 cms-pub.json"
fi

log "安装 systemd 服务 cms-pub 并启动"
(cd "$DEST" && ./cms-pub -config "$DEST/cms-pub.json" -install)

open_port() {
  local p="$1"
  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1 || true
  elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi active; then
    ufw allow "${p}/tcp" >/dev/null 2>&1 || true
  elif command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport "$p" -j ACCEPT >/dev/null 2>&1 || \
      iptables -I INPUT -p tcp --dport "$p" -j ACCEPT || true
  fi
}

log "放行 TCP 8900(HLS) 9177(VLC列表/tvapp) 9188(后台)"
open_port 8900
open_port 9177
open_port 9188
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$IP" ] || IP="服务器公网IP"

cat <<EOF

安装完成。工作目录: $DEST

  后台:     http://${IP}:9188/cms_admin/     账号 admin / admin888（立刻改密）
  VLC列表:  http://${IP}:9177/tvlive.m3u8
  HLS源站:  http://${IP}:8900/live/<频道ID>.php
  tvapp:    http://${IP}:9177/

改密:  cd $DEST && ./cms-pub -passwd '新密码' && systemctl restart cms-pub
停止:  systemctl stop cms-pub   或  $DEST/cms-pub -stop
卸载:  $DEST/cms-pub -uninstall

请阅读仓库 README：Cloudflare 绑域名、自动预热、容器部署。
EOF
