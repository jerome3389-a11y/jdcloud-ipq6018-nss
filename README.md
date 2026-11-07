# JDCloud IPQ6018 NSS

JDCloud AX1800（RE-SS-01 / RE-CS-02）的 OpenWrt 自动编译项目：最强最完整的 Qualcomm NSS 加速，最新内核，GitHub Actions 自动构建 + 发布。

> 状态：项目新建，尚未发布第一个版本。RE-SS-01（Arthur）是实测目标；RE-CS-02（Athena）只编译、不上机验证（没有 Athena 硬件）。

## 基础版本

| 组件 | 版本 |
| --- | --- |
| 基础树 | LiBwrt/LibWrt `25.12-nss` @ `96a0ec8a`（2026-10-31，pinned） |
| 内核 | 6.12（6.12.112） |
| NSS 固件 | 12.5（12.5-210-MP；可选 12.2） |
| 目标平台 | qualcommax / ipq60xx（DSA） |
| LuCI | Argon 默认主题 |

| Feed | 分支 | Pinned commit |
| --- | --- | --- |
| nss_packages（laipeng668/nss-packages） | NSS-LibWrt | `c425674d` |
| sqm_scripts_nss（qosmio/sqm-scripts-nss） | main | `4b4ed863`（2024-05-12，stale） |
| packages（immortalwrt/packages） | openwrt-25.12 | `fa25995d` |
| luci（immortalwrt/luci） | openwrt-25.12 | `c38e5665` |
| routing（openwrt/routing） | openwrt-25.12 | `48c80803` |
| telephony（openwrt/telephony） | openwrt-25.12 | `c58ec5a6` |
| video（openwrt/video） | openwrt-25.12 | `094bf58d` |

## NSS

| 项目 | 说明 |
| --- | --- |
| NSS 加速 | qca-nss-dp + qca-nss-drv + qca-nss-ecm + 全部管理器（bridge/pppoe/vlan 等） |
| NSS 内存档位 | MEDIUM（512 MB 板子默认值） |
| WiFi NSS offload | ath11k NSS（ATH11K_NSS_SUPPORT 默认开） |
| q6_region | 64 MB（基础树默认 55 MB；WiFi 至少需要 54 MB） |
| 802.11s（MESH） | NSS 固件 12.5 不支持 NSS MESH（只有 11.4 支持）；本项目默认 12.5，MESH 默认关闭 |

NSS 栈来自基础树的 qualcommax 默认包（不是本项目额外加的）：`qca-nss-dp`、`nss-ifb`、`qca-nss-drv`、`qca-nss-ecm` 及全部管理器都在 `target/linux/qualcommax/Makefile` 的 DEFAULT_PACKAGES 里；`ATH11K_NSS_SUPPORT` 默认开，`ATH11K_MEM_PROFILE_512M` 默认，`NSS_MEM_PROFILE` 对 512 MB 板子默认 MEDIUM。构建工作流会在 defconfig 后逐项检查这些默认值确实进了 `.config`，缺一项就失败——静默丢 NSS 的镜像不会发布。

### NSS MESH（802.11s）与固件版本

本项目用 NSS 固件 12.5。12.5 在 IPQ60xx 上**不支持 NSS mesh 卸载**：新固件会拒绝 mesh 接口分配，只有 11.4 支持（固件 Makefile 的版本说明原文；`ATH11K_NSS_MESH_SUPPORT` 选中时也会强制切到 11.4）。所以 12.5 和 NSS mesh 是二选一，本项目选 12.5，mesh 默认关闭。

注意这不是所有 NSS 平台都这样：**IPQ5018（CR880x 项目）上 12.5 可以跑 NSS mesh 卸载**（kuncy7 的 nss-firmware 说明原文：“On IPQ5018 it runs the ath11k NSS mesh offload (802.11s) as well as 12.2”；11.4 是 ipq807x/ipq60xx 上 mesh 需要的版本）。这个限制是 SoC 相关的，别把两个项目的结论混起来。

如果以后这个项目要 mesh，路子是把固件版本换成 11.4——这是一次性的分叉选择，不是开关；目前构建输入只提供 12.5/12.2。

## 固件特性

| 特性 | 支持 | 默认状态 | 实机测试 |
| --- | --- | --- | --- |
| NSS 加速 | 支持 | 默认启用 | 未测试 |
| 双频 WiFi | 支持 | 默认启用 | 未测试 |
| 802.11k（RRM） | 支持 | 默认启用 | 未测试 |
| 802.11v（WNM Sleep + BSS Transition） | 支持 | 默认启用 | 未测试 |
| 802.11r（FT） | 支持 | 默认关闭 | — |
| 802.11s（MESH） | 不支持 NSS 卸载（固件 12.5，见下文） | 默认关闭 | — |
| SQM（NSS nssfq_codel） | 支持 | 默认关闭 | — |
| sing-box（命令行） | 支持 | 已安装，未配置（用户用命令行运行 `sing-box run -c <配置文件>`，自行加载配置；无 LuCI 管理界面，PassWall 已于 2026-11-08 移除） | 未测试 |
| TTYD 网页终端 | 支持 | 已安装（在 LuCI 里打开） | — |
| SFTP 服务端 | 支持 | 随 SSH 提供 | — |
| ARP 绑定 / USB 打印机 | 支持 | 已安装（在 LuCI 里配置） | — |
| Adblock | 支持 | 默认启用 | 未测试 |
| UPnP | 支持 | 默认关闭 | — |
| 内核流量分载 | 支持 | 默认关闭（必须关，ECM 才是分载路径） | — |
| IGMP snooping | 支持 | 默认关闭 | — |
| zram-swap | 支持 | 默认启用 | 未测试 |
| 5G 160 MHz | RE-SS-01 不支持（硬件上限 80 MHz）；RE-CS-02 支持（QCN9074） | — | 未测试 |

