import AppKit
import Security
import CryptoKit

struct QuotaSource:Codable,Identifiable,Equatable {
    var id:String
    var name:String
    var enabled:Bool
}
enum SpeechBackend:String,Codable,CaseIterable {
    case disabled,dsh,codex,api
    var title:String {switch self{case .disabled:return "暂不开启";case .dsh:return "DeepSeek Harness";case .codex:return "Codex";case .api:return "兼容 OpenAI 的 API"}}
}
enum BubbleSource:String,Codable,CaseIterable {case local,model}
struct PetConfiguration:Codable {
    var bubbleSource:BubbleSource = .local
    var localLines="今天也可以慢一点。\n我刚刚想到了什么，又忘了。\n发呆也是一种休息。\n先伸个懒腰吧。\n你忙你的，我在这里。"
    var apiTokenParameter="max_tokens"
    var version=1
    var backend:SpeechBackend = .disabled
    var paused=true
    var dshPath=""
    var dshProvider="deepseek-account"
    var dshModel="deepseek-flash"
    var dshEffort="off"
    var codexPath=""
    var codexModel=""
    var codexEffort="low"
    var apiURL=""
    var apiModel=""
    var apiEffort=""
    var persona=""
    var maxCharacters=40
    var bubbleSeconds=8.0
    var volume=0.35
    var quotaSources=[QuotaSource]()
    var geminiOnly=false
    var refreshSeconds=180.0
    enum CodingKeys:String,CodingKey {case version,backend,paused,dshPath,dshProvider,dshModel,dshEffort,codexPath,codexModel,codexEffort,apiURL,apiModel,apiEffort,persona,maxCharacters,bubbleSeconds,volume,quotaSources,geminiOnly,refreshSeconds,bubbleSource,localLines,apiTokenParameter}
    init() {}
    init(from decoder:Decoder)throws {
        self.init()
        let c=try decoder.container(keyedBy:CodingKeys.self)
        version=try c.decodeIfPresent(Int.self,forKey:.version) ?? version
        backend=try c.decodeIfPresent(SpeechBackend.self,forKey:.backend) ?? backend
        paused=try c.decodeIfPresent(Bool.self,forKey:.paused) ?? paused
        dshPath=try c.decodeIfPresent(String.self,forKey:.dshPath) ?? dshPath
        dshProvider=try c.decodeIfPresent(String.self,forKey:.dshProvider) ?? dshProvider
        dshModel=try c.decodeIfPresent(String.self,forKey:.dshModel) ?? dshModel
        dshEffort=try c.decodeIfPresent(String.self,forKey:.dshEffort) ?? dshEffort
        codexPath=try c.decodeIfPresent(String.self,forKey:.codexPath) ?? codexPath
        codexModel=try c.decodeIfPresent(String.self,forKey:.codexModel) ?? codexModel
        codexEffort=try c.decodeIfPresent(String.self,forKey:.codexEffort) ?? codexEffort
        apiURL=try c.decodeIfPresent(String.self,forKey:.apiURL) ?? apiURL
        apiModel=try c.decodeIfPresent(String.self,forKey:.apiModel) ?? apiModel
        apiEffort=try c.decodeIfPresent(String.self,forKey:.apiEffort) ?? apiEffort
        persona=try c.decodeIfPresent(String.self,forKey:.persona) ?? persona
        maxCharacters=try c.decodeIfPresent(Int.self,forKey:.maxCharacters) ?? maxCharacters
        bubbleSeconds=try c.decodeIfPresent(Double.self,forKey:.bubbleSeconds) ?? bubbleSeconds
        volume=try c.decodeIfPresent(Double.self,forKey:.volume) ?? volume
        quotaSources=try c.decodeIfPresent([QuotaSource].self,forKey:.quotaSources) ?? quotaSources
        geminiOnly=try c.decodeIfPresent(Bool.self,forKey:.geminiOnly) ?? geminiOnly
        refreshSeconds=try c.decodeIfPresent(Double.self,forKey:.refreshSeconds) ?? refreshSeconds
        bubbleSource=try c.decodeIfPresent(BubbleSource.self,forKey:.bubbleSource) ?? bubbleSource
        localLines=try c.decodeIfPresent(String.self,forKey:.localLines) ?? localLines
        apiTokenParameter=try c.decodeIfPresent(String.self,forKey:.apiTokenParameter) ?? apiTokenParameter
        guard version<=1 else{throw ConfigError.message("配置来自较新的版本，请先升级桌宠。")}
        if !c.contains(.bubbleSource),backend != .disabled {bubbleSource = .model}
        if persona.isEmpty {persona=Self.defaultPersona}
    }
    static var defaultPersona:String {
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Companion/personality.txt") else{return "你是自然随意的桌面小伙伴，只说一句简短中文，不使用工具。"}
        return (try? String(contentsOf:url,encoding:.utf8)) ?? "你是自然随意的桌面小伙伴，只说一句简短中文，不使用工具。"
    }
    static func defaults()->PetConfiguration {
        var value=PetConfiguration()
        value.persona=defaultPersona
        return value
    }
    func validated(forGeneration:Bool=false)throws->PetConfiguration {
        guard (8...100).contains(maxCharacters),(3...30).contains(bubbleSeconds),(0...1).contains(volume),(60...1800).contains(refreshSeconds),!persona.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,persona.count<=4000 else{throw ConfigError.message("请检查性格、长度、音量和刷新间隔。")}
        guard Set(quotaSources.map{$0.id}).count==quotaSources.count,quotaSources.allSatisfy({$0.id.range(of:"^[a-z0-9-]+$",options:.regularExpression) != nil && !$0.name.isEmpty}) else{throw ConfigError.message("额度来源 ID 必须唯一，只能包含小写字母、数字和连字符。")}
        if bubbleSource == .model && backend == .api && (!paused || forGeneration) {_ = try APIClient.endpoint(apiURL);guard !apiModel.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ConfigError.message("请填写 API 模型名称。")}}
        guard localLines.utf8.count<=50_000,["max_tokens","max_completion_tokens",""].contains(apiTokenParameter) else{throw ConfigError.message("请检查本地台词长度和 API 参数。")}
        if bubbleSource == .local && (!paused || forGeneration) && LocalLines.lines(localLines).isEmpty {throw ConfigError.message("请至少填写一句本地台词。")}
        if bubbleSource == .model && (!paused || forGeneration) && backend == .disabled {throw ConfigError.message("请先选择模型来源。")}
        return self
    }
    func exported() -> PetConfiguration {
        var copy=self
        copy.dshPath="";copy.codexPath=""
        // A base URL may include private hostnames. It is deliberately omitted from exports.
        copy.apiURL="";copy.backend = .disabled;copy.paused=true
        return copy
    }
}
enum ConfigError:LocalizedError {
    case message(String)
    var errorDescription:String? {if case .message(let text)=self{return text};return nil}
}
final class ConfigurationStore:ObservableObject {
    static let shared=ConfigurationStore()
    private(set) var configSource="fresh"
    @Published var value:PetConfiguration
    @Published var diagnostic=""
    private let defaults:PetPreferences
    init(defaults:PetPreferences = .shared) {
        self.defaults=defaults
        if let data=defaults.data(forKey:"petConfiguration") {
            configSource="loaded"
            do {value=try JSONDecoder().decode(PetConfiguration.self,from:data).validated()}
            catch {
                // Preserve the original blob so a later repair can recover it.
                value=PetConfiguration.defaults()
                diagnostic="设置读取失败，已临时关闭气泡和额度查询；原设置已保留。"
            }
        } else {
            // Appearance preferences are not evidence of consent to model/quota access.
            value=PetConfiguration.defaults()
            if let data=try? JSONEncoder().encode(value){defaults.set(data,forKey:"petConfiguration")}
        }
    }

