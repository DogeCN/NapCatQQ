#!/bin/bash
set -e

# 检查是否在 Debian/Ubuntu 容器内
if ! command -v apt &> /dev/null; then
    echo "错误：未检测到apt包管理器"
    exit 1
fi

apt update
apt install -y python3 python3-pip python3-venv git build-essential libssl-dev
python3 --version
cd ~
if [ -d "AstrBot" ]; then
    cd AstrBot && git pull
else
    git clone --depth=1 https://github.com/AstrBotDevs/AstrBot.git
    cd AstrBot
fi

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple

echo ""
echo "✅ 安装完成！"
echo ""
echo "🚀 启动 AstrBot 的命令："
echo "    cd ~/AstrBot && source venv/bin/activate && python main.py"
echo ""
echo "🌐 访问 Web 面板：http://localhost:6185"
echo ""
echo "💡 如需后台运行，可使用 tmux 或 screen："
echo "    tmux new -s astrbot"
echo "    然后执行上述启动命令，按 Ctrl+B 再按 D 脱离会话"
