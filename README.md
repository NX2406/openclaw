# OpenClaw 一键管理脚本

<p align="center">
  <img src="https://openclaw.ai/logo.png" alt="OpenClaw Logo" width="200">
</p>

<p align="center">
  <strong>🚀 OpenClaw 一键安装 | 卸载 | Telegram 对接</strong>
</p>

<p align="center">
  <a href="#一键安装">快速开始</a> •
  <a href="#功能介绍">功能介绍</a> •
  <a href="#使用说明">使用说明</a> •
  <a href="#常见问题">常见问题</a>
</p>

---

## 📦 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NX2406/openclaw/refs/heads/main/openclaw_manager.sh)
```

或者：

```bash
curl -fsSL https://raw.githubusercontent.com/NX2406/openclaw-manager/main/openclaw_manager.sh | bash
```

## ✨ 功能介绍

| 功能 | 说明 |
|------|------|
| 🟢 一键安装 | 自动更新系统、检查依赖、安装 Node.js、运行官方脚本 |
| 🔴 一键卸载 | 完全删除 OpenClaw，自动检测并清理残留文件 |
| 🔵 Telegram 对接 | 快速绑定 Telegram 机器人 |

## 🖥️ 支持的系统

- ✅ Ubuntu / Debian
- ✅ CentOS / RHEL / Rocky Linux / AlmaLinux
- ✅ Fedora
- ✅ Arch Linux / Manjaro
- ✅ Alpine Linux

## 📖 使用说明

### 方法一：一键运行（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NX2406/openclaw-manager/main/openclaw_manager.sh)
```

### 方法二：下载后运行

```bash
# 下载脚本
wget -O openclaw_manager.sh https://raw.githubusercontent.com/NX2406/openclaw-manager/main/openclaw_manager.sh

# 添加执行权限
chmod +x openclaw_manager.sh

# 运行脚本
./openclaw_manager.sh
```

### 菜单界面

运行脚本后，您将看到以下菜单：

```
   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗
  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║
  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║
  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║
  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝
   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ 

请选择操作:

   1. 一键安装 OpenClaw
   2. 一键卸载 OpenClaw
   3. Telegram 机器人对接

   0. 退出脚本
```

## 🔗 Telegram 机器人对接

1. 在 Telegram 中搜索 OpenClaw 官方机器人
2. 获取您的对接码
3. 运行脚本，选择选项 `3`
4. 输入对接码完成绑定

## ❓ 常见问题

<details>
<summary><b>Q: 安装失败怎么办？</b></summary>

请检查：
1. 确保网络连接正常
2. 查看安装日志：`/tmp/openclaw_install.log`
3. 确保 Node.js 版本 >= 18

</details>

<details>
<summary><b>Q: 如何更新 OpenClaw？</b></summary>

重新运行安装脚本即可自动更新到最新版本。

</details>

<details>
<summary><b>Q: 卸载后数据能恢复吗？</b></summary>

卸载时会询问是否删除数据目录，如选择保留则数据不会丢失。

</details>

## 📜 开源协议

MIT License

## 🔗 相关链接

- [OpenClaw 官网](https://openclaw.ai)
- [OpenClaw 文档](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)

---

<p align="center">
  <sub>Made with ❤️ by NX2406</sub>
</p>

