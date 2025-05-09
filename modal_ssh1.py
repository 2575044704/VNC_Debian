import os
os.system("pip install paramiko")
import socket
import sys
import threading
import paramiko
import select
import time
# 配置参数
USERNAME = 'user'
PASSWORD = os.environ.get('SSH_PASSWORD')
HOST = 'server.lovedraw.cn'
REMOTE_PORT = 5901
LOCAL_HOST = '127.0.0.1'
LOCAL_PORT = 5901
KEEP_ALIVE_INTERVAL = 60  # 发送保持连接的间隔时间（秒）

# 定义一个类来处理转发请求
class ReverseForwardServer(threading.Thread):
    def __init__(self, transport, remote_port, local_host, local_port):
        super(ReverseForwardServer, self).__init__()
        self.transport = transport
        self.remote_port = remote_port
        self.local_host = local_host
        self.local_port = local_port
        self.daemon = True  # 使线程随主线程退出
        self.start()

    def run(self):
        # 请求远程端口转发
        try:
            self.transport.request_port_forward('', self.remote_port)
            print(f"请求在远程服务器上监听端口 {self.remote_port}，转发到本地 {self.local_host}:{self.local_port}")
        except Exception as e:
            print(f'无法请求远程端口转发: {e}')
            sys.exit(1)

        while True:
            try:
                chan = self.transport.accept(1000)  # 等待新连接，超时1秒
                if chan is None:
                    continue
                thr = threading.Thread(target=self.handle_channel, args=(chan,))
                thr.daemon = True
                thr.start()
            except Exception as e:
                print(f"处理通道时发生错误: {e}")
                break

    def handle_channel(self, chan):
        try:
            # 连接到本地服务
            sock = socket.socket()
            sock.connect((self.local_host, self.local_port))
        except Exception as e:
            print(f"无法连接到本地服务 {self.local_host}:{self.local_port}: {e}")
            chan.close()
            return

        print(f"建立连接: {chan.origin_addr} -> {self.local_host}:{self.local_port}")

        # 双向转发数据
        def forward(src, dst):
            try:
                while True:
                    data = src.recv(1024)
                    if not data:
                        break
                    dst.sendall(data)
            except Exception:
                pass
            finally:
                src.close()
                dst.close()

        # 启动两个线程进行数据转发
        t1 = threading.Thread(target=forward, args=(chan, sock))
        t2 = threading.Thread(target=forward, args=(sock, chan))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()

def main():
    while True:  # 自动重连循环
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # 自动添加主机密钥

        try:
            print(f"正在连接到 {HOST}...")
            client.connect(hostname=HOST, username=USERNAME, password=PASSWORD)
            print("连接成功！")

            transport = client.get_transport()
            if transport is None or not transport.is_active():
                print("SSH Transport不可用")
                raise Exception("SSH Transport不可用")

            # 设置保持连接（发送心跳）
            transport.set_keepalive(KEEP_ALIVE_INTERVAL)
            print(f"已设置保持连接，每 {KEEP_ALIVE_INTERVAL} 秒发送一次心跳包")

            # 启动反向端口转发服务器
            ReverseForwardServer(transport, REMOTE_PORT, LOCAL_HOST, LOCAL_PORT)

            print(f"已在远程服务器 {HOST} 上监听端口 {REMOTE_PORT}，并转发到本地 {LOCAL_HOST}:{LOCAL_PORT}")

            # 保持主线程运行，并监控连接状态
            while transport.is_active():
                time.sleep(1)

        except KeyboardInterrupt:
            print("用户中断，关闭连接。")
            break
        except Exception as e:
            print(f"发生错误: {e}")
            print("尝试重新连接...")
            time.sleep(5)  # 等待5秒后重试
        finally:
            client.close()
            print("SSH连接已关闭。")

if __name__ == "__main__":
    main()