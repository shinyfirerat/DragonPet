# 小龙娘桌宠 · DragonPet

<p align="center"><img src="Resources/Skins/white-dragon/portrait.png" width="180" alt="默认白毛龙娘皮肤"></p>

一个个人 macOS 桌宠实验：戳一下会压扁、出声、回弹；可选本地台词或模型生成一句闲话，右键查看自己选定的账户额度。形象与功能独立，可以换成自己的角色。

**这是个人实验项目，并非任何厂商的官方应用。** 功能及兼容性有限，按个人需求维护，不保证持续维护或支持所有模型服务。基础桌宠可离线使用；说话与额度是分别配置的可选功能。调用模型会消耗你对应账户的额度或 API 余额。

## 已实现

- 点击压扁、松开回弹、短音效；拖动移动并保存位置。
- 小幅等待动作、三点思考泡、正文气泡；连点只保留一个在途请求，不排队。
- 可编辑本地台词：每行一句，随机选择、尽量避免连续重复，不联网、不记录模型用量。
- DSH、Codex 或兼容 OpenAI 的 Chat Completions API 生成短句。
- 额度通过 CodexBar 查询：选择、排序、隐藏来源，修改显示名。
- 独立奶油紫设置窗口：性格、字数、气泡时长、音量、大小、形象、点击气泡开关、登录时启动。
- 设置里的“用量记录”显示最近 10/50/200 次生成：模型、时间、耗时、输入/缓存/输出 token 和结果；未知不当零。
- API Key 存 macOS 钥匙串；配置导入/导出不携带 Key、接口地址或本机路径。
- 额度自动刷新，右键打开卡片也会更新；卡片底部只有设置和退出；退出是门形图标，悬停可查看说明。菜单栏也可显示/隐藏、打开设置和退出。

## 系统与依赖

