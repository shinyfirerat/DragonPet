import AppKit
/// Does not execute clients or expose paths, keys, prompts, replies, or account data.
enum Diagnostics {
    static func summary(_ config:PetConfiguration)->String {
        let checks=[("DSH",ExecutableLocator.find("dsh",override:config.dshPath) != nil),("Codex",ExecutableLocator.find("codex",override:config.codexPath) != nil),("CodexBar",UsageService.cli() != nil)]
        let deps=checks.map{$0.0+": "+($0.1 ? "程序可找到（未验证登录）":"程序未找到")}.joined(separator:"\n")
        let version=Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "source"
        return "DragonPet "+version+"\n"+ProcessInfo.processInfo.operatingSystemVersionString+"\n"+deps+"\n气泡："+(config.paused ? "关闭":config.bubbleSource == .local ? "本地台词":"模型生成")+"\n此诊断未读取凭据、未调用模型，不含个人路径或额度。"
    }
}
