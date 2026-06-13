#!/data/data/com.termux/files/usr/bin/bash
# NapCatQQ Termux Shell 模式一键部署脚本
# 源仓库: DogeCN/NapCatQQ
#
# 原理:
#   Termux (Android libc) → proot-distro (Debian arm64 容器) → Node.js + NapCat
#   不需要 root, 不需要 xvfb, 不需要完整 QQ 客户端
#   只需要: QQ 的 wrapper.node + package.json + NapCat.Shell.zip
#
# 用法:
#   curl -o install.termux.shell.sh https://raw.githubusercontent.com/DogeCN/NapCatQQ/main/scripts/install.termux.shell.sh
#   bash install.termux.shell.sh
#
# 或指定自定义仓库:
#   GITHUB_REPO="用户名/NapCatQQ" bash install.termux.shell.sh
#
# 安装后使用:
#   cd ~/napcat
#   bash napcat.sh                 # 前台启动 (首次扫码)
#   bash napcat.sh start           # 前台启动
#   bash napcat.sh start -q QQ号   # 前台启动 + 快速登录
#   bash napcat.sh bg              # 后台启动 (screen)
#   bash napcat.sh bg -q QQ号      # 后台启动 + 快速登录
#   bash napcat.sh stop            # 停止
#   bash napcat.sh restart         # 重启
#   bash napcat.sh status          # 查看状态
#   bash napcat.sh log             # 查看日志 (screen -r)
#   bash napcat.sh console         # 进入容器
#   bash napcat.sh help            # 显示帮助

set -e

# ============================================================
# 配置 (可通过环境变量覆盖)
# ============================================================

GITHUB_REPO="${GITHUB_REPO:-DogeCN/NapCatQQ}"

CONTAINER_NAME="napcat"                    # proot-distro 容器别名
INSTALL_DIR="${HOME}/napcat"              # Termux 侧的工作目录
CONTAINER_INSTALL_DIR="/root/napcat"      # 容器内的工作目录

TERMUX_PREFIX="/data/data/com.termux/files/usr"

# 颜色输出
NC='\033[0m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'

# ============================================================
# 工具函数
# ============================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_arch() {
    local arch
    arch=$(uname -m)
    case "${arch}" in
        aarch64|arm64)
            log_info "设备架构: ${arch} (与 Linux arm64 wrapper.node 匹配)"
            ;;
        *)
            log_error "不支持的架构: ${arch}"
            log_error "本脚本仅支持 arm64 (aarch64) 设备 (绝大多数现代 Android 手机)"
            exit 1
            ;;
    esac
}

# ============================================================
# 步骤 1: 环境检查
# ============================================================

echo
log_info "========================================"
log_info "  NapCatQQ Termux Shell 模式一键部署"
log_info "  源仓库: ${GITHUB_REPO}"
log_info "  容器: proot-distro / Debian arm64"
log_info "  模式: Shell (纯 Node.js, 不需 xvfb)"
log_info "========================================"
echo

if [ ! -f "${TERMUX_PREFIX}/bin/bash" ]; then
    log_error "未检测到 Termux 环境，请在 Termux 中运行此脚本"
    exit 1
fi

check_arch

# ============================================================
# 步骤 2: 安装 Termux 依赖 (proot-distro, screen, curl)
# ============================================================

log_info "[1/6] 安装 Termux 基础依赖..."

pkg update -y >/dev/null 2>&1 || apt update -y >/dev/null 2>&1 || true

if ! command -v proot-distro >/dev/null 2>&1; then
    pkg install -y proot-distro
    log_success "proot-distro 已安装"
else
    log_success "proot-distro 已存在 (跳过)"
fi

if ! command -v screen >/dev/null 2>&1; then
    pkg install -y screen
    log_success "screen 已安装"
else
    log_success "screen 已存在 (跳过)"
fi

if ! command -v curl >/dev/null 2>&1; then
    pkg install -y curl
    log_success "curl 已安装"
fi

echo

# ============================================================
# 步骤 3: 创建 Debian arm64 容器
# ============================================================

log_info "[2/6] 创建 Debian arm64 容器 (proot-distro)..."

if proot-distro list 2>/dev/null | grep -q "^${CONTAINER_NAME} "; then
    log_success "容器 '${CONTAINER_NAME}' 已存在 (跳过创建)"
else
    log_info "正在下载 Debian arm64 rootfs (约 150MB, 首次需耐心等待)..."
    proot-distro install debian --override-alias "${CONTAINER_NAME}"
    log_success "Debian arm64 容器创建完成"
