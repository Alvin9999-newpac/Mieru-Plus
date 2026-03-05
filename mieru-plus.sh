#!/usr/bin/env bash
# ============================================================
#  Mieru 管理脚本 v1.0.0
#  项目地址：https://github.com/Alvin9999-newpac/Mieru-Plus
# ============================================================

set -Eeuo pipefail
stty erase ^H 2>/dev/null || true

# ──────────── 颜色 ────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; PLAIN='\033[0m'

ok()   { echo -e " ${GREEN}[OK]${PLAIN}  $*"; }
warn() { echo -e " ${YELLOW}[!!]${PLAIN}  $*"; }
err()  { echo -e " ${RED}[ERR]${PLAIN} $*"; }
info() { echo -e " ${CYAN}--${PLAIN}   $*"; }

press_enter() { echo; read -rp " 按 Enter 返回主菜单..." _; }

# ──────────── 常量 ────────────
CRED_FILE="/etc/mita/.credentials"

# ──────────── 系统检测 ────────────
detect_system() {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  DEB_ARCH="amd64"; RPM_ARCH="x86_64" ;;
    aarch64) DEB_ARCH="arm64"; RPM_ARCH="aarch64" ;;
    *) err "不支持的架构：$ARCH"; exit 1 ;;
  esac
  if   [[ -f /etc/debian_version ]]; then PKG_TYPE="deb"
  elif [[ -f /etc/redhat-release ]]; then PKG_TYPE="rpm"
  else err "仅支持 Debian/Ubuntu 和 CentOS/Rocky/RHEL"; exit 1; fi
}

