# 实现边界

- `Configuration.swift`：可序列化的非敏感设置、版本、迁移、校验；API Key 用 Security 钥匙串且按接口地址隔离。
- `Companion.swift`：唯一在途请求、点击时间闸门、35秒超时、关闭与晚回调防护；路由 DSH/Codex/API。客户端调用在独立工作目录，每次不复用对话。
- `APIClient.swift`：文本 Chat Completions 请求与响应，地址校验和重定向拒绝；不将原始响应写进提示或日志。
- `Usage.swift`：发现 CodexBar、读取来源列表、异步逐来源查询；数据保留来源与单位，不合并金额和百分比。
- `SettingsWindow.swift`：草稿配置 → 校验保存 → `onApply`，主应用取消当前生成、更新声音/气泡与刷新计时。客户端连接测试是显式操作。
- `BalancePanel.swift`：只显示选中的额度、关闭、设置与退出；打开卡片自动刷新，设置在独立窗口。
- `Skin.swift` / `PetView.swift` / `SpeechBubble.swift`：皮肤、反馈动画、气泡分别管理；形象资源更换不依赖模型和额度代码。

扩展新的说话客户端：增加 `SpeechBackend` 选项、设置字段和对应调用适配；复用 `CompanionService` 的在途/超时/取消边界，不在视图里发请求。新适配必须有离线错误/取消检查，再标明真实连接的验证范围。这里没有动态插件加载器，也不承诺任意客户端可直接接入。

新的额度来源先通过 CodexBar 支持的 ID 添加，不把各家的登录凭据复制进本项目。换立绘只改皮肤目录，不新增模型后端。

## 0.6.0更新
- BubbleSource.local/model 与模型后端分离；paused保留旧字段表示气泡关闭。LocalLines是无IO的本地选择器，模型请求仍由CompanionService管理。
- Codable缺失字段取默认值；旧配置没bubbleSource但有模型后端则保留model。损坏/未来版本配置回退全关闭，保留原blob并显示diagnostic。
- DSH补丁每请求唯一、0600、正常结束删除；Codex不依赖DSH模板。turn级usage覆盖step累计，取消部分记录标记partial。
- 生成、设置回调及UI状态按主线程契约执行；进程读取转发main。尚未切换Swift6严格并发/SPM。
- API长度参数可选，Keychain service从bundle identifier派生。更换bundle标识需维护者迁移配置与Key，项目不自动读取其他偏好域。

0.6.1：PetPreferences包装生产UserDefaults；测试模式使用注入目录内的plist，无系统suite。AppPaths统一皮肤/history/workspace测试路径；ConfigurationStore记录fresh/loaded来源。CompanionWorkspace父目录与run-PID子目录0700，只清理当前用户所有且PID明确失效的子目录；Codex正文走stdin，DSH模板在私有目录写入，权限失败给明确错误。
