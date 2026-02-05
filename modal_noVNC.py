#!/usr/bin/env python3
"""
通过 Modal 的 forward 函数将 VNC 桌面映射为可访问的 URL
需要先安装 noVNC: apt install -y novnc websockify
"""

import modal
import subprocess
import time
import os
import signal
import sys

# noVNC 网页端口（websockify 监听）
NOVNC_PORT = 6080
# 本机 VNC 端口
VNC_PORT = 5901

def start_novnc():
    """启动 noVNC websockify，将 VNC 转为网页"""
    # 查找 noVNC 网页文件路径
    novnc_paths = [
        "/usr/share/novnc/",
        "/usr/share/novnc/utils/../",
        "/opt/novnc/",
    ]
    
    novnc_web = None
    for p in novnc_paths:
        if os.path.exists(p):
            novnc_web = p
            break
    
    if not novnc_web:
        print("错误: 未找到 noVNC，请先运行: apt install -y novnc websockify")
        sys.exit(1)
    
    # 启动 websockify
    proc = subprocess.Popen(
        ["websockify", "--web", novnc_web, str(NOVNC_PORT), f"localhost:{VNC_PORT}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    time.sleep(2)
    
    if proc.poll() is not None:
        print(f"错误: websockify 启动失败")
        print(proc.stderr.read().decode())
        sys.exit(1)
    
    print(f"✓ noVNC 已启动 (本地端口 {NOVNC_PORT} -> VNC {VNC_PORT})")
    return proc

def main():
    # 安装 noVNC（如果没有）
    if not os.path.exists("/usr/bin/websockify"):
        print("正在安装 noVNC...")
        subprocess.run(["apt", "install", "-y", "novnc", "websockify"], 
                       capture_output=True)
    
    # 启动 noVNC
    novnc_proc = start_novnc()
    
    # 通过 Modal 暴露端口
    print(f"\n正在通过 Modal 创建公网链接...")
    with modal.forward(NOVNC_PORT, unencrypted=True) as tunnel:
        hostname, remote_port = tunnel.tcp_socket
        url = f"http://{hostname}:{remote_port}/vnc.html"
        
        print(f"\n{'='*50}")
        print(f"  ✓ VNC 桌面已就绪！")
        print(f"  浏览器打开: {url}")
        print(f"{'='*50}")
        print(f"\n按 Ctrl+C 停止\n")
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n正在停止...")
            novnc_proc.terminate()
            print("已停止")

if __name__ == "__main__":
    main()
