# 版本台账（公开版）

格式 `open-主.次.修`。每次改动产品文件（`index.html` / `config.js` / `lib` / `islands` / `server`）至少 +1；纯文档维护不触发；回滚用新号并写记录。

每次交付四件事：HTML `fi-version` meta → JS `FI_VERSION` → 本文件新增一行 → `CHANGELOG.md` 新增一条 `## open-X.Y.Z`。

| 版本 | 日期 | 状态 | 改动摘要 | 记录 |
|---|---|---|---|---|
| `open-0.1.0` | 2026-11-12 | 已发布（GitHub + Gitee 公开仓库） | 从内部 `v3.1.3` 派生首个公开快照：移除硬编码端点/密钥/分享码/本机路径，改为配置外置 + 全链路离线短路；补 README / SECURITY / ASSESSMENT / 台账 | [详情](CHANGELOG.md) |
