#!/bin/bash

# ================= 配置区域 =================
# CHANGELOG 的原始地址
CHANGELOG_URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
# ===========================================

# 定义颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}正在检查 Claude Code 版本...${NC}"

# 1. 获取本地版本
# 检查 claude 是否安装
if ! command -v claude &> /dev/null; then
    echo -e "${RED}错误: 未找到 'claude' 命令。请先安装 Claude Code。${NC}"
    exit 1
fi

# 获取版本字符串，例如 "2.1.31 (Claude Code)" -> 提取 "2.1.31"
local_version=$(claude --version | awk '{print $1}')
echo "本地版本: $local_version"

# 2. 获取远程最新版本
# 使用 curl 获取并用 grep 提取第一个形如 X.X.X 的版本号
latest_version=$(curl -sL "$CHANGELOG_URL" | grep -E "^##? \[?[0-9]+\.[0-9]+\.[0-9]+" | head -n 1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")

if [ -z "$latest_version" ]; then
    echo -e "${RED}错误: 无法获取远程版本号，请检查网络连接。${NC}"
    exit 1
fi

echo "最新版本: $latest_version"

# 3. 版本比较函数 (语义化比较)
# 返回 0 (true) 如果 $1 > $2，否则返回 1 (false)
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# 4. 判断并执行更新
if [ "$local_version" == "$latest_version" ]; then
    echo -e "${GREEN}当前已是最新版本，无需更新。${NC}"
else
    # 检查 latest_version 是否大于 local_version
    if version_gt "$latest_version" "$local_version"; then
        echo -e "${YELLOW}发现新版本！正在准备更新...${NC}"
        
        # === 执行用户指定的更新命令 ===
        echo -e "执行命令: claude install $latest_version"
        
        # 注意：这里假设 'claude install' 是你环境中的有效命令
        # 如果是标准的 npm 安装，通常建议使用: npm install -g @anthropics/claude-code@"$latest_version"
        claude install "$latest_version"
        
        if [ $? -eq 0 ]; then
             echo -e "${GREEN}更新成功！${NC}"
             # 验证更新后的版本
             new_ver=$(claude --version | awk '{print $1}')
             echo "当前版本: $new_ver"
        else
             echo -e "${RED}更新失败，请检查错误日志。${NC}"
             exit 1
        fi
    else
        # 这种情况通常很少见（本地版本比远程还新，可能是测试版）
        echo -e "${GREEN}本地版本 ($local_version) 似乎比 Changelog 版本 ($latest_version) 更新或相同。${NC}"
    fi
fi

