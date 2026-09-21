# NAT VPS Sing-box + Cloudflare Tunnel 一键部署

适用于 Alpine 容器 / Podman 运行环境，无 systemd 依赖。

## 准备工作
1. 在 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) 控制台中创建一个 Cloudflared Tunnel 并获取 Token。
2. 在 Tunnel 的 Public Hostname 中将你的域名指向 `HTTP` -> `localhost:10000`。

## 一键执行命令

### 方式 1：交互式输入 Token
```sh
sh -c "$(curl -fsSL [https://raw.githubusercontent.com/](https://raw.githubusercontent.com/)<你的GitHub用户名>/<你的仓库名>/main/install.sh)"
```

### 方式 2：非交互式（直接携带 Token 参数）
```sh
sh -c "$(curl -fsSL [https://raw.githubusercontent.com/](https://raw.githubusercontent.com/)<你的GitHub用户名>/<你的仓库名>/main/install.sh)" -- "你的Cloudflare_Token"
```

## 国内网络镜像加速（备选）
如果国内机器访问 `raw.githubusercontent.com` 速度慢或被阻断，可使用代理加速源：
```sh
sh -c "$(curl -fsSL [https://ghproxy.net/https://raw.githubusercontent.com/](https://ghproxy.net/https://raw.githubusercontent.com/)<你的GitHub用户名>/<你的仓库名>/main/install.sh)"
```

## 运维命令
- 查看进程：`ps | grep -E 'sing-box|cloudflared'`
- 查看 Sing-box 日志：`cat /var/log/sing-box.log`
- 查看 Tunnel 连接日志：`cat /var/log/cloudflared.log`
- 容器重启后快速拉起：`/root/run_proxy.sh`
