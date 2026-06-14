#!/bin/bash

# ============================================
# NapCat 混合安装脚本 - 无宿主机文件版
# - 容器名: napcat
# - 源仓库: DogeCN/NapCatQQ
# - 注入方式: Launcher 模式 (LD_PRELOAD)
# - 虚拟显示: xvfb-run (官方稳定方案)
# - 启动方式: 进入容器后输入 napcat
# ============================================

RED='\033[0;1;31;91m'
GREEN='\033[0;1;32;92m'
YELLOW='\033[0;1;33;93m'
BLUE='\033[0;1;34;94m'
NC='\033[0m'

CONTAINER_NAME="napcat"
WORKDIR="/root/napcat-work"

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
log_err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# 1. 安装 proot-distro（仅在 Termux 宿主执行）
log "安装 proot-distro 环境..."
pkg update -y 2>/dev/null
pkg install -y proot-distro || {
    apt update -y && apt install -y proot-distro || log_err "proot-distro 安装失败"
}
log_ok "proot-distro 安装成功"

# 2. 清理并创建容器
if proot-distro list 2>/dev/null | grep -q "${CONTAINER_NAME}"; then
    log_warn "发现已存在的 ${CONTAINER_NAME} 容器，将删除重建..."
    proot-distro remove "${CONTAINER_NAME}" || log_err "容器删除失败"
fi

log "创建 ${CONTAINER_NAME} 容器..."
proot-distro install debian --override-alias "${CONTAINER_NAME}" || log_err "容器创建失败"
log_ok "容器创建成功"

# 3. 容器内安装脚本（Launcher 模式 + DogeCN 源 + 添加 napcat 命令）
log "开始在容器内安装 NapCat（DogeCN 源 + Launcher 模式）..."

INNER_SCRIPT='
#!/bin/bash
set -e

WORKDIR="/root/napcat-work"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo ">>> 安装系统依赖..."
apt update -y
apt install -y curl unzip jq screen procps wget
apt install -y libnss3 libgbm1 xvfb
apt install -y libasound2 2>/dev/null || apt install -y libasound2t64
apt install -y g++ make

# 网络代理测试
echo ">>> 测试 Github 连接..."
proxy_arr=("https://ghfast.top" "https://gh.wuliya.xin" "https://gh-proxy.com")
check_url="https://raw.githubusercontent.com/DogeCN/NapCatQQ/main/package.json"
target_proxy=""
for proxy in "${proxy_arr[@]}"; do
    if curl -k -s --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "${proxy}/${check_url}" | grep -q "200"; then
        target_proxy="$proxy"
        echo ">>> 使用代理: $proxy"
        break
    fi
done

# ============================================
# Launcher 模式：手动编译 libnapcat_launcher.so
# ============================================

# 1. 下载并编译 launcher.cpp
echo ">>> 下载 launcher.cpp..."
LAUNCHER_URL="${target_proxy:+${target_proxy}/}https://raw.githubusercontent.com/NapNeko/napcat-linux-launcher/refs/heads/main/launcher.cpp"
curl -k -L -# -o launcher.cpp "$LAUNCHER_URL"

echo ">>> 编译 libnapcat_launcher.so..."
g++ -shared -fPIC launcher.cpp -o libnapcat_launcher.so -ldl
rm -f launcher.cpp

# 2. 下载 NapCat 本体（DogeCN 源）
echo ">>> 下载 NapCat 本体 (DogeCN/NapCatQQ)..."
NAP_URL="${target_proxy:+${target_proxy}/}https://github.com/DogeCN/NapCatQQ/releases/latest/download/NapCat.Shell.zip"
curl -k -L -# -o NapCat.Shell.zip "$NAP_URL"
unzip -q -o NapCat.Shell.zip -d napcat && rm -f NapCat.Shell.zip

# 3. 安装 LinuxQQ
echo ">>> 安装 LinuxQQ..."
ARCH=$(arch | sed "s/aarch64/arm64/" | sed "s/x86_64/amd64/")
if [ "$ARCH" = "amd64" ]; then
    QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/8015ff90/linuxqq_3.2.21-42086_amd64.deb"
else
    QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/8015ff90/linuxqq_3.2.21-42086_arm64.deb"
fi
curl -k -L -# -o QQ.deb "$QQ_URL"
dpkg -i QQ.deb 2>/dev/null || apt install -f -y -qq
apt install -y libnss3 libgbm1
apt install -y libasound2 2>/dev/null || apt install -y libasound2t64
rm -f QQ.deb

# 4. 修改 QQ 的 package.json（Launcher 模式核心）
echo ">>> 配置 QQ 加载 NapCat..."
QQ_PACKAGE_JSON="/opt/QQ/resources/app/package.json"
if [ -f "$QQ_PACKAGE_JSON" ]; then
    cp "$QQ_PACKAGE_JSON" "$QQ_PACKAGE_JSON.bak"
    jq ".main = \"../../../../root/napcat-work/napcat/loadNapCat.js\"" "$QQ_PACKAGE_JSON" > "$QQ_PACKAGE_JSON.tmp"
    mv "$QQ_PACKAGE_JSON.tmp" "$QQ_PACKAGE_JSON"
fi

# 5. 创建全局 napcat 启动命令
cat > /usr/local/bin/napcat << NAPCAT_EOF
#!/bin/bash
cd $WORKDIR
export LD_PRELOAD="./libnapcat_launcher.so"
xvfb-run -a /opt/QQ/qq --no-sandbox
NAPCAT_EOF
chmod +x /usr/local/bin/napcat

# 6. 清理缓存
apt autoremove -y && apt clean
rm -rf /var/lib/apt/lists/* /tmp/*

echo "INSTALL_SUCCESS"
'

# 执行容器内安装
proot-distro login "${CONTAINER_NAME}" -- bash -c "$INNER_SCRIPT" | grep -q "INSTALL_SUCCESS" || {
    proot-distro remove "${CONTAINER_NAME}"
    log_err "安装失败"
}

log_ok "NapCat 安装成功（Launcher 模式 + DogeCN 源）"

# 4. 输出使用说明（不创建任何宿主机文件）
clear
log_ok "========================================="
log_ok "安装完成！"
log_ok "========================================="
echo ""
echo "进入容器并启动 NapCat："
echo "  proot-distro login ${CONTAINER_NAME}"
echo "  napcat"
echo ""
echo "后台运行（可选）："
echo "  proot-distro login ${CONTAINER_NAME} -- bash -c \"screen -dmS napcat napcat\""
echo "  查看日志: screen -r napcat"
echo "  退出后台: Ctrl+A, D"
echo ""
echo "WebUI 访问密钥："
echo "  cat /data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/${CONTAINER_NAME}${WORKDIR}/napcat/config/webui.json | jq .token"
echo ""
log_ok "========================================="