fi

echo

# ============================================================
# 步骤 4: 在容器内安装 Node.js + 系统依赖 + 下载 NapCat
# ============================================================

log_info "[3/6] 在容器内安装 Node.js、系统依赖并下载 NapCat..."

# 使用 PROOT_EOF (单引号禁用外部变量展开, 让容器内的 bash 自己展开)
# 用 env 显式传递 GITHUB_REPO, 确保 proot-distro 不会意外清理环境变量
proot-distro sh "${CONTAINER_NAME}" -- env GITHUB_REPO="${GITHUB_REPO}" bash <<'PROOT_EOF'
set -e

# 继承的环境变量: GITHUB_REPO

# 颜色
NC='\033[0m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'

log_info() { echo -e "${BLUE}[容器]${NC} $1"; }
log_success() { echo -e "${GREEN}[容器]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[容器]${NC} $1"; }

NAPCAT_DIR="/root/napcat"
GITHUB_REPO="${GITHUB_REPO:-DogeCN/NapCatQQ}"

# ---- 4.1 更新系统 + 基础工具 ----
log_info "(1/6) 更新系统包..."
apt update -y >/dev/null 2>&1
apt install -y sudo curl ca-certificates unzip file >/dev/null 2>&1
log_success "基础工具已安装"

# ---- 4.2 安装 Node.js 18 LTS ----
log_info "(2/6) 安装 Node.js 18 LTS..."
NEED_INSTALL_NODE=0
if ! command -v node >/dev/null 2>&1; then
    NEED_INSTALL_NODE=1