| 用途 | 需要什么 |
| --- | --- |
| 按压、拖动、音效 | macOS 13 或更新；不需要账号、网络或其他客户端 |
| 本地台词 | 无外部依赖，设置内可编辑 |
| DSH 说话 | 安装 DeepSeek Harness，登录账户或在 Harness 配置 API；其 headless CLI 支持本项目的临时配置 |
| Codex 说话 | 可用、已登录的 Codex CLI；桌面应用内的 CLI 或手动选择路径均可 |
| 直接 API 说话 | 支持 `/chat/completions` 的文本服务、模型名，以及服务要求的 Key |
| 额度 | 安装并配置 [CodexBar](https://github.com/steipete/CodexBar)，登录要查询的来源 |
| 从源码构建 | macOS、Xcode Command Line Tools（Swift 编译器）；离线测试另需 Python 3 |

基础应用不捆绑模型、客户端、账户凭据或 CodexBar。Antigravity 可作为 CodexBar 的额度来源；**没有实现 Antigravity 客户端的模型生成后端**。当前不支持任意 API 协议、自动登录、账户充值或多账户管理。

## 构建与安装

```sh
./build.sh
./scripts/test.sh
python3 scripts/test-api.py
python3 scripts/test-smoke.py
python3 scripts/test-smoke-negative.py
```

以上测试按顺序执行；启动检查依赖 build.sh 产物，反向检查会额外编译两次。

首次构建前需要已安装 Xcode Command Line Tools；如系统提示缺少编译器，可运行 `xcode-select --install`，按系统提示完成安装。

输出 `dist/小龙娘桌宠.app`。默认构建 arm64/x86_64 双架构，目标 macOS 13；开发时可用 `DRAGONPET_ARCH=native ./build.sh` 只构建当前架构。

退出旧版后，将 `.app` 放入“应用程序”目录再打开；可以通过启动台、访达或菜单栏找回。不需要把程序一直放在桌面。移动正在运行的应用后应退出重开，以免旧资源路径失效。

构建产物仅本地 ad-hoc 签名，**尚未进行 Developer ID 签名或 Apple 公证**。从网络下载的应用可能被 Gatekeeper 拦截，不承诺下载后一键运行；推荐从源码构建。不要为了运行它关闭系统安全保护。

## 首次配置

首次安装默认关闭“点击时生成气泡”、没有额度选择，桌宠仍可互动。右键卡片的齿轮，或菜单栏爪印 → 设置：

1. **说话**：默认关闭气泡；开启后选择“本地台词”或“模型生成”。本地台词每行一句，可自行编辑；模型生成再选 DSH、Codex 或 API。此页开关、台词、连接参数均需保存后生效。关闭开关时仅保留按压音效，不发模型请求、不记录生成用量。程序位置留空自动寻找，找不到可手动选 CLI。填写服务支持的模型及思考强度。
2. **额度**：读取 CodexBar 来源列表，勾选所需项，改名/调整顺序后保存。也可手动添加 CodexBar 支持的来源 ID。选择不会修改 CodexBar 的设置。Antigravity 可选择仅显示 Gemini。
3. **测试**：本地模式保存并预览，不消耗 token；模型模式保存并测试会真实调用模型，即使日常气泡开关关闭；结果显示在设置中。失败时先在对应客户端验证登录和模型可用性。

DSH 每次创建独立请求，工具、项目指令及环境上下文通过临时配置关闭。Codex 每次 `exec --ephemeral --ignore-user-config`、只读并关闭相关工具；仍带客户端自身的模型上下文，消耗可能更高。客户端升级可能导致不兼容。

API 地址可填完整 `/chat/completions` 地址，或包含版本路径的基础地址（例如 `https://api.example.com/v1`）。只支持文本 Chat Completions、Bearer Key 和非流式回复；可选择发送 `max_tokens: 512`、`max_completion_tokens: 512` 或不发送长度参数，思考参数可选择不发送。服务若采用其他参数、认证或协议，当前可能不兼容。仅本机服务可使用 HTTP；不跟随重定向。Key 按完整接口地址分别保存在钥匙串，更换地址后需要重新配置。

## 更换形象

默认源文件在 `Resources/Skins/white-dragon/`。首次启动复制到 `~/Library/Application Support/DragonPet/Skins/white-dragon/`：

- `portrait.png`：透明立绘。
- `press.wav`、`release.wav`：可选短音效。
- `skin.json`：名称、文件名、默认高度与压缩比例。

设置 → 形象与声音 → 打开当前文件夹。替换后重新加载，无需编译；也可以切换到另一个包含 `skin.json` 的文件夹。文件名须为目录的直接子文件，缺音效可静音运行。不要编辑应用包本体。

## 隐私与数据

- 说话只发送配置的性格和短请求；本应用不读取屏幕、聊天记录或工作目录。
- 账户认证由对应客户端处理；DSH headless 可能在自身目录保存会话，Codex 临时模式不保存此类会话。客户端自身的日志/遥测由其设置决定。
- API Key 在 macOS 钥匙串，本地普通设置不含 Key。删除 Key 针对最近保存的 API 地址，未保存的地址草稿不会改变删除目标；更换过地址的旧 Key 可以在“钥匙串访问”中查找服务 `org.dragonpet.desktop.api` 管理。
- DSH 的临时补丁包含性格明文，仅当前用户可读，正常结束/取消后删除；强制终止应用可能残留在 CompanionWorkspace。仅 DSH 路线写此补丁。客户端自身仍可能保存日志或会话。新补丁放在0700的进程专属子目录；启动时仅清理已确认所属进程退出的目录，不删除活跃请求。旧版平铺补丁可能需要手动清理。
- Codex提示通过stdin发送，不放入进程参数；模型ID仍是命令行参数，应避免把敏感信息填作模型名。
- 普通设置、额度选择及位置保存于本机。额度只在内存中显示，不把账户原始 JSON 写入日志。错误提示不展示服务原始响应、Key 或请求头。
- 导出保留性格、本地台词、模型名称与来源显示名，它们可能包含你自行填写的私人信息；分享前仍应检查。导出会关闭说话并去掉接口地址/客户端路径。导入后需重新配置连接。

## 用量历史

每个 macOS 用户独立保存在 `~/Library/Application Support/DragonPet/token-history.json`，最多 200 条；设置 → 用量记录默认显示最近十次点击，取消“只看点击”也能看到连接测试。一次合并的连点只产生一条请求记录；保存设置取消在途请求也标为取消。失败/取消请求可能已被服务计费，缺少回传数据时记为未知；中途取消且只收到部分用量会标注“部分”，不计入完整合计，不能认为零消耗。

本地台词不新增模型记录。输入列统一为包含缓存的输入总数：DSH 的 `inputTokens` 与 `cacheReadTokens` 相加；Codex 的输入本身包含缓存；API 使用 `prompt_tokens`。缓存单独显示，但不重复加进合计。思考输出通常已包含在输出列中，不能再加一遍。没有返回用量的兼容服务显示未知。这里不是账单，不换算订阅剩余百分比或货币金额。

历史从启用此版本开始记录，以前的点击无法恢复。只存模型名称、结果状态、时间与用量，不存正文、性格、Key 或接口地址；不会随设置导出，公开源码包也不包含运行数据。可在设置中清空。

## 卸载

退出桌宠，先关闭设置中的登录启动；如使用 API，可在删除程序前删除对应 Key。随后将应用移到废纸篓。需要完整清理时，可删除 `~/Library/Application Support/DragonPet/`，并清理偏好域 `org.dragonpet.desktop`。它不会卸载 CodexBar、DSH 或 Codex，也不会删除它们的登录账户。

## 测试与发布范围

[验证记录及第二台 Mac 检查表](docs/VALIDATION.md)。本机通过不代表所有电脑都能运行。GitHub 托管 macOS Runner 已通过一次完整构建和自动检查，记录见验证文档；Intel/旧版 macOS 的构建通过也不等于真机运行通过。

公开源码请使用 `python3 scripts/package-source.py` 生成的 `dist/public-source/`；请从该目录建立干净的新仓库，不复制开发目录的 `.git`。它按白名单收集代码、必要资源与文档，排除个人记忆、账号截图、模型试验记录、制作档案和原始参考素材。发布前仍要检查这个目录及 Git 历史。打包器扫描常见敏感模式和资源元数据，但不构成完整安全或法律审计。

## 许可与致谢

代码采用 [MIT License](LICENSE)。默认皮肤来源及外部依赖说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。额度查询由 [CodexBar](https://github.com/steipete/CodexBar) 提供；桌宠构想、按压压扁/回弹、气泡及额度挂件交互受到 [DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) 启发。半身Q版与呆萌表情的方向也参考了用户提供的 DS 桌宠等示例。感谢原作者公开分享。

本项目为独立 Swift 实现，未包含上游插件源码、立绘文件、音效或固定台词库；默认龙娘文件由 AI 图像工具生成，音效自行合成。独立实现、AI生成和致谢不等于获得第三方素材或角色的授权；代码、交互理念与具体美术表达分别说明，详见来源文档。

实现参考：[Codex 非交互模式](https://learn.chatgpt.com/docs/non-interactive-mode)、[Chat Completions 接口](https://developers.openai.com/api/reference/resources/chat)。

## 兼容与维护边界

DSH 临时 patch 和客户端 CLI、CodexBar JSON 字段可能随版本改变；额度卡是实验性适配。接口不兼容时不要将未知值当零。设置 → 启动与配置 → 生成脱敏诊断只检查可执行文件能否找到，不验证登录或联网，不输出个人路径、Key、台词或额度。

当前版本 0.6.3 推荐发布源码，不提供已公证的通用安装包。默认标识为 `org.dragonpet.desktop`。维护已有安装时，可通过 `DRAGONPET_BUNDLE_ID` 构建变量保留原偏好域与钥匙串服务；改变标识不会自动迁移旧设置。

气泡及连接配置采用保存后生效；形象页的大小、静音、换肤操作以及登录启动即时生效，并在界面标明。皮肤高度范围60–260，横向压缩比例0.8–1.3，纵向0.5–1。固定奶油紫外观为当前设计，未实现自动深色主题。

测试隔离通过显式 `DRAGONPET_TEST_ROOT` 注入偏好文件及运行目录，不依赖 `CFFIXED_USER_HOME` 隔离cfprefsd。`test.sh`会自动创建并清理测试目录；正常启动仍使用原生偏好。GUI smoke要求首次fresh、二次loaded，并通过 `python3 scripts/test-smoke-negative.py` 验证默认气泡开启/预选额度两种错误必须失败；该脚本需额外编译两次，但不调用模型或额度服务。

调试参数 `--usage-diagnostics` 会输出模型回传用量及气泡正文；与 `--usage-log-path <文件>` 配合时写入0600文件。普通启动不记录正文；自行重定向stdout时，文件权限和分享范围由你负责。公开前不要上传这些日志。

可选 `--motion-diagnostics` 只在本机保存 `motion-diagnostic.jsonl`（0600），记录相对位移、动画状态和触发标签；不包含绝对坐标、截图、正文或账户数据。普通启动不启用，退出重开且不传此参数即可停止。该文件属于调查数据，不应上传。

## 项目状态与反馈

这是0.6.3源码发布。欢迎提交具体复现步骤、系统与客户端版本，或讨论皮肤和交互改进；请勿在Issue里上传Key、账户截图、真实额度、个人路径或诊断日志原文。测试记录与未验证边界见docs/VALIDATION.md；当前不承诺跨系统即装即用。
