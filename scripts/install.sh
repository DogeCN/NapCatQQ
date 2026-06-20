#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}${1}${NC}"; exit 1; }
success() { echo -e "${GREEN}${1}${NC}"; }

command -v apt-get &>/dev/null || error "未检测到 apt-get 包管理器"
[ "$EUID" -eq 0 ] || error "此脚本需要以 root 权限运行"

apt-get update -y -qq
apt-get install -y -qq zip unzip jq curl xvfb screen xauth procps g++ libnss3 libgbm1

apt-get install -y -qq libasound2 2>/dev/null || apt-get install -y -qq libasound2t64

SYSTEM_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
[ "$SYSTEM_ARCH" = "amd64" ] || [ "$SYSTEM_ARCH" = "arm64" ] || error "不支持的架构: $SYSTEM_ARCH"

# 检测 Github 代理
TARGET_PROXY=""
for proxy in "https://ghfast.top" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://github.moeyy.xyz"; do
    if [ "$(curl -k -L --connect-timeout 10 --max-time 20 -o /dev/null -s -w "%{http_code}" "${proxy}/https://raw.githubusercontent.com/DogeCN/NapCatQQ/main/package.json")" = "200" ]; then
        TARGET_PROXY="$proxy"
        break
    fi
done

mkdir -p ./napcat

if [ ! -f "NapCat.Shell.zip" ]; then
    DOWNLOAD_URL="${TARGET_PROXY:+${TARGET_PROXY}/}https://github.com/DogeCN/NapCatQQ/releases/latest/download/NapCat.Shell.zip"
    curl -k -L -# "$DOWNLOAD_URL" -o NapCat.Shell.zip || error "NapCat下载失败"
fi
unzip -q -o -d ./napcat NapCat.Shell.zip || error "文件解压失败"

# 安装 LinuxQQ
QQ_VERSION="8015ff90"
QQ_NUM_VERSION="3.2.21-42086"
QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/${QQ_VERSION}/linuxqq_${QQ_NUM_VERSION}_${SYSTEM_ARCH}.deb"
[ -f "QQ.deb" ] || curl -k -L -# "$QQ_URL" -o QQ.deb || error "QQ下载失败"
apt-get install -f -y --allow-downgrades -qq ./QQ.deb
rm -f QQ.deb

# 编译 launcher.so
CPP_URL="https://raw.githubusercontent.com/NapNeko/napcat-linux-launcher/refs/heads/main/launcher.cpp"
if [ -n "$TARGET_PROXY" ]; then
    DOWNLOAD_URL="${TARGET_PROXY}/${CPP_URL#https://}"
else
    DOWNLOAD_URL="$CPP_URL"
fi
curl -k -L -# "$DOWNLOAD_URL" -o launcher.cpp || error "launcher.cpp下载失败"
g++ -shared -fPIC launcher.cpp -o libnapcat_launcher.so -ldl || error "launcher.so编译失败"
rm -f launcher.cpp NapCat.Shell.zip

cat << 'EOF' > launcher.sh
#!/bin/bash
Xvfb :1 -screen 0 1x1x8 +extension GLX +render > /dev/null 2>&1 &
export DISPLAY=:1
trap "" SIGPIPE
LD_PRELOAD=./libnapcat_launcher.so qq --no-sandbox
EOF
chmod +x launcher.sh

success "安装完成！运行 bash ./launcher.sh 启动 NapCat Shell"