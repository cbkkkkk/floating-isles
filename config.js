/* 公开版默认配置：三个值全部留空 => 离线模式，页面零网络请求。
 *
 * 接入自己的后端时填写下面三个值即可。填好真实配置后请勿提交本文件，
 * 建议改用本地忽略：
 *   git update-index --skip-worktree config.js
 *
 * 这三个值应当来自你自己后端服务的 publicConfig，不是任何第三方平台的
 * 生产凭据。本项目不提供、也不要求任何现成的服务端地址。 */
window.FI_CLOUD_CONFIG = {
  endpoint: '',
  publishableKey: '',
  oauthRelayBaseUrl: ''
};
