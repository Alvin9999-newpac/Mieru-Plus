# Mieru-Plus

mieru 一键安装脚本，自动搭建 TCP 和 UDP 账号，生成官方配置和 Clash Meta / Mihomo 配置。

---

## 特性

- 一键安装，全程无需手动填写配置
- 自动生成 **TCP 账号** 和 **UDP 账号** 各一个，端口随机
- 安装完成后直接输出客户端 JSON 配置和 Clash Meta / Mihomo 配置片段
- 自动配置防火墙（支持 ufw / iptables）
- 支持 BBR 加速一键开启
- VPS 重启后服务自动恢复（systemd 托管）
- 支持 Debian / Ubuntu / CentOS / Rocky Linux

---

## 使用方法

```bash
wget -O mieru-plus.sh https://raw.githubusercontent.com/Alvin9999-newpac/Mieru-Plus/main/mieru-plus.sh && chmod +x mieru-plus.sh && bash mieru-plus.sh
```

或者下载后运行：

```bash
curl -fsSL -o mieru-plus.sh https://raw.githubusercontent.com/Alvin9999-newpac/Mieru-Plus/main/mieru-plus.sh && chmod +x mieru-plus.sh && bash mieru-plus.sh
```

---

## 菜单说明

```
 ================================================
   Mieru 管理脚本
   https://github.com/Alvin9999-newpac/Mieru-Plus
 ================================================
 BBR 加速：  已启用
 服务状态：  运行中
 当前版本：  v3.28.0
 ------------------------------------------------
 1. 安装 / 重装
 2. 查看节点 & 配置
 3. 重启服务
 4. 一键开启 BBR
 5. 查看实时日志
 6. 卸载
 0. 退出
 ================================================
```

| 选项 | 说明 |
|------|------|
| 1 | 自动下载最新版 mita，生成两个账号（TCP + UDP），写入配置并启动服务 |
| 2 | 查看当前节点信息、客户端 JSON 配置、Clash Meta 配置片段 |
| 3 | 重启 mita 服务 |
| 4 | 一键开启 BBR 网络加速（需内核 4.9+） |
| 5 | 实时查看 mita 运行日志（Ctrl+C 退出） |
| 6 | 卸载 mita 及所有配置文件 |

---

## 安装效果示例

安装完成后自动输出：

```
 ========== 节点信息 ==========

 [账号 1 · TCP]
  服务器 : 1.2.3.4
  端口   : 38291
  协议   : TCP
  用户名 : tcp_ab3c9f2e
  密码   : Xk9mPqR2sLwN4vZj

 [账号 2 · UDP]
  服务器 : 1.2.3.4
  端口   : 22183
  协议   : UDP
  用户名 : udp_lxkjmxbv
  密码   : yGt8BvuxKr0Qufo8

 [客户端 JSON 配置 · TCP 账号]
{
  "profiles": [
    {
      "profileName": "mieru-tcp",
      "user": { "name": "tcp_ab3c9f2e", "password": "Xk9mPqR2sLwN4vZj" },
      "servers": [{
        "ipAddress": "1.2.3.4",
        "domainName": "",
        "portBindings": [{ "port": 38291, "protocol": "TCP" }]
      }],
      "mtu": 1375
    }
  ],
  "activeProfile": "mieru-tcp",
  "rpcPort": 8964,
  "socks5Port": 1080,
  "loggingLevel": "INFO"
}

 [客户端 JSON 配置 · UDP 账号]
{ ... }

 [Clash Meta / Mihomo 配置]
proxies:
  - name: mieru-tcp
    type: mieru
    server: 1.2.3.4
    port: 38291
    transport: tcp
    username: tcp_ab3c9f2e
    password: Xk9mPqR2sLwN4vZj

  - name: mieru-udp
    ...
```

---

## 客户端使用

### 官方客户端

1. 从 [mieru releases](https://github.com/enfein/mieru/releases) 下载对应平台的客户端
2. 将安装输出的 JSON 配置保存为 `config.json`
3. 执行：
   ```bash
   mieru apply config config.json
   mieru start
   ```
4. 本地 SOCKS5 代理地址：`127.0.0.1:1080`，HTTP 代理：`127.0.0.1:8080`

### Clash Meta / Mihomo

将输出的配置片段复制到 Clash 配置文件的 `proxies:` 部分即可。

支持的客户端：

**桌面端（Windows / macOS / Linux）**
- [Clash Verge Rev](https://www.clashverge.dev/)
- [Mihomo Party](https://mihomo.party/)

**Android**
- [ClashMetaForAndroid](https://github.com/MetaCubeX/ClashMetaForAndroid)
- [Karing](https://karing.app/)

**iOS**
- [ClashMi](https://clashmi.app/)
- [Karing](https://karing.app/)

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Debian 10+ / Ubuntu 20.04+ / CentOS 7+ / Rocky Linux 8+ |
| 架构 | x86_64 / aarch64 |
| 内存 | 128MB 以上 |
| 权限 | root |

---

## 常用命令

```bash
# 查看服务状态
mita status

# 查看当前配置
mita describe config

# 查看日志
journalctl -u mita -f

# 手动启动 / 停止
mita start
mita stop
```

---

## 相关项目

- [mieru](https://github.com/enfein/mieru) — 本脚本所使用的代理核心
- [Sing-Box-Plus](https://github.com/Alvin9999-newpac/Sing-Box-Plus) — 同类一键脚本参考

---

## License

MIT