    func save(_ candidate:PetConfiguration)throws {
        let checked=try candidate.validated()
        let data=try JSONEncoder().encode(checked)
        defaults.set(data,forKey:"petConfiguration");value=checked
    }
}
enum APIKeyStore {
    private static var service:String {(Bundle.main.bundleIdentifier ?? "org.dragonpet.desktop")+".api"}
    private static func account(_ endpoint:String)throws->String {
        let canonical=try APIClient.endpoint(endpoint).absoluteString
        return SHA256.hash(data:Data(canonical.utf8)).map{String(format:"%02x",$0)}.joined()
    }
    static func deletionEndpoint(_ saved:String)throws->String {
        guard !saved.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ConfigError.message("尚未保存 API 接口，没有可删除的 Key。")}
        guard (try? APIClient.endpoint(saved)) != nil else{throw ConfigError.message("已保存的接口地址无效，请先在设置中修正地址。")} 
        return saved
    }
    static func set(_ key:String,endpoint:String)throws {
        let account=try account(endpoint)
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        if key.isEmpty {let status=SecItemDelete(query as CFDictionary);guard status==errSecSuccess || status==errSecItemNotFound else{throw ConfigError.message("钥匙串删除失败（\(status)）。")};return}
        let data=Data(key.utf8)
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound {
            var insert=query;insert[kSecValueData as String]=data;insert[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added=SecItemAdd(insert as CFDictionary,nil);guard added==errSecSuccess else{throw ConfigError.message("钥匙串保存失败（\(added)）。")}
        }else if status != errSecSuccess {throw ConfigError.message("钥匙串保存失败（\(status)）。")}
    }
    static func get(endpoint:String)throws->String? {
        let account=try account(endpoint)
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?;let status=SecItemCopyMatching(query as CFDictionary,&result)
        if status==errSecItemNotFound{return nil}
        guard status==errSecSuccess,let data=result as? Data else{throw ConfigError.message("钥匙串暂时不可访问（\(status)）。")}
        return String(data:data,encoding:.utf8)
    }
}
enum ExecutableLocator {
    static func find(_ kind:String,override:String="")->URL? {
        if !override.isEmpty {let url=URL(fileURLWithPath:NSString(string:override).expandingTildeInPath);return FileManager.default.isExecutableFile(atPath:url.path) ? url:nil}
        var candidates=[URL]()
        let relative=kind=="dsh" ? "Contents/Resources/runtime/cli/bin/dsh":"Contents/Resources/codex"
        for app in NSWorkspace.shared.runningApplications {
            if let bundle=app.bundleURL,(kind=="dsh" && app.localizedName=="DeepSeek Harness") || (kind=="codex" && ["Codex","ChatGPT"].contains(app.localizedName ?? "")) {candidates.append(bundle.appendingPathComponent(relative));if kind=="codex"{candidates.append(bundle.appendingPathComponent("Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"))}}
        }
        let paths=kind=="dsh" ? ["/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh",NSHomeDirectory()+"/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh"]:["/Applications/Codex.app/Contents/Resources/codex","/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",NSHomeDirectory()+"/Applications/Codex.app/Contents/Resources/codex"]
        candidates += paths.map{URL(fileURLWithPath:$0)}
        let environmentPath=ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in (environmentPath+":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin").split(separator:":"){candidates.append(URL(fileURLWithPath:String(directory)).appendingPathComponent(kind))}
        return candidates.first{FileManager.default.isExecutableFile(atPath:$0.path)}
    }
}
