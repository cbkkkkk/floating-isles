# 变更记录（公开版）

> 一条记录 = 一个版本号。写给完全不了解背景的人：只看这条，就能判断改对没有、怎么退回去。
> 本仓库版本独立于内部主线（内部主线为 `v3.1.3`）。

## open-0.1.0 — 2026-11-12　　[首个公开快照]

- **触发**：作者要求把项目发布到公开代码仓库，且「不要有任何个人信息」「不要让别的人攻击我的电脑或服务器」。
- **改动**（文件 + 位置）
  - 新建本仓库，运行时只保留 6 个文件：`index.html`、`lib/three.min.js`、`islands/` × 3、`server/schema.sql`。排除了 3 个备份 HTML、2 个备份台账，并移除平台专有云端 SDK（离线版不需要）。
  - `index.html` → `CLOUD_CFG`（原 1161–1165 行）由硬编码端点 / 密钥 / relay 改为读取 `window.FI_CLOUD_CONFIG`，默认全空；新增 `FI_OFFLINE` 判定。
  - `index.html` → 新增 `<script src="config.js">`，配置落在独立文件 `config.js`（空值模板）。
  - `index.html` → 移除平台云端 SDK 的 `<script>` 引用；`lib/` 只保留 three.js。公开版不携带任何平台专有客户端库。
  - `index.html` → `cloudInit()` 开头离线短路；`rpc()` 在 Promise 入口离线短路（返回 `{ok:0, err:'offline'}`），保证**零网络请求**。
  - `index.html` → 启动区把 `cidInit()` / 两个 `pollerAdd` / `setTimeout(cloudBoot, 60)` 包进 `if (!FI_OFFLINE)`；离线分支隐藏 `btnAcct` / `btnMsg` / `btnEnter`，并显示「离线演示版」提示。
  - 版本号：HTML `fi-version` meta 与 JS `FI_VERSION` 均设为 `open-0.1.0`。
  - 新增 `README.md`（项目介绍 / 运行 / 两种模式）、`SECURITY.md`（安全边界）、`docs/ASSESSMENT.md`（缺陷 + 改造 + 托管迁移）、`config.js`、`.gitignore`、`VERSIONS.md`、本文件。
- **不做什么**
  - 不改动内部主线任何文件，主线版本保持 `v3.1.3`；不动线上站点。
  - 不删除或改写三座内置岛的内容；不擅自决定许可证（README 中标为「待作者确认」）。
  - 不实现后端、不填任何真实端点或密钥；不把任何凭据、账号或本机信息写进仓库内容。
  - 不重写渲染、构图或漫游逻辑——公开版只做脱敏与离线化。
- **验证**
  - 8 处字符串替换各命中 1 次（脚本 `assert count == 1`），后续质检再修 2 行注释并移除 SDK 引用，最终 286,914 B、CRLF 0。
  - 敏感模式复验（扩大到 9 类）：平台密钥 / 托管域名 / 分享码 / 任意邮箱 / Windows 路径 / 盘符路径 / 内部文档名 / 作者标识 / 手机号与内网地址，命中数均为 **0**。
  - 主脚本与 `config.js` 的 `node --check` 均通过；本地静态服务 **8/8** 路径返回 200（含三座内置岛、config.js、schema.sql）；版本四件事一致（meta / JS / 台账 / 记录均 `open-0.1.0`）。
  - 离线分支生效：无头 Chromium 实载，页面与内置岛正常加载（可见 WebGL 驱动消息），页面侧 **0 个外部域名请求**；日志中出现的 Microsoft 登录域来自浏览器自身组件，与仓库无关。
- **过程中发现并修掉的问题**
  - 原始目录里 3 个 `.bak` 文件含旧密钥、分享码、大量本机绝对路径与线上地址；若整目录推送会全部泄露 → 改为白名单式逐文件复制。
  - 全局 git 提交身份是作者的真实邮箱，会写进公开 commit → 本仓库单独配置中性本地身份，不继承全局配置。
  - 只替换密钥而不短路 `rpc()` 仍会向占位域名发请求，且弹出「网络不通」误导文案 → 增加 `FI_OFFLINE` 全链路短路与离线提示。
  - 二进制写入避免把 LF 行尾改成 CRLF（内部主线曾踩过此坑，多出 6,352 字节）。
  - 扩大复验抓到 `index.html` 第 7 行注释里的本机绝对路径、第 11 行内部文档引用 → 按行精确替换清除。
  - SDK 内两处 `wbpk_` 经上下文核对是 `^wbpk_` 格式校验与报错文案，不是真实密钥；但公开离线版不需要平台 SDK，整体移除以消除误报与多余依赖。
  - 浏览器实载打印 `An iframe which has both allow-scripts and allow-same-origin ... can escape its sandboxing.` → 把 A2 缺陷从代码推断升级为实测证据，写进 `SECURITY.md` / `ASSESSMENT.md`，并把「0 条该告警」设为 P0 验收指标。
- **风险 / 已知限制**
  - 这是**前端快照**，不是可投产系统：`allow-scripts + allow-same-origin` 的沙箱逃逸面、匿名接口无限流、无内容审核等缺陷仍存在于代码里，详见 `SECURITY.md` 与 `docs/ASSESSMENT.md`。
  - `server/schema.sql` 是参考实现，缺 `fi_island_add`，与任何实际部署都不完全一致。
  - 许可证未定；`lib/three.min.js` 与内置岛内联的 three.js 为 MIT。
  - 实测确认存在 1 条 sandbox escape 告警；演示版不开放上传入口，但代码缺陷仍在，生产前必须修。
  - 无头浏览器因软件渲染 ReadPixels 卡顿超时（退出码 124，未拿到 dump-dom），构图仍以数值验收 + 人工目视为准。
- **状态 / 备份 / 回滚**
  - 状态：已发布为公开静态仓库（GitHub / Gitee 各一份，地址见仓库页面）；许可证保持「待作者确认」。
  - 源目录 `v3.1.1-publish/` 全程只读未改，是完整回滚点；删除 `floating-isles-open/` 即完全回退，不影响主线。
  - 若需回退离线化改动：把 `index.html` 的 8 处替换逆向还原即可，配置改回 `CLOUD_CFG` 常量；回滚使用新版本号 `open-0.1.1` 并写新记录，不把号退回去。
