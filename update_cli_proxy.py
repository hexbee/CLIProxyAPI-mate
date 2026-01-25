#!/usr/bin/env python3
"""
CLIProxyAPI 自动更新脚本
下载最新版本并更新本地安装
"""

import os
import subprocess
import sys
import urllib.request
import json
import zipfile
import shutil

REPO_OWNER = "router-for-me"
REPO_NAME = "CLIProxyAPI"
APP_DIR = "CLIProxyAPI"
EXE_NAME = "cli-proxy-api.exe"
CONFIG_EXAMPLE = "config.example.yaml"
CONFIG_FILE = "config.yaml"


def get_current_version():
    """检查当前已安装版本"""
    exe_path = os.path.join(APP_DIR, EXE_NAME)
    if not os.path.exists(exe_path):
        return None

    try:
        result = subprocess.run(
            [exe_path, "--help"],
            capture_output=True,
            text=True,
            timeout=10
        )
        output = result.stdout + result.stderr

        # 解析 "CLIProxyAPI Version: X.X.X" 格式，只提取版本号 X.X.X
        import re
        match = re.search(r'CLIProxyAPI\s+Version:\s*(\d+\.\d+\.\d+)', output)
        if match:
            return match.group(1)

        return None
    except Exception as e:
        print(f"获取当前版本失败: {e}")
        return None


def get_latest_version():
    """获取 GitHub 最新 release 版本号"""
    api_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"

    try:
        req = urllib.request.Request(api_url, headers={'User-Agent': 'Python'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            tag_name = data.get('tag_name', '')
            # 移除 'v' 前缀
            if tag_name.startswith('v'):
                tag_name = tag_name[1:]
            return tag_name
    except Exception as e:
        print(f"获取最新版本失败: {e}")
        return None


def download_and_extract(version):
    """下载并解压新版本"""
    zip_url = f"https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/v{version}/CLIProxyAPI_{version}_windows_amd64.zip"
    zip_path = f"CLIProxyAPI_{version}_windows_amd64.zip"

    print(f"正在下载: {zip_url}")

    try:
        # 下载
        urllib.request.urlretrieve(zip_url, zip_path)
        print(f"下载完成: {zip_path}")

        # 创建目标目录
        os.makedirs(APP_DIR, exist_ok=True)

        # 解压到目标目录
        print(f"正在解压到 {APP_DIR}/ ...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            for member in zip_ref.namelist():
                # 去掉任何路径前缀，只保留文件名
                filename = os.path.basename(member)
                if filename:
                    zip_ref.extract(member, APP_DIR)

        # 删除 ZIP
        os.remove(zip_path)
        print("解压完成")

        return True
    except Exception as e:
        print(f"下载/解压失败: {e}")
        if os.path.exists(zip_path):
            os.remove(zip_path)
        return False


def rename_config():
    """重命名配置文件"""
    import time
    src = os.path.join(APP_DIR, CONFIG_EXAMPLE)
    dst = os.path.join(APP_DIR, CONFIG_FILE)

    if os.path.exists(src):
        if os.path.exists(dst):
            # 备份旧配置文件
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            backup_name = f"config.{timestamp}.yaml"
            backup_path = os.path.join(APP_DIR, backup_name)
            os.rename(dst, backup_path)
            print(f"已备份旧配置文件 -> {backup_name}")
        os.rename(src, dst)
        print(f"已重命名 {CONFIG_EXAMPLE} -> {CONFIG_FILE}")
        return True
    else:
        print(f"未找到配置文件: {src}")
        return False


def verify_version():
    """验证版本"""
    exe_path = os.path.join(APP_DIR, EXE_NAME)
    if os.path.exists(exe_path):
        print("\n验证安装:")
        subprocess.run([exe_path, "--help"])
        return True
    return False


def main():
    print("=" * 50)
    print("CLIProxyAPI 自动更新脚本")
    print("=" * 50)

    # 步骤 1: 检查当前版本
    current_version = get_current_version()
    if current_version:
        print(f"当前版本: {current_version}")
    else:
        print("未检测到已安装版本，将下载最新版本")

    # 步骤 2: 获取最新版本
    latest_version = get_latest_version()
    if not latest_version:
        print("无法获取最新版本，退出")
        sys.exit(1)

    print(f"最新版本: {latest_version}")

    # 步骤 3: 版本比较
    if current_version == latest_version:
        print("\n当前已是最新版本，无需更新")
        verify_version()
        return

    print(f"\n发现新版本: {latest_version}，开始更新...")

    # 步骤 4: 下载并解压
    if not download_and_extract(latest_version):
        sys.exit(1)

    # 步骤 5: 重命名配置文件
    rename_config()

    # 步骤 6: 验证版本
    verify_version()

    print("\n更新完成!")


if __name__ == "__main__":
    main()
