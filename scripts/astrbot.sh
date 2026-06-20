#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}${1}${NC}"; exit 1; }
success() { echo -e "${GREEN}${1}${NC}"; }

command -v apt &>/dev/null || error "未检测到 apt 包管理器"

apt update
apt install -y python3 python3-pip python3-venv git build-essential libssl-dev

cd ~
[ -d AstrBot ] && (cd AstrBot && git pull) || git clone --depth=1 https://github.com/AstrBotDevs/AstrBot.git
cd AstrBot

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple

cat > ~/start.sh << 'EOF'
#!/bin/bash
cd ~/AstrBot && source venv/bin/activate && python main.py
EOF
chmod +x ~/start.sh

success "完成！运行 ~/start.sh 启动 AstrBot"