else
    NODE_MAJOR=$(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v')
    if [ -n "${NODE_MAJOR}" ] && [ "${NODE_MAJOR}" -lt 18 ]; then
        NEED_INSTALL_NODE=1
    fi
fi

if [ "${NEED_INSTALL_NODE}" -eq 1 ]; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    apt install -y nodejs >/dev/null 2>&1
    log_success "Node.js $(node -v) 已安装"
else
    log_success "Node.js $(node -v) 已存在 (跳过)"
fi

# ---- 4.3 安装 QQ wrapper.node 依赖 (链接库, 不需图形环境) ----
log_info "(3/6) 安装 QQ 运行依赖 (图形/网络库)..."
apt install -y \
    libgbm1 libasound2 libegl1 libgl1 libglx-mesa0 libglx0 \
    libnss3 libxcb1 libxkbcommon0 libdbus-1-3 libx11-6 \
    libxext6 libxrandr2 libegl-mesa0 fontconfig \
    libatomic1 libxshmfence1 libdrm2 libxcb-shm0 libxcb-dri2-0 \
    libxcb-present0 libxcb-sync1 libxcb-xfixes0 libxcb-glx0 \
    libxcb-cursor0 libxkbcommon-x11-0 \
    >/dev/null 2>&1
log_success "系统依赖已安装"

# ---- 4.4 创建工作目录 ----
log_info "(4/6) 准备工作目录..."
mkdir -p "${NAPCAT_DIR}"
mkdir -p "${NAPCAT_DIR}/qq"
mkdir -p "${NAPCAT_DIR}/napcat-core"
cd "${NAPCAT_DIR}"

# ---- 4.5 从 GitHub Release 下载 NapCat.Shell.zip ----
log_info "(5/6) 下载 NapCat.Shell.zip..."
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*Shell[^"]*"' \
    | head -1 \
    | cut -d'"' -f4)

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "ERROR: 未在 Release 中找到 NapCat.Shell.zip"
    echo "请检查仓库: https://github.com/${GITHUB_REPO}/releases"
    exit 1
fi

echo "  URL: ${DOWNLOAD_URL}"
curl -L -o NapCat.Shell.zip "${DOWNLOAD_URL}"

if [ ! -s NapCat.Shell.zip ]; then
    echo "ERROR: NapCat.Shell.zip 下载失败或为空"
    exit 1
fi

# 解压到 napcat-core 目录
unzip -q NapCat.Shell.zip -d napcat-core/
rm -f NapCat.Shell.zip

# ---- 4.6 从仓库 source/ 下载 QQ 核心文件 ----
echo
log_info "从仓库 source/ 目录下载 QQ 核心文件..."

curl -L -o "${NAPCAT_DIR}/qq/wrapper.node" \
    "https://raw.githubusercontent.com/${GITHUB_REPO}/main/script/depends/wrapper.node"
curl -L -o "${NAPCAT_DIR}/qq/package.json" \
    "https://raw.githubusercontent.com/${GITHUB_REPO}/main/script/depends/package.json"

# 验证
if [ ! -s "${NAPCAT_DIR}/qq/wrapper.node" ]; then
    echo "ERROR: wrapper.node 下载失败"
    exit 1
fi
if [ ! -s "${NAPCAT_DIR}/qq/package.json" ]; then
    echo "ERROR: package.json 下载失败"
    exit 1
fi

# 验证架构
WRAPPER_INFO=$(file "${NAPCAT_DIR}/qq/wrapper.node" 2>/dev/null || echo "unknown")
echo "  wrapper.node: $(echo "${WRAPPER_INFO}" | head -1)"

# 读取版本号
QQ_VERSION=$(grep -o '"version": *"[^"]*"' "${NAPCAT_DIR}/qq/package.json" | head -1 | cut -d'"' -f4)
echo "  QQ 版本: ${QQ_VERSION}"

# ---- 4.7 权限设置 ----
chmod -R +x "${NAPCAT_DIR}/napcat-core/"

# ---- 4.8 在容器内生成运行脚本 (避免 Termux 侧复杂的引号嵌套) ----
echo
log_info "(6/6) 生成容器内运行脚本..."

# run.sh: 在容器内执行的 NapCat 启动脚本
# 用法: bash run.sh          # 扫码登录
#       bash run.sh -q QQ号  # 快速登录
cat > "${NAPCAT_DIR}/run.sh" <<'RUNSCRIPT'
#!/bin/bash
# NapCat Shell 模式运行脚本 (容器内执行)

set -e

NAPCAT_DIR="/root/napcat"

# 关键: 通过环境变量告诉 NapCat 去哪里找 wrapper.node 和版本信息
export NAPCAT_WRAPPER_PATH="${NAPCAT_DIR}/qq/wrapper.node"
export NAPCAT_QQ_PACKAGE_INFO_PATH="${NAPCAT_DIR}/qq/package.json"
export NAPCAT_WORKDIR="${NAPCAT_DIR}/napcat-core"

cd "${NAPCAT_DIR}/napcat-core"

# 启动 NapCat (参数透传: $@ 可以是 -q QQ号 等)
exec node napcat.mjs "$@"
RUNSCRIPT

chmod +x "${NAPCAT_DIR}/run.sh"
log_success "容器内脚本: ${NAPCAT_DIR}/run.sh"

echo
log_success "NapCat Shell 模式部署文件已就绪"
echo
echo "  NapCat 代码: ${NAPCAT_DIR}/napcat-core/"
echo "  QQ 核心模块: ${NAPCAT_DIR}/qq/wrapper.node"
echo "  QQ 版本信息: ${NAPCAT_DIR}/qq/package.json"
echo "  运行脚本:   ${NAPCAT_DIR}/run.sh"
echo

PROOT_EOF

echo

# ============================================================
# 步骤 5: 在 Termux 侧生成单一启动脚本 napcat.sh
# ============================================================
#
# 设计: 用子命令控制行为, 无参数默认前台启动
#   bash napcat.sh                     → 前台启动
#   bash napcat.sh start               → 前台启动
#   bash napcat.sh start -q 123456789  → 前台启动 + 快速登录
#   bash napcat.sh -q 123456789        → 前台启动 + 快速登录
#   bash napcat.sh bg                  → 后台启动 (screen)
#   bash napcat.sh bg -q 123456789     → 后台启动 + 快速登录
#   bash napcat.sh stop                → 停止
#   bash napcat.sh restart             → 重启 (停止 + 后台启动)
#   bash napcat.sh status              → 查看状态
#   bash napcat.sh log                 → 查看日志 (screen -r)
#   bash napcat.sh console             → 进入容器交互 shell
#   bash napcat.sh help                → 显示帮助

log_info "[4/6] 生成 Termux 侧启动脚本..."

mkdir -p "${INSTALL_DIR}"

# ---- 5.1 生成 napcat.sh 单脚本 (合并所有功能) ----
cat > "${INSTALL_DIR}/napcat.sh" <<NAPCATEOF
#!/data/data/com.termux/files/usr/bin/bash
# NapCatQQ Termux Shell 模式 - 统一管理脚本
#
# 用法:
#   bash napcat.sh                     # 前台启动 (扫码登录)
#   bash napcat.sh start               # 前台启动
#   bash napcat.sh start -q 123456789  # 前台启动 + 快速登录
#   bash napcat.sh -q 123456789        # 前台启动 + 快速登录
#   bash napcat.sh bg                  # 后台启动 (screen)
#   bash napcat.sh bg -q 123456789     # 后台启动 + 快速登录
#   bash napcat.sh stop                # 停止后台运行
#   bash napcat.sh restart             # 重启 (停止 + 后台启动)
#   bash napcat.sh status              # 查看运行状态
#   bash napcat.sh log                 # 查看日志 (attach screen)
#   bash napcat.sh console             # 进入容器交互 shell
#   bash napcat.sh help                # 显示帮助
#
# 也可以直接用符号链接:
#   ~/napcat.sh bg

set -e

# ============ 配置 ============
CONTAINER_NAME="${CONTAINER_NAME}"
CONTAINER_DIR="${CONTAINER_INSTALL_DIR}"
NAPCAT_SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"

# ============ 工具函数 ============
is_running() {
    screen -ls 2>/dev/null | grep -q "\.napcat "
}

cmd_start_foreground() {
    # 前台启动: 直接进入容器执行 run.sh, 参数完整透传
    echo "→ 前台启动 NapCat (Ctrl+C 退出)"
    echo ""
    exec proot-distro sh "\${CONTAINER_NAME}" -- bash "\${CONTAINER_DIR}/run.sh" "\$@"
}

cmd_start_background() {
    # 后台启动: 用 screen 分离模式
    if is_running; then
        echo "✓ NapCat 已在后台运行 (screen 会话: napcat)"
        echo "  查看输出: bash \$0 log"
        echo "  停止服务: bash \$0 stop"
        exit 0
    fi

    echo "→ 后台启动 NapCat (screen)"
    # 核心: 在 screen 中执行前台启动脚本 (即本脚本不带子命令)
    # 用 bash "$0" __fg__ 让 screen 启动一个子进程做实际工作
    # "__fg__" 是一个内部标记, 让脚本知道自己应该以前台模式启动
    screen -dmS napcat bash "\${NAPCAT_SCRIPT_DIR}/napcat.sh" __fg__ "\$@"

    sleep 3

    if is_running; then
        echo "✓ NapCat 已在后台启动"
        echo ""
        echo "【管理命令】"
        echo "  bash \$0 log      # 查看输出 (退出查看: Ctrl+A 然后按 D)"
        echo "  bash \$0 stop     # 停止服务"
        echo "  bash \$0 status   # 查看运行状态"
    else
        echo "✗ 启动失败, 请手动运行前台模式查看错误:"
        echo "  bash \$0 start"
        exit 1
    fi
}

cmd_stop() {
    if is_running; then
        echo "→ 停止 NapCat..."
        screen -S napcat -X quit
        sleep 1
        if is_running; then
            # 温和方式失败, 强制杀掉所有相关进程
            pkill -f "napcat.*napcat" >/dev/null 2>&1 || true
            sleep 1
        fi
        if is_running; then
            echo "✗ 停止失败, 请手动执行: screen -S napcat -X quit"
            exit 1
        else
            echo "✓ NapCat 已停止"
        fi
    else
        echo "未检测到运行中的 NapCat"
    fi
}

cmd_restart() {
    echo "→ 重启 NapCat..."
    cmd_stop 2>/dev/null || true
    sleep 1
    cmd_start_background "$@"
}

cmd_status() {
    echo "================ NapCat 状态 ================"
    if is_running; then
        echo "状态: 运行中 ✓ (screen 会话: napcat)"
    else
        echo "状态: 未运行 ✗"
    fi
    echo ""
    echo "================ 文件检查 ================="
    proot-distro sh "\${CONTAINER_NAME}" -- bash -c '
NAPCAT_DIR="/root/napcat"
echo ""
echo "  wrapper.node:   "\$(test -f \${NAPCAT_DIR}/qq/wrapper.node && echo "存在 ✓" || echo "缺失 ✗")
echo "  package.json:   "\$(test -f \${NAPCAT_DIR}/qq/package.json && echo "存在 ✓" || echo "缺失 ✗")
echo "  napcat.mjs:     "\$(test -f \${NAPCAT_DIR}/napcat-core/napcat.mjs && echo "存在 ✓" || echo "缺失 ✗")
echo "  run.sh:         "\$(test -x \${NAPCAT_DIR}/run.sh && echo "存在/可执行 ✓" || echo "缺失 ✗")
echo "  Node.js:        "\$(node -v 2>/dev/null || echo "未安装")
echo ""
echo "  QQ 版本:        "\$(grep -o '"version": *"[^"]*"' \${NAPCAT_DIR}/qq/package.json 2>/dev/null | head -1 | cut -d'"' -f4 || echo "未知")
echo "  日志目录:       "\$(ls -d \${NAPCAT_DIR}/napcat-core/logs 2>/dev/null && echo "存在" || echo "不存在 (未启动过)")
echo "  配置目录:       "\$(ls -d \${NAPCAT_DIR}/napcat-core/config 2>/dev/null && echo "存在" || echo "不存在 (未启动过)")
echo ""
echo "  文件根目录:     \${NAPCAT_DIR}"
' 2>/dev/null || echo "  (无法进入容器, 请检查 proot-distro 是否正常)"

    echo ""
    echo "================ 快速命令 ================="
    echo "  bash \$0 start     # 前台启动 (扫码登录用)"
    echo "  bash \$0 bg        # 后台启动 (日常使用)"
    echo "  bash \$0 bg -q QQ号 # 后台启动 + 快速登录"
    echo "  bash \$0 stop      # 停止"
    echo "  bash \$0 restart   # 重启"
    echo "  bash \$0 log       # 查看输出"
    echo "  bash \$0 console   # 进入容器"
}

cmd_log() {
    if is_running; then
        echo "→ 进入 NapCat 日志查看 (screen)"
        echo "  提示: 按 Ctrl+A 然后按 D 退出查看 (进程会继续运行)"
        echo ""
        screen -r napcat
    else
        echo "NapCat 未在后台运行, 请先启动:"
        echo "  bash \$0 bg"
    fi
}

cmd_console() {
    echo "→ 进入 Debian arm64 容器交互 shell (exit 退出)"
    echo ""
    proot-distro login "\${CONTAINER_NAME}"
}

cmd_help() {
    echo "NapCatQQ Termux Shell 模式 - 管理脚本"
    echo ""
    echo "用法:"
    echo "  bash napcat.sh                     # 前台启动 (扫码登录)"
    echo "  bash napcat.sh start               # 前台启动"
    echo "  bash napcat.sh start -q 123456789  # 前台启动 + 快速登录"
    echo "  bash napcat.sh -q 123456789        # 前台启动 + 快速登录"
    echo "  bash napcat.sh bg                  # 后台启动 (screen)"
    echo "  bash napcat.sh bg -q 123456789     # 后台启动 + 快速登录"
    echo "  bash napcat.sh stop                # 停止"
    echo "  bash napcat.sh restart             # 重启"
    echo "  bash napcat.sh status              # 查看状态"
    echo "  bash napcat.sh log                 # 查看日志"
    echo "  bash napcat.sh console             # 进入容器"
    echo "  bash napcat.sh help                # 显示帮助"
    echo ""
    echo "路径:"
    echo "  Termux 工作目录: \${NAPCAT_SCRIPT_DIR}"
    echo "  容器名称:        \${CONTAINER_NAME}"
    echo "  容器内目录:      \${CONTAINER_DIR}"
}

# ============ 参数解析 ============
# 核心逻辑:
#   1. 如果第一个参数是已知子命令 (start/bg/stop/restart/status/log/console/help),
#      则执行对应函数, 剩余参数透传
#   2. 如果第一个参数是 "__fg__" (内部标记), 则执行前台启动
#   3. 否则默认前台启动 (所有参数作为启动参数传递)

if [ \$# -eq 0 ]; then
    # 无参数: 默认前台启动
    cmd_start_foreground
fi

case "\$1" in
    # 内部标记: 由 screen 调用时使用, 表示"前台启动模式"
    __fg__)
        shift
        cmd_start_foreground "\$@"
        ;;
    # 前台启动
    start|fg|foreground)
        shift
        cmd_start_foreground "\$@"
        ;;
    # 后台启动
    bg|background|daemon|d)
        shift
        cmd_start_background "\$@"
        ;;
    # 停止
    stop|kill|quit|exit)
        cmd_stop
        ;;
    # 重启
    restart|reload)
        shift
        cmd_restart "\$@"
        ;;
    # 查看状态
    status|info|check)
        cmd_status
        ;;
    # 查看日志
    log|logs|attach|console-log)
        cmd_log
        ;;
    # 进入容器
    console|shell|chroot|login)
        cmd_console
        ;;
    # 帮助
    help|--help|-h|-\?)
        cmd_help
        ;;
    # 其他情况: 可能是 -q 123456789 这种直接参数
    # 按默认前台启动处理 (把 $1 及后续都作为启动参数传递)
    *)
        cmd_start_foreground "\$@"
        ;;