## 出厂默认凭证

| 项目 | 默认值 |
| --- | --- |
| WiFi 2.4G SSID | OpenWrt |
| WiFi 5G SSID | OpenWrt_5G |
| WiFi 密码 | 12345678（WPA2） |
| Root 密码 | password |
| LAN IP | 192.168.1.1（固件默认） |
| 主机名 | OpenWrt（固件默认） |

> 这些是公开的出厂默认值，刷机后请立即修改 Root 密码和 WiFi 密码。

## 支持的型号

| 固件（profile） | 支持的设备 | 芯片 | 状态 |
| --- | --- | --- | --- |
| `jdcloud_re-ss-01` | JDCloud RE-SS-01（Arthur） | IPQ6018 + QCA8075；2.4G IPQ6018 内置；5G QCN6122（80 MHz 上限） | 未上机验证 |
| `jdcloud_re-cs-02` | JDCloud RE-CS-02（Athena） | IPQ6018 + QCN9074（5G，160 MHz）；2.4G IPQ6018 内置 | 未上机验证 |
| — | 其他所有型号 | — | 不支持，刷错变砖 |

认板看主板版号 + 板型，不要只看型号。RE-SS-01 和 RE-CS-02 是不同硬件，固件不可互刷。

## 刷机与首次开机

- **升级（已有 OpenWrt/ImmortalWrt 在运行）**：用 `sysupgrade.bin`，LuCI（系统 → 备份/升级）或命令行 `sysupgrade` 刷入。升级保留配置可选（建议首次升级不保留，从干净状态开始）。
- **首次安装**：用 `factory.bin`（FIT 镜像），走设备的原厂 web 升级或 U-Boot 恢复刷入（与参考项目 fork 固件同一路子）。**首次安装的具体步骤尚未实测确认**——第一台设备刷机前请先在实机上确认入口，确认后补到这里。
- **恢复**：构建产物包含 `initramfs` 镜像（workflow artifact 里），可用于 TFTP 启动恢复（未实测）。
- **首次开机**：双频 WiFi 默认开启，SSID/密码见上表；5G 启动可能较慢（自动信道扫描 + DFS 检测，最长约 10 分钟），属正常现象，不是故障。
- **DNS**：默认 dnsmasq 缓存 1000 条，监听 lan 接口，缓存 ANY/A/AAAA 记录类型（与 CR880x 项目相同的默认值）。

## 编译

手动触发（workflow_dispatch），无定时自动构建。

| 输入 | 选项 | 默认 |
| --- | --- | --- |
| device | `all` / `re-ss-01` / `re-cs-02` | `all`（两个设备同一 run、同一 HEAD 并行编） |
| firmware | `12.5` / `12.2` | `12.5` |
| base_ref | LiBwrt 25.12-nss commit | `96a0ec8a`（pinned） |

每次构建发布一个 draft → 校验 digest → publish 的 release，含 `factory.bin` + `sysupgrade.bin` 两个镜像；构建证据（config.buildinfo、feeds.buildinfo、full.config、third-party-sources.txt、sha256sums.txt）随 workflow artifact 保存 90 天。

构建失败时工作流会保留诊断信息（见 Diagnose 步骤）；修复原则：先读原文找原因，再改代码，单变量实验，成功以实机运行为准（不以编译成功为准）。

## 给 fork 者的建议与注意事项

- 基础树和 feeds 全部 pinned：改 `feeds.conf` 或 `base_ref` 前请确认新 commit 的 NSS 栈没有回归。
- 插件和软件每次构建自动用最新版（2026-11-06 起的规则）：sing-box（DIY 从 SagerNet 最新 release 取）、Argon、Athena LED（都从 master 取）每次构建都拉最新；基础树和 feeds 保持 pinned，只有插件/软件浮动到最新版。PassWall 已于 2026-11-08 移除（用户直接用命令行运行 sing-box）。
- LuCI 语言是英文（`# CONFIG_LUCI_LANG_zh_Hans is not set`）：英文是 LuCI 的源语言、没有可选项，LiBwrt 树默认中文；配置里必须明确取消中文，否则 `make defconfig` 会把中文语言包重新加回来。
- NSS 固件版本是单选：12.5 和 12.2 只能选一个；12.5 不支持 NSS MESH。
- q6_region 不要低于 54 MB（WiFi 会起不来）；RE-SS-01 用 64 MB，RE-CS-02 不走这条 DTS，不要动。
- RE-CS-02 的无线配置（PCIe 路径、HE160）是从 DTS 推导的，未上机验证；Athena 上 WiFi 不起来时先删静态无线文件，让系统自动检测生成配置，再从 `/etc/board.json` 查真实路径。
- 不要把本项目的 `files/` 静态无线直接搬到别的 IPQ6018 设备上：IPQ6018 只有一个 wifi 节点（`wifi@c000000`），两频共用一条 path，靠 `option radio` 区分——和 IPQ50xx 的双节点结构不一样。

## 合规

本项目基于 LiBwrt/LibWrt（GPLv2）及 OpenWrt/ImmortalWrt 相关组件构建；固件仅供个人学习与自用。
