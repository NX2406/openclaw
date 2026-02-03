<div align="center">

# 🎯 OpenClaw 完整管理工具

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/NX2406/openclaw-uninstaller)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0+-orange.svg)](https://www.gnu.org/software/bash/)
[![Lines](https://img.shields.io/badge/lines-1624-yellow.svg)](openclaw-manager-all.sh)

**功能全集成 • 界面精美 • 操作简单**

一键管理 OpenClaw 的完整生命周期：安装、配置、卸载

[快速开始](#-快速开始) • [功能特性](#-功能特性) • [使用文档](#-使用文档) • [截图展示](#-界面展示)

</div>

---

## 🌟 功能特性

<table>
<tr>
<td width="50%">

### 🚀 安装与更新
- ✅ 三种安装方式
  - 官方脚本（推荐）
  - npm 全局安装
  - Git 源码编译
- ✅ 自动依赖检测
- ✅ Node.js v22+ 支持
- ✅ 安装进度可视化

</td>
<td width="50%">

### 🔐 OAuth 管理
- ✅ 多账号无限支持
- ✅ Google Gemini / Claude
- ✅ 一键切换账号
- ✅ 自动切换功能
- ✅ 配置自动备份

</td>
</tr>
<tr>
<td width="50%">

### 💬 Telegram 集成
- ✅ 配对码批准/拒绝
- ✅ 设备管理
- ✅ 实时状态监控
- ✅ 连接数显示
- ✅ 待批准提醒

</td>
<td width="50%">

### 🗑️ 完整卸载
- ✅ Docker 组件清理
- ✅ npm/pnpm 包清理
- ✅ 配置文件清理
- ✅ 系统服务停止
- ✅ Shell 配置清理

</td>
</tr>
</table>

---

## 🎨 界面展示

### 主菜单
```
┌─────────────────────────────────────────┐
│         OpenClaw 管理工具 v2.0.0        │
│   安装 | 卸载 | OAuth | TG Bot          │
└─────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
● OpenClaw 状态: 已安装 (v1.2.3)
○ OAuth 账号: 3 个 (自动切换: 已启用)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【 安装与更新 】
  1. 安装/更新 OpenClaw

【 卸载管理 】
  2. 扫描已安装组件
  3. 一键完整卸载
  4. 选择性卸载

【 OAuth 管理 】
  5. OAuth 账号管理

【 Telegram 】
  6. Telegram 机器人管理

【 其他 】
  7. 查看日志
  8. 帮助信息
  0. 退出
```

### OAuth 账号列表
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  总计: 3 个账号
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  账号 ID              提供商             邮箱                       状态
  ───────────────────────────────────────────────────────────────────
  account-1704123456   google-gemini      user1@gmail.com        ✓ 活动
  account-1704123789   claude             user2@gmail.com          未活动
  account-1704124000   google-gemini      user3@gmail.com          未活动

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔄 自动切换: 已启用
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🚀 快速开始

### 一键运行

```bash
# 方式 1: 在线运行（推荐）
bash <(curl -fsSL https://raw.githubusercontent.com/NX2406/openclaw-uninstaller/main/openclaw-manager-all.sh)

# 方式 2: 下载后运行
wget https://raw.githubusercontent.com/NX2406/openclaw-uninstaller/main/openclaw-manager-all.sh
chmod +x openclaw-manager-all.sh
./openclaw-manager-all.sh
```

### 新用户完整流程

```bash
# 1️⃣ 运行脚本
bash openclaw-manager-all.sh

# 2️⃣ 选择 [1] 安装 OpenClaw
#    → 自动检查依赖
#    → 选择官方脚本
#    → ✅ 安装完成

# 3️⃣ 选择 [5] OAuth 账号管理
#    → 选择 [2] 添加新账号
#    → 完成 OAuth 认证
#    → ✅ 账号配置完成

# 4️⃣ 选择 [6] Telegram 机器人
#    → 在 TG 发送配对请求
#    → 选择 [1] 批准配对
#    → ✅ 配对成功

# 🎉 全部完成！
```

---

## 📖 使用文档

### 命令行选项

```bash
# 显示帮助信息
./openclaw-manager-all.sh --help

# 显示版本
./openclaw-manager-all.sh --version

# 仅扫描系统（不卸载）
./openclaw-manager-all.sh -s

# 一键完整卸载（自动确认）
./openclaw-manager-all.sh -y
```

### 配置文件

```
~/.openclaw/
├── credentials/
│   ├── oauth.json              # OAuth 配置
│   └── oauth-staging.json      # 临时配置
├── backups/
│   └── oauth.json.backup.*     # 自动备份（保留10个）
└── telegram-config.json        # TG 配置
```

### OAuth 配置格式

```json
{
  "accounts": [
    {
      "id": "account-1704123456",
      "provider": "google-gemini",
      "email": "user@gmail.com",
      "access_token": "ya29.xxx",
      "refresh_token": "1//xxx",
      "is_active": true,
      "added_at": "2024-01-01T12:00:00Z"
    }
  ],
  "auto_switch": true,
  "active_account_id": "account-1704123456"
}
```

---

## 💡 高级功能

### OAuth 自动切换

启用自动切换后，OpenClaw 会在账号配额用尽时自动切换到下一个可用账号：

```bash
# 在 OAuth 管理菜单
选择 [5] 启用/禁用自动切换
```

### 配置备份与恢复

所有 OAuth 配置修改前会自动备份到 `~/.openclaw/backups/`：

```bash
# 恢复备份
cp ~/.openclaw/backups/oauth.json.backup.20240101_120000 \
   ~/.openclaw/credentials/oauth.json
```

### 选择性卸载

不想完全卸载？可以只删除特定组件：

```bash
# 主菜单 → [4] 选择性卸载
# 然后选择要删除的组件：
1. Docker 组件
2. npm 包
3. 配置目录
4. 系统服务
5. 可执行文件
6. Shell 配置
7. 缓存文件
```

---

## 🔧 技术细节

### 代码统计

| 指标 | 数值 |
|------|------|
| 总行数 | 1624 |
| 文件大小 | ~55KB |
| 功能模块 | 4 个 |
| 菜单选项 | 8 个 |
| 子菜单 | 3 个 |

### 代码分布

```
安装模块 (5.7%)    ████
OAuth模块 (23.6%)  ███████████████████████
TG模块 (6.2%)      ██████
卸载模块 (26.5%)   ██████████████████████████
菜单UI (23.8%)     ███████████████████████
辅助函数 (6.5%)    ██████
配置入口 (7.8%)    ███████
```

### 依赖要求

**必需：**
- Bash 4.0+
- curl
- Node.js v22+（运行 OpenClaw）
- Git（源码安装需要）

**可选：**
- jq（OAuth 功能）
- Docker（Docker 安装方式）

---

## 🐛 故障排除

### 常见问题

<details>
<summary><b>Q: OAuth 功能提示 jq 未安装？</b></summary>

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```
</details>

<details>
<summary><b>Q: 安装失败怎么办？</b></summary>

1. 检查 Node.js 版本：`node --version`（需要 >= v22）
2. 尝试其他安装方式（npm 或 Git）
3. 查看详细日志：选择 [7] 查看日志
</details>

<details>
<summary><b>Q: 如何完全卸载？</b></summary>

```bash
# 方式1: 使用脚本
./openclaw-manager-all.sh
# 选择 [3] 一键完整卸载

# 方式2: 命令行
./openclaw-manager-all.sh -y

# 方式3: 手动清理
rm -rf ~/.openclaw
rm -rf ~/openclaw
npm uninstall -g openclaw
```
</details>

---

## 📊 项目结构

```
openclaw-uninstaller/
├── openclaw-manager-all.sh      # 🌟 完整统一脚本（推荐）
├── README-SHOWCASE.md            # 📖 展示文档（本文件）
├── README-UNIFIED.md             # 📚 详细技术文档
├── LICENSE                       # ⚖️  MIT 许可证
│
├── openclaw-install.sh           # 🔧 独立安装脚本
├── openclaw-oauth.sh             # 🔐 独立 OAuth 脚本
├── openclaw-tg.sh                # 💬 独立 TG 脚本
└── uninstall.sh                  # 🗑️  独立卸载脚本
```

---

## 🎯 设计理念

### 💎 核心原则

1. **一体化** - 所有功能集成在单个脚本
2. **美观性** - 精心设计的彩色 UI 界面
3. **易用性** - 清晰的菜单和智能提示
4. **安全性** - 自动备份和二次确认

### 🎨 UI 设计

- ✨ 全彩色 ANSI 终端界面
- 📊 Unicode 边框和分隔线
- 😀 Emoji 图标标识
- 📋 表格化数据展示
- 🔄 实时状态监控

---

## 📝 更新日志

### v2.0.0 (2026-02-03)

**🎉 重大更新**
- ✅ 完整功能整合（安装/卸载/OAuth/TG）
- ✅ 全新美化界面
- ✅ 表格化数据展示
- ✅ 实时状态监控
- ✅ 自动配置备份
- ✅ 智能步骤提示

**📈 数据**
- 代码行数：1624 行
- 功能模块：4 个
- UI 美化：全面重构

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发指南

```bash
# 1. Fork 项目
git clone https://github.com/NX2406/openclaw-uninstaller.git

# 2. 创建分支
git checkout -b feature/amazing-feature

# 3. 提交更改
git commit -m "Add amazing feature"

# 4. 推送分支
git push origin feature/amazing-feature

# 5. 创建 Pull Request
```

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

---

## 🌐 相关链接

- 🏠 [项目首页](https://github.com/NX2406/openclaw-uninstaller)
- 📖 [详细文档](README-UNIFIED.md)
- 🐛 [问题反馈](https://github.com/NX2406/openclaw-uninstaller/issues)
- 📰 [更新日志](CHANGELOG.md)
- 🌟 [OpenClaw 官网](https://openclaw.bot)

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star！**

Made with ❤️ by [NX2406](https://github.com/NX2406)

</div>
