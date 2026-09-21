#!/bin/sh
set -e

echo "=========================================="
echo " Alpine 容器版 Sing-box + Cloudflared 部署"
echo "=========================================="

# 1. 检查或读取 Token
if [ -n "$1" ]; then
  CF_TOKEN="$1"
else
  printf "请输入你的 Cloudflare Tunnel Token: "
  read -r CF_TOKEN
fi

if [ -z "$CF_TOKEN" ]; then
  echo "[-] 错误: Token 不能为空！"
  exit 1
fi

# 2. 安装基础依赖
echo "[+] 正在更新 apk 索引并安装必要依赖..."
apk update
apk add --no-cache curl wget bash jq ca-certificates gcompat tar

# 3. 架构检测
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    SING_ARCH="amd64"
    CF_ARCH="amd64"
    ;;
  aarch64|arm64)
    SING_ARCH="arm64"
    CF_ARCH="arm64"
    ;;
  *)
    echo "[-] 暂不支持的系统架构: $ARCH"
    exit 1
    ;;
esac

# 4. 下载并安装 Sing-box
echo "[+] 正在安装 Sing-box..."
mkdir -p /tmp/singbox /usr/local/bin /etc/sing-box /var/log

SING_VER=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name | sed 's/^v//')
if [ -z "$SING_VER" ] || [ "$SING_VER" = "null" ]; then
  SING_VER="1.11.4"
fi

wget -qO /tmp/singbox.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v${SING_VER}/sing-box-${SING_VER}-linux-${SING_ARCH}.tar.gz"
tar -xzf /tmp/singbox.tar.gz -C /tmp/singbox --strip-components=1
mv /tmp/singbox/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf /tmp/singbox*

# 5. 下载并安装 Cloudflared
echo "[+] 正在安装 Cloudflared..."
wget -qO /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
chmod +x /usr/local/bin/cloudflared

# 6. 生成随机 UUID 与 WebSocket 路径
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | head -c 32 | sed -r 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')
WS_PATH="/$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)"
PORT=10000

# 7. 写入 Sing-box 配置文件
cat << CFG > /etc/sing-box/config.json
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": ""
        }
      ],
      "transport": {
        "type": "ws",
        "path": "${WS_PATH}"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
CFG

# 8. 生成常驻拉起脚本
cat << RUNNER > /root/run_proxy.sh
#!/bin/sh
killall sing-box 2>/dev/null || true
killall cloudflared 2>/dev/null || true
sleep 1

nohup /usr/local/bin/sing-box run -c /etc/sing-box/config.json > /var/log/sing-box.log 2>&1 &
nohup /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "${CF_TOKEN}" > /var/log/cloudflared.log 2>&1 &

echo "[+] Sing-box 与 Cloudflared 已在后台拉起"
RUNNER

chmod +x /root/run_proxy.sh

# 9. 启动服务
/root/run_proxy.sh

# 10. 输出客户端参数
echo ""
echo "=========================================="
echo "           🎉 部署成功！                  "
echo "=========================================="
echo "客户端填写参数（适用于 Sing-box / v2rayN / Clash 等）："
echo ""
echo "  - 协议 (Type/Protocol)  : vless"
echo "  - 地址 (Server/Address) : 你的CF绑定域名 (或填CF优选IP)"
echo "  - 端口 (Port)           : 443"
echo "  - 用户ID (UUID)         : ${UUID}"
echo "  - 传输层 (Transport)    : ws"
echo "  - 路径 (Path)           : ${WS_PATH}"
echo "  - 安全/加密 (TLS)       : 开启 (enabled)"
echo "  - 域名 (SNI / Host)     : 你的CF绑定域名"
echo "=========================================="
echo "CF Tunnel Public Hostname 规则确认："
echo "  - Type : HTTP"
echo "  - URL  : localhost:${PORT}"
echo "=========================================="
