# 🧹 OpenClaw 一键卸载工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

> 完整卸载 OpenClaw (原名 ClawdBot/Moltbot) 的一键脚本

## ✨ 功能特点

- 🎨 **交互式菜单界面** - 美观易用的 TUI 菜单
- 🔍 **智能扫描** - 自动检测已安装的组件
- 🐳 **Docker 支持** - 清理容器、镜像和数据卷
- 📦 **包管理器支持** - npm/pnpm/yarn 全局包
- ⚙️ **服务管理** - systemd 服务和 Gateway
- 📁 **完整清理** - 配置目录、缓存和临时文件
- 📝 **日志记录** - 详细的操作日志

## 🚀 快速开始

### 一键运行 (推荐)

```bash
curl -fsSL (https://raw.githubusercontent.com/NX2406/openclaw/refs/heads/main/uninstall.sh) | bash
```

### 下载后运行

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/NX2406/openclaw-uninstaller/main/uninstall.sh

# 添加执行权限
chmod +x uninstall.sh

# 运行
./uninstall.sh
```

## 📖 使用说明

### 交互式模式

直接运行脚本即可进入交互式菜单:

```bash
./uninstall.sh
```

菜单选项:
1. **扫描系统** - 查找所有已安装的 OpenClaw 组件
2. **一键完整卸载** - 删除所有检测到的组件
3. **选择性卸载** - 自定义选择要删除的组件
4. **查看卸载日志** - 查看操作记录
5. **帮助信息** - 获取使用帮助

### 命令行参数

```bash
# 显示帮助
./uninstall.sh --help

# 仅扫描 (不卸载)
./uninstall.sh --scan

# 自动确认所有操作 (非交互模式)
./uninstall.sh --yes

# 显示版本
./uninstall.sh --version
```

## 🗑️ 清理内容

此脚本会检测并清理以下内容:

### Docker 组件
- OpenClaw/ClawdBot 相关容器
- 相关 Docker 镜像
- Docker 数据卷和网络

### 包管理器
- npm 全局包: `openclaw`, `clawdbot`, `moltbot`, `@openclaw/cli`
- pnpm 全局包
- yarn 全局包

### 配置和数据
- `~/.openclaw` - OpenClaw 配置目录
- `~/.clawdbot` - ClawdBot 配置目录 (旧版)
- `~/.moltbot` - Moltbot 配置目录 (旧版)
- `~/openclaw` - 工作区目录
- `~/clawdbot` - 工作区目录 (旧版)
- `~/clawd` - 工作区目录

### 系统服务
- systemd 服务文件
- Gateway 服务
- 运行中的进程

### 可执行文件
- `/usr/local/bin/openclaw`
- `/usr/local/bin/clawdbot`
- `~/.local/bin/openclaw`
- 其他相关二进制文件

### Shell 配置
- `.bashrc` 中的相关配置
- `.zshrc` 中的相关配置
- `.bash_profile` / `.profile` 中的相关配置

## 📸 截图

```
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗║
║  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║║
║  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║║
║  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║║
║  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝║
║   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ║
║                                                                       ║
║                    🧹 一键卸载工具 v1.0.0                              ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

  请选择操作:

    1. 🔍 扫描系统 - 查找已安装的组件
    2. 🚀 一键完整卸载 - 删除所有组件
    3. 📋 选择性卸载 - 自定义卸载项目
    4. 📊 查看卸载日志
    5. ❓ 帮助信息
    0. 🚪 退出
```

## ⚠️ 注意事项

1. **备份重要数据** - 运行前请确保备份重要的工作区文件和配置
2. **权限要求** - 某些操作可能需要 sudo 权限
3. **Shell 配置备份** - 清理 Shell 配置时会自动创建备份文件
4. **不可逆操作** - 删除的数据无法恢复，请谨慎操作

## 🔧 故障排除

### 权限不足
```bash
# 使用 sudo 运行
sudo ./uninstall.sh
```

### 找不到命令
确保脚本有执行权限:
```bash
chmod +x uninstall.sh
```

### Docker 命令失败
确保 Docker 服务正在运行:
```bash
sudo systemctl start docker
```

## 📝 日志

脚本会自动生成操作日志，位置:
```
/tmp/openclaw-uninstall-YYYYMMDD_HHMMSS.log
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📄 许可证

[MIT License](LICENSE)

---

