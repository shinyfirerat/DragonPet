# 来源与许可

本项目 Swift 功能代码按根目录 MIT License 发布。生成工具参与了代码与插画制作；不将生成结果的独占性作为保证。

## CodexBar

- https://github.com/steipete/CodexBar
- MIT；Copyright (c) 2026 Peter Steinberger。
- 本项目通过用户已安装的 CLI 查询额度，参考其公开 JSON 格式；不捆绑 CodexBar 的程序或账户数据。CodexBar 须另行安装，其自身许可证与服务规则继续适用。

## DeepSeek-Balance-Whale-Widget

- https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget
- MIT；Copyright (c) 2026 MeteorNOX。
- 桌宠构想、点击压扁/回弹、按压/松开音效反馈、气泡及额度挂件交互参考了该项目；此处为独立 Swift 实现。未包含它的立绘、音频、插件代码或固定文字库。

上述两项目的 MIT 许可条件为：复制或分发其代码及实质性部分时保留原版权声明和完整许可文本。仅列致谢不替代许可要求；今后引入其代码时必须随复制部分补齐原 LICENSE。

## 客户端和服务

DeepSeek Harness、Codex 及模型 API 是用户选择的外部依赖，本项目不捆绑其运行时或提供账户。登录、额度、服务条款及兼容性由相应提供方决定。本项目与上述项目及厂商没有官方隶属关系。

## 图片与声音

默认白毛龙娘立绘由本项目使用 AI 图像工具生成；半身Q版比例、呆萌表情方向参考了用户提供的 DS 桌宠等示例；没有分发参考截图或上游立绘。默认 press.wav/release.wav 为本项目合成音效。默认皮肤资源随本项目按 MIT 许可提供，以项目有权许可的范围为限，不保证生成素材的独占权。替换皮肤的用户应确认自己选用的图片、音效、字体许可。

默认 portrait.png 保留 AI 图像工具写入的 C2PA 内容凭证（ChatGPT / OpenAI 图像生成来源）；其中包含生成工具、时间和签名标识。打包器显式允许该资源的 caBX chunk，未移除来源凭证。生成凭证不是版权担保，重编码资源可能影响凭证有效性。应用图标使用系统 SF Symbol 与程序绘制底色，生成脚本随源码提供。

借鉴交互理念与复制具体作品应分开判断：我们披露设计启发，不据此声称原作形象授权或完全不存在视觉相似性。致谢不能代替需要的许可；上游代码的 MIT 许可也不能自动解决潜在第三方角色/素材权利。项目名称保持“小龙娘桌宠 / DragonPet”，不以 GPT 等第三方品牌作为应用名称。