# ──────────── 状态查询 ────────────
get_version() {
  command -v mita &>/dev/null || { echo "未安装"; return; }
  local v; v=$(dpkg -l mita 2>/dev/null | awk '/^ii/{print $3}' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  [[ -n "$v" ]] && echo "v${v}" || echo "已安装"
}

get_status() {
  command -v mita &>/dev/null || { echo "未安装"; return; }
  mita status 2>/dev/null | grep -q "RUNNING" && echo "运行中" || echo "未运行"
}

get_bbr() {
  sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' \
    | grep -q "bbr" && echo "已启用" || echo "未启用"
}

get_ip() {
  curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -fsSL --max-time 5 https://ifconfig.me 2>/dev/null \
    || echo "未知"
}

# ──────────── 防火墙放行 ────────────
open_port() {
  local port=$1 proto=${2,,}
  if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw allow "${port}/${proto}" &>/dev/null && ok "ufw 放行 ${port}/${proto}"
  fi
  if command -v iptables &>/dev/null; then
    iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null \
      || iptables -I INPUT -p "$proto" --dport "$port" -j ACCEPT
    command -v netfilter-persistent &>/dev/null && netfilter-persistent save &>/dev/null || true
    ok "iptables 放行 ${port}/${proto}"
  fi
}

# ──────────── 主菜单 ────────────
show_menu() {
  clear
  local VER STATUS BBR SC BC
  VER=$(get_version); STATUS=$(get_status); BBR=$(get_bbr)
  [[ "$STATUS" == "运行中" ]] && SC="$GREEN" || SC="$RED"
  [[ "$BBR"    == "已启用" ]] && BC="$GREEN" || BC="$YELLOW"

  echo -e "${BOLD}${CYAN}"
  echo " ================================================"
  echo "   Mieru 管理脚本 v1.0.0"
  echo "   https://github.com/Alvin9999-newpac/Mieru-Plus"
  echo -e " ================================================${PLAIN}"
  printf " %-12s ${BC}%s${PLAIN}\n"   "BBR 加速："  "$BBR"
  printf " %-12s ${SC}%s${PLAIN}\n"   "服务状态："  "$STATUS"
  printf " %-12s ${CYAN}%s${PLAIN}\n" "当前版本："  "$VER"
  echo " ------------------------------------------------"
  echo -e " ${BOLD}1.${PLAIN} 安装 / 重装"
  echo -e " ${BOLD}2.${PLAIN} 查看节点 & 配置"
  echo -e " ${BOLD}3.${PLAIN} 重启服务"
  echo -e " ${BOLD}4.${PLAIN} 一键开启 BBR"
  echo -e " ${BOLD}5.${PLAIN} 查看实时日志"
  echo -e " ${BOLD}6.${PLAIN} 卸载"
  echo -e " ${BOLD}0.${PLAIN} 退出"
  echo " ================================================"
  echo
  read -rp " 请输入选项 [0-6]: " CHOICE
}

# ──────────── 配置展示 ────────────
_show_config() {
  [[ ! -f "$CRED_FILE" ]] && { warn "未找到凭据，请先安装"; return; }
  # shellcheck source=/dev/null
  source "$CRED_FILE"
  local IP; IP=$(get_ip)

  echo -e "\n${BOLD}${GREEN} ========== 节点信息 ==========${PLAIN}"
  echo
  echo -e " ${BOLD}[账号 1 · TCP]${PLAIN}"
  echo   "  服务器 : ${IP}"
  echo   "  端口   : ${TCP_PORT}"
  echo   "  协议   : TCP"
  echo   "  用户名 : ${TCP_USER}"
  echo   "  密码   : ${TCP_PASS}"
  echo
  echo -e " ${BOLD}[账号 2 · UDP]${PLAIN}"
  echo   "  服务器 : ${IP}"
  echo   "  端口   : ${UDP_PORT}"
  echo   "  协议   : UDP"
  echo   "  用户名 : ${UDP_USER}"
  echo   "  密码   : ${UDP_PASS}"

  echo
  echo -e " ${BOLD}[客户端 JSON 配置 · TCP 账号]${PLAIN}"
  cat <<EOF
{
  "profiles": [
    {
      "profileName": "mieru-tcp",
      "user": { "name": "${TCP_USER}", "password": "${TCP_PASS}" },
      "servers": [{
        "ipAddress": "${IP}",
        "domainName": "",
        "portBindings": [{ "port": ${TCP_PORT}, "protocol": "TCP" }]
      }],
      "mtu": 1375
    }
  ],
  "activeProfile": "mieru-tcp",
  "rpcPort": 8964,
  "socks5Port": 1080,
  "loggingLevel": "INFO"
}
EOF

  echo
  echo -e " ${BOLD}[客户端 JSON 配置 · UDP 账号]${PLAIN}"
  cat <<EOF
{
  "profiles": [
    {
      "profileName": "mieru-udp",
      "user": { "name": "${UDP_USER}", "password": "${UDP_PASS}" },
      "servers": [{
        "ipAddress": "${IP}",
        "domainName": "",
        "portBindings": [{ "port": ${UDP_PORT}, "protocol": "UDP" }]
      }],
      "mtu": 1375
    }
  ],
  "activeProfile": "mieru-udp",
  "rpcPort": 8964,
  "socks5Port": 1080,
  "loggingLevel": "INFO"
}
EOF

  echo
  echo -e " ${BOLD}[Clash Meta / Mihomo 配置]${PLAIN}"
  cat <<EOF
proxies:
  - name: mieru-tcp
    type: mieru
    server: ${IP}
    port: ${TCP_PORT}
    transport: tcp
    username: ${TCP_USER}
    password: ${TCP_PASS}

  - name: mieru-udp
    type: mieru
    server: ${IP}
    port: ${UDP_PORT}
    transport: udp
    username: ${UDP_USER}
    password: ${UDP_PASS}
EOF
  echo -e "\n${BOLD}${GREEN} ==============================${PLAIN}\n"
}

# ──────────── 1. 安装 ────────────
do_install() {
  clear
  echo -e "${BOLD}${CYAN}===== 安装 Mieru =====${PLAIN}\n"
  detect_system

  info "获取最新版本..."
  local TAG VER
  TAG=$(curl -fsSL --max-time 10 \
    "https://api.github.com/repos/enfein/mieru/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"\(v[^"]*\)".*/\1/')
  [[ -z "$TAG" ]] && { err "获取版本失败，请检查网络"; press_enter; return; }
  VER=${TAG#v}
  ok "最新版本：${TAG}"

  local PKG URL TMP
  [[ "$PKG_TYPE" == "deb" ]] \
    && PKG="mita_${VER}_${DEB_ARCH}.deb" \
    || PKG="mita-${VER}-1.${RPM_ARCH}.rpm"
  URL="https://github.com/enfein/mieru/releases/download/${TAG}/${PKG}"
  TMP=$(mktemp -d); trap "rm -rf $TMP" RETURN

  info "下载 ${PKG}..."
  curl -fSL --progress-bar -o "${TMP}/${PKG}" "$URL" \
    || { err "下载失败"; press_enter; return; }

  info "安装中..."
  [[ "$PKG_TYPE" == "deb" ]] \
    && dpkg -i "${TMP}/${PKG}" &>/dev/null \
    || rpm -Uvh --force "${TMP}/${PKG}" &>/dev/null
  ok "安装完成：$(get_version)"

  # ── 自动生成 TCP + UDP 两个账号 ──
  echo
  info "自动生成账号..."

  local TCP_USER TCP_PASS TCP_PORT UDP_USER UDP_PASS UDP_PORT

  # 用 openssl + python3 生成随机字符串，完全避免管道 SIGPIPE
  rand_lower8=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_lowercase+string.digits, k=8)))")
  rand_lower8b=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_lowercase+string.digits, k=8)))")
  rand_pass1=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_letters+string.digits, k=16)))")
  rand_pass2=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_letters+string.digits, k=16)))")
  TCP_USER="tcp_${rand_lower8}"
  UDP_USER="udp_${rand_lower8b}"
  TCP_PASS="${rand_pass1}"
  UDP_PASS="${rand_pass2}"
  TCP_PORT=$(( RANDOM % 40000 + 10000 ))
  UDP_PORT=$(( RANDOM % 40000 + 10000 ))
  while [[ "$UDP_PORT" == "$TCP_PORT" ]]; do
    UDP_PORT=$(( RANDOM % 40000 + 10000 ))
  done

  # 写服务端配置
  local CFG; CFG=$(mktemp)
  cat > "$CFG" <<EOF
{
  "portBindings": [
    { "port": ${TCP_PORT}, "protocol": "TCP" },
    { "port": ${UDP_PORT}, "protocol": "UDP" }
  ],
  "users": [
    { "name": "${TCP_USER}", "password": "${TCP_PASS}" },
    { "name": "${UDP_USER}", "password": "${UDP_PASS}" }
  ],
  "loggingLevel": "INFO",
  "mtu": 1375
}
EOF
  mita apply config "$CFG" &>/dev/null && rm -f "$CFG"
  ok "服务端配置写入完成"

  # 保存凭据
  mkdir -p /etc/mita
  cat > "$CRED_FILE" <<EOF