esac
NAPCATEOF

chmod +x "${INSTALL_DIR}/napcat.sh"
log_success "管理脚本: ${INSTALL_DIR}/napcat.sh"

echo

# ============================================================
# 步骤 6: 验证 & 输出使用说明
# ============================================================

log_info "[5/6] 验证部署..."

# 检查容器内关键文件
if proot-distro sh "${CONTAINER_NAME}" -- bash -c "
test -f ${CONTAINER_INSTALL_DIR}/qq/wrapper.node && \
test -f ${CONTAINER_INSTALL_DIR}/qq/package.json && \
test -f ${CONTAINER_INSTALL_DIR}/napcat-core/napcat.mjs && \
test -x ${CONTAINER_INSTALL_DIR}/run.sh && \
test -x /usr/bin/node
" >/dev/null 2>&1; then
    log_success "核心文件验证通过"
else
    log_warn "部分文件可能缺失, 请手动检查 (bash ${INSTALL_DIR}/napcat.sh status)"
fi

echo
log_info "[6/6] 部署完成!"
echo

echo "========================================"
echo "  管理脚本:    ${INSTALL_DIR}/napcat.sh"
echo "  容器名称:    ${CONTAINER_NAME} (Debian arm64)"
echo "  容器内目录:  ${CONTAINER_INSTALL_DIR}"
echo "========================================"
echo
echo "【快速开始】"
echo
echo "  cd ${INSTALL_DIR}"
echo ""
echo "  1) 首次启动 (扫码登录):"
echo "     bash napcat.sh start"
echo ""
echo "  2) 后台运行 (推荐日常使用):"
echo "     bash napcat.sh bg"
echo ""
echo "  3) 指定 QQ 号快速登录:"
echo "     bash napcat.sh start -q 123456789   # 前台"
echo "     bash napcat.sh bg -q 123456789      # 后台"
echo ""
echo "  4) 后台管理:"
echo "     bash napcat.sh log       # 查看输出"
echo "     bash napcat.sh stop      # 停止"
echo "     bash napcat.sh restart   # 重启"
echo "     bash napcat.sh status    # 查看状态"
echo ""
echo "【完整子命令】"
echo "  start / fg         前台启动 (无参数默认行为)"
echo "  bg / daemon        后台启动 (screen)"
echo "  stop                停止后台运行"
echo "  restart             重启 (停止 + 后台启动)"
echo "  status              查看状态"
echo "  log                 查看日志 (screen -r)"
echo "  console             进入容器交互 shell"
echo "  help                显示帮助"
echo "  -q QQ号             快速登录指定 QQ 号 (跟随 start 或 bg)"
echo ""
echo "【文件位置 (容器内 ${CONTAINER_INSTALL_DIR})】"
echo "  napcat-core/       ← NapCat 代码"
echo "  napcat-core/config/ ← 配置文件"
echo "  napcat-core/logs/   ← 日志文件"
echo "  qq/wrapper.node     ← QQ 核心模块 (arm64)"
echo "  qq/package.json     ← QQ 版本信息"
echo "  run.sh              ← 运行脚本"
echo ""
echo "【Shell 模式特点】"
echo "  ✓ 不需要 root 权限"
echo "  ✓ 不需要 xvfb (虚拟图形环境)"
echo "  ✓ 不需要安装完整 QQ 客户端"
echo "  ✓ 只需要 Node.js + wrapper.node"
echo "  ✓ 资源占用低, 启动速度快"
echo ""
echo "【重要提示】"
echo "  1. 首次启动会显示二维码, 用手机 QQ 扫码登录"
echo "  2. WebUI 地址在启动后输出 (如 http://localhost:6099/webui/?token=...)"
echo "  3. Termux 被系统清理后只需重新运行: bash napcat.sh bg"
echo "  4. 如需切换其他 QQ 号, 可进入容器删除 napcat-core/config 后重启"
echo "  5. 查看日志时按 Ctrl+A 然后按 D 退出查看 (进程会继续运行)"
echo

# 在 HOME 建立符号链接方便使用
if [ ! -f "${HOME}/napcat.sh" ]; then
    ln -sf "${INSTALL_DIR}/napcat.sh" "${HOME}/napcat.sh"
    log_success "已在 \$HOME 建立快捷链接, 可直接运行 ~/napcat.sh"
fi

echo
log_success "部署完成! 首次启动请运行: bash ${INSTALL_DIR}/napcat.sh start"