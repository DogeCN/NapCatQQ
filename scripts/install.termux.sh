#!/bin/bash

# 颜色变量
RED='\033[0;1;31;91m'
GREEN='\033[0;1;32;92m'
YELLOW='\033[0;1;33;93m'
BLUE='\033[0;1;34;94m'
NC='\033[0m'

CONTAINER_NAME="napcat"
WORKDIR="/root/napcat-work"

function log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}
function log_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
function log_err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
function log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# ============================================
# 检查容器是否存在（修正版）
# ============================================
function container_exists() {
    proot-distro list 2>/dev/null | grep -q "${CONTAINER_NAME}"
}

# ============================================
# 安装脚本内容（将在容器内执行）
# ============================================
read -r -d '' INSTALL_SCRIPT << 'EOF'
#!/bin/bash

set -e

WORKDIR="/root/napcat-work"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
log_err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# 网络测试，自动选择代理
network_test() {
    local proxy_arr=("https://ghfast.top" "https://gh.wuliya.xin" "https://gh-proxy.com")
    local check_url="https://raw.githubusercontent.com/DogeCN/NapCatQQ/main/package.json"
    target_proxy=""
    
    log "测试 Github 连接..."
    for proxy in "${proxy_arr[@]}"; do
        if curl -k -s --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "${proxy}/${check_url}" | grep -q "200"; then
            target_proxy="$proxy"
            log_ok "使用代理: $proxy"
            return
        fi
    done
    
    if curl -k -s --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "$check_url" | grep -q "200"; then
        log_ok "直连成功，不使用代理"
    else
        log_warn "Github 连接失败，将尝试直连（可能较慢）"
    fi
}

# 安装依赖
log "安装系统依赖..."
apt-get update -qq
apt-get install -y -qq curl unzip jq xvfb screen procps g++ wget
apt-get install -y -qq libnss3 libgbm1
apt-get install -y -qq libasound2 2>/dev/null || apt-get install -y -qq libasound2t64
log_ok "依赖安装完成"

# 下载 NapCat
network_test
NAP_URL="${target_proxy:+${target_proxy}/}https://github.com/DogeCN/NapCatQQ/releases/latest/download/NapCat.Shell.zip"
log "下载 NapCat..."
curl -k -L -# -o NapCat.Shell.zip "$NAP_URL" || log_err "NapCat 下载失败"
unzip -q -o NapCat.Shell.zip -d napcat && rm -f NapCat.Shell.zip
log_ok "NapCat 解压完成"

# 下载并编译 launcher
log "编译 launcher.so..."
LAUNCHER_URL="${target_proxy:+${target_proxy}/}https://raw.githubusercontent.com/NapNeko/napcat-linux-launcher/refs/heads/main/launcher.cpp"
curl -k -L -s -o launcher.cpp "$LAUNCHER_URL" || log_err "launcher.cpp 下载失败"
g++ -shared -fPIC launcher.cpp -o libnapcat_launcher.so -ldl && rm -f launcher.cpp
log_ok "libnapcat_launcher.so 编译完成"

# 安装 LinuxQQ
log "安装 LinuxQQ..."
ARCH=$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')
if [ "$ARCH" = "amd64" ]; then
    QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/8015ff90/linuxqq_3.2.21-42086_amd64.deb"
else
    QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/8015ff90/linuxqq_3.2.21-42086_arm64.deb"
fi
curl -k -L -# -o QQ.deb "$QQ_URL" || log_err "QQ 下载失败"
dpkg -i QQ.deb 2>/dev/null || apt-get install -f -y -qq
apt-get install -y -qq libnss3 libgbm1
apt-get install -y -qq libasound2 2>/dev/null || apt-get install -y -qq libasound2t64
rm -f QQ.deb
log_ok "LinuxQQ 安装完成"

# 生成启动脚本
cat > launcher.sh << 'LAUNCHER'
#!/bin/bash
cd /root/napcat-work
Xvfb :1 -screen 0 1x1x8 +extension GLX +render > /dev/null 2>&1 &
export DISPLAY=:1
LD_PRELOAD=./libnapcat_launcher.so qq --no-sandbox
LAUNCHER
chmod +x launcher.sh

log_ok "安装完成！"
echo ""
echo "========================================="
echo "启动 NapCat:"
echo "  proot-distro login napcat -- bash -c 'cd /root/napcat-work && bash launcher.sh'"
echo "========================================="
EOF

# ============================================
# 主流程（Termux 宿主）
# ============================================
clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    NapCat Shell 一键安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 安装 proot-distro
if ! command -v proot-distro &> /dev/null; then
    log "安装 proot-distro..."
    pkg update -q -y 2>/dev/null
    pkg install -y proot-distro || log_err "proot-distro 安装失败"
fi

# 2. 创建容器（仅在不存在时创建）
if container_exists; then
    log_ok "容器 $CONTAINER_NAME 已存在，将复用"
else
    log "创建 Debian 容器 ($CONTAINER_NAME)..."
    proot-distro install debian --override-alias "$CONTAINER_NAME" || log_err "容器创建失败"
    log_ok "容器创建成功"
fi

# 3. 将安装脚本传入容器并执行
log "开始在容器内安装 NapCat（可能需要几分钟）..."
echo "$INSTALL_SCRIPT" | proot-distro login "$CONTAINER_NAME" -- bash -s

# 4. 生成宿主机快捷启动脚本
cat > napcat-start.sh << EOF
#!/bin/bash
echo "启动 NapCat Shell..."
proot-distro login $CONTAINER_NAME -- bash -c "cd $WORKDIR && bash launcher.sh"
EOF
chmod +x napcat-start.sh

echo ""
log_ok "安装完成！"
echo ""
echo "启动方式："
echo "  bash napcat-start.sh"
echo ""
echo "或手动进入："
echo "  proot-distro login $CONTAINER_NAME"
echo "  cd $WORKDIR && bash launcher.sh"