TCP_USER=${TCP_USER}
TCP_PASS=${TCP_PASS}
TCP_PORT=${TCP_PORT}
UDP_USER=${UDP_USER}
UDP_PASS=${UDP_PASS}
UDP_PORT=${UDP_PORT}
EOF
  chmod 600 "$CRED_FILE"

  # 防火墙
  open_port "$TCP_PORT" TCP
  open_port "$UDP_PORT" UDP

  # 启动
  systemctl enable mita &>/dev/null
  mita start &>/dev/null || true
  sleep 3
  ok "服务状态：$(get_status)"

  _show_config
  press_enter
}

# ──────────── 2. 查看节点 ────────────
do_show() {
  clear
  echo -e "${BOLD}${CYAN}===== 节点信息 & 分享配置 =====${PLAIN}\n"
  if ! command -v mita &>/dev/null; then err "mita 未安装"; press_enter; return; fi
  _show_config
  press_enter
}

# ──────────── 3. 重启 ────────────
do_restart() {
  clear
  echo -e "${BOLD}${CYAN}===== 重启服务 =====${PLAIN}\n"
  if ! command -v mita &>/dev/null; then err "mita 未安装"; press_enter; return; fi
  mita stop &>/dev/null; sleep 1; mita start &>/dev/null
  sleep 2; ok "重启完成，状态：$(get_status)"
  press_enter
}

# ──────────── 4. BBR ────────────
do_bbr() {
  clear
  echo -e "${BOLD}${CYAN}===== 开启 BBR =====${PLAIN}\n"
  [[ "$(get_bbr)" == "已启用" ]] && { ok "BBR 已启用"; press_enter; return; }

  local MAJOR MINOR
  MAJOR=$(uname -r | cut -d. -f1); MINOR=$(uname -r | cut -d. -f2)
  if [[ $MAJOR -lt 4 ]] || { [[ $MAJOR -eq 4 ]] && [[ $MINOR -lt 9 ]]; }; then
    err "内核 $(uname -r) 版本过低，需 4.9+"; press_enter; return
  fi

  grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null \
    || echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
  modprobe tcp_bbr 2>/dev/null || true
  grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf \
    || echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf \
    || echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p &>/dev/null
  ok "BBR 已开启：$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
  press_enter
}

# ──────────── 5. 日志 ────────────
do_logs() {
  clear
  echo -e "${BOLD}${CYAN}===== 实时日志（Ctrl+C 退出）=====${PLAIN}\n"
  if ! command -v mita &>/dev/null; then err "mita 未安装"; press_enter; return; fi
  journalctl -u mita -f --no-hostname -o cat
}

# ──────────── 6. 卸载 ────────────
do_uninstall() {
  clear
  echo -e "${BOLD}${RED}===== 卸载 Mieru =====${PLAIN}\n"
  if ! command -v mita &>/dev/null; then warn "mita 未安装"; press_enter; return; fi
  read -rp " 确认卸载？[y/N]: " _c
  [[ "${_c,,}" != "y" ]] && { press_enter; return; }

  mita stop &>/dev/null || true
  systemctl disable mita &>/dev/null || true
  detect_system
  [[ "$PKG_TYPE" == "deb" ]] \
    && apt-get remove -y mita &>/dev/null \
    || rpm -e mita &>/dev/null || true
  rm -rf /etc/mita /var/lib/mita /var/log/mita 2>/dev/null || true
  ok "Mieru 已卸载"
  press_enter
}

# ──────────── 入口 ────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}请用 root 权限运行：sudo bash $0${PLAIN}"; exit 1; }

while true; do
  show_menu
  case "$CHOICE" in
    1) do_install   ;;
    2) do_show      ;;
    3) do_restart   ;;
    4) do_bbr       ;;
    5) do_logs      ;;
    6) do_uninstall ;;
    0) echo -e "\n 再见！\n"; exit 0 ;;
    *) warn "无效选项"; sleep 1 ;;
  esac
done
