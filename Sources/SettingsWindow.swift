import AppKit
import SwiftUI
import ServiceManagement

final class SettingsState:ObservableObject {
    @Published var draft=ConfigurationStore.shared.value
    @Published var key=""
    @Published var message=""
    @Published var checking=false
    @Published var loginEnabled=SMAppService.mainApp.status == .enabled
    @Published var petSize=Double(PetPreferences.shared.integer(forKey:"petSize"))
    @Published var muted=PetPreferences.shared.bool(forKey:"muted")
    @Published var newProviderID=""
    @Published var newProviderName=""
}
private struct PetSettingsView:View {
    @ObservedObject var state:SettingsState
    let owner:SettingsWindow
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("小龙娘的设置").font(.title2.weight(.semibold))
            Text("按自己的习惯，选她说话的方式和想看的额度。").font(.caption).foregroundStyle(.secondary)
            TabView {
                speech.tabItem{Label("说话",systemImage:"bubble.left")}
                quota.tabItem{Label("额度",systemImage:"chart.bar")}
                character.tabItem{Label("形象与声音",systemImage:"pawprint")}
                TokenHistoryView().tabItem{Label("用量记录",systemImage:"clock.arrow.circlepath")}
                general.tabItem{Label("启动与配置",systemImage:"slider.horizontal.3")}
            }
            if !state.message.isEmpty {Text(state.message).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:10))}
            HStack {
                Button("恢复默认…"){owner.restoreDefaults()}
                Spacer()
                Button("保存设置"){owner.save()}.buttonStyle(.borderedProminent).tint(Color(red:0.62,green:0.50,blue:0.75))
            }
        }.padding(22).frame(width:650,height:620)
        .background(Color(red:0.98,green:0.95,blue:0.98)).environment(\.colorScheme,.light)
    }
    var speech:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                Toggle("点击时生成气泡",isOn:Binding(get:{!state.draft.paused},set:{owner.setBubbleEnabled($0)}))
                Text("默认关闭；本页修改均需保存后生效。").font(.caption).foregroundStyle(.secondary)
                Picker("气泡内容",selection:$state.draft.bubbleSource){Text("本地台词").tag(BubbleSource.local);Text("模型生成").tag(BubbleSource.model)}
                if state.draft.bubbleSource == .local {
                    Text("每行一句，可以自行增删。随机选择，尽量避免连续重复；不联网、不消耗 token。").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text:$state.draft.localLines).frame(height:170).border(.gray.opacity(0.2))
                } else {
                Picker("模型来源",selection:$state.draft.backend){ForEach(SpeechBackend.allCases,id:\.self){Text($0.title).tag($0)}}
                Text("默认关闭。开关与台词编辑需保存后生效；本地台词零消耗，模型生成需要配置。").font(.caption).foregroundStyle(.secondary)
                if state.draft.backend == .dsh {
                    path("Harness 程序位置",binding:$state.draft.dshPath,kind:"dsh")
                    Picker("账户方式",selection:$state.draft.dshProvider){Text("Harness 登录账户").tag("deepseek-account");Text("Harness 已配置的 API").tag("deepseek-official")}
                    TextField("模型 ID",text:$state.draft.dshModel)
                    Picker("思考强度",selection:$state.draft.dshEffort){ForEach(["off","low","high","max"],id:\.self){Text($0).tag($0)}}
                }else if state.draft.backend == .codex {
                    path("Codex 程序位置",binding:$state.draft.codexPath,kind:"codex")
                    TextField("模型 ID（空白使用客户端默认）",text:$state.draft.codexModel)
                    Picker("思考强度",selection:$state.draft.codexEffort){ForEach(["low","medium","high","xhigh","max","ultra"],id:\.self){Text($0).tag($0)}}
                    Text("需要已登录的 Codex；模型和思考强度是否可用由账户及客户端决定。Codex 的上下文开销通常大于直接 API。").font(.caption).foregroundStyle(.secondary)
                }else if state.draft.backend == .api {
                    TextField("API 地址，例如 https://api.example.com/v1",text:$state.draft.apiURL)
                    TextField("模型 ID",text:$state.draft.apiModel)
                    SecureField("新 API Key（留空保留已有 Key）",text:$state.key)
                    HStack {Text("Key 按接口地址分别保存在钥匙串。").font(.caption).foregroundStyle(.secondary);Spacer();Button("删除已存 Key…"){owner.deleteKey()}}
                    Picker("输出长度参数",selection:$state.draft.apiTokenParameter){Text("max_tokens").tag("max_tokens");Text("max_completion_tokens").tag("max_completion_tokens");Text("不发送").tag("")}
                    Picker("思考强度（服务支持时填写）",selection:$state.draft.apiEffort){Text("不发送此参数").tag("");ForEach(["none","low","medium","high"],id:\.self){Text($0).tag($0)}}
                    Text("支持 Chat Completions 文本接口。无 Key 的本地服务也可使用；仅本机允许 HTTP，不支持重定向或自定义认证协议。").font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Text("性格与说话方式").font(.headline)
                TextEditor(text:$state.draft.persona).font(.system(size:12)).frame(height:105).border(.gray.opacity(0.2))
                }
                HStack {Stepper("最多 \(state.draft.maxCharacters) 字",value:$state.draft.maxCharacters,in:8...100);Spacer();Stepper("气泡 \(Int(state.draft.bubbleSeconds)) 秒",value:$state.draft.bubbleSeconds,in:3...30)}
                HStack {Button(state.checking ? "正在测试…":"保存并测试一句"){owner.testConnection()}.disabled(state.checking || (state.draft.bubbleSource == .model && state.draft.backend == .disabled));Text(state.draft.bubbleSource == .local ? "本地预览，不消耗 token。":"会实际调用所选模型，产生对应消耗。").font(.caption).foregroundStyle(.secondary)}
            }.padding(15).textFieldStyle(.roundedBorder)
        }
    }
    func path(_ title:String,binding:Binding<String>,kind:String)->some View {
        HStack {TextField(title+"（空白自动寻找）",text:binding);Button("选择…"){if let url=owner.pickExecutable(){binding.wrappedValue=url.path}}}
    }
    var quota:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Button("读取 CodexBar 来源列表"){owner.discover()};Button("选择 CodexBar CLI…"){owner.onChooseCLI?()}}
            Text("勾选想显示的来源；可改显示名、调整顺序。登录和额度查询由 CodexBar 负责。").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing:8) {
                    ForEach(Array(state.draft.quotaSources.enumerated()),id:\.element.id){index,source in
                        HStack {
                            Toggle("",isOn:Binding(get:{state.draft.quotaSources[index].enabled},set:{state.draft.quotaSources[index].enabled=$0})).labelsHidden().accessibilityLabel("显示 "+source.id)
                            TextField("显示名称",text:Binding(get:{state.draft.quotaSources[index].name},set:{state.draft.quotaSources[index].name=$0}))
                            Text(source.id).font(.caption).foregroundStyle(.secondary).frame(width:95,alignment:.leading)
                            Button{owner.moveSource(index,-1)}label:{Image(systemName:"arrow.up")}.disabled(index==0).help("上移")
                            Button{owner.moveSource(index,1)}label:{Image(systemName:"arrow.down")}.disabled(index==state.draft.quotaSources.count-1).help("下移")
                            Button{state.draft.quotaSources.remove(at:index)}label:{Image(systemName:"minus.circle")}.help("移除来源")
                        }.padding(7).background(.white.opacity(0.65),in:RoundedRectangle(cornerRadius:8))
                    }
                }
            }
            HStack {TextField("来源 ID",text:$state.newProviderID);TextField("显示名称",text:$state.newProviderName);Button("添加"){owner.addSource()}}
            Toggle("Antigravity 只显示 Gemini",isOn:$state.draft.geminiOnly)
            Stepper("自动刷新：\(Int(state.draft.refreshSeconds/60)) 分钟",value:$state.draft.refreshSeconds,in:60...1800,step:60)
        }.padding(15).textFieldStyle(.roundedBorder)
    }
    var character:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack{Text("大小");Slider(value:$state.petSize,in:80...180,step:1).onChange(of:state.petSize){owner.onSize?(Int($0))};Text("\(Int(state.petSize))")}
            Toggle("静音",isOn:$state.muted).onChange(of:state.muted){owner.onMute?($0)}
            HStack{Text("音量");Slider(value:$state.draft.volume,in:0...1);Text("\(Int(state.draft.volume*100))%")}
            Divider()
            HStack {Button("切换形象文件夹…"){owner.onSkin?()};Button("重新加载"){owner.onReload?()};Button("打开当前文件夹"){owner.onOpenSkin?()}}
            Text("立绘、音效与功能代码独立。形象文件夹包含 skin.json、透明图片和可选音效。此页大小、静音及形象操作即时生效；音量需保存。").font(.caption).foregroundStyle(.secondary)
            Button("回到右下角"){owner.onReset?()}
            Spacer()
        }.padding(15)
    }
    var general:some View {
        VStack(alignment:.leading,spacing:18) {
            Toggle("登录 Mac 时启动（即时生效）",isOn:Binding(get:{state.loginEnabled},set:{owner.setLogin($0)}))
            Text("建议将程序放在“应用程序”目录；系统可能要求在登录项中确认。").font(.caption).foregroundStyle(.secondary)
            HStack {Button("暂时隐藏桌宠"){owner.onHide?()};Button("导出配置…"){owner.exportConfig()};Button("导入配置…"){owner.importConfig()}}
            Text("导出不包含 Key、API 地址、客户端路径和账户凭据；导入后需要重新选择说话来源。").font(.caption).foregroundStyle(.secondary)
            Button("生成脱敏诊断"){state.message=Diagnostics.summary(ConfigurationStore.shared.value)}
            Divider()
            Text("个人实验项目").font(.headline)
            Text("基础交互不需要任何账户。说话和额度是可选功能，分别配置；没有依赖时仍可使用桌宠。不会读取屏幕或工作目录。客户端行为由相应客户端版本决定。").font(.callout)
            if !ConfigurationStore.shared.diagnostic.isEmpty {Text(ConfigurationStore.shared.diagnostic).font(.caption).textSelection(.enabled)}
            Spacer()
        }.padding(15)
    }
}
final class SettingsWindow:NSObject {
    let state=SettingsState()
    private var window:NSWindow?
    private var testService:CompanionService?
    var onApply:(()->Void)?
    var onSize:((Int)->Void)?
    var onMute:((Bool)->Void)?
    var onSkin:(()->Void)?
    var onReload:(()->Void)?
    var onOpenSkin:(()->Void)?
    var onReset:(()->Void)?
    var onHide:(()->Void)?
    var onChooseCLI:(()->Void)?
    func show(){
        state.draft=ConfigurationStore.shared.value;state.key="";state.message=""
        state.petSize=Double(PetPreferences.shared.integer(forKey:"petSize"));state.muted=PetPreferences.shared.bool(forKey:"muted");state.loginEnabled=SMAppService.mainApp.status == .enabled
        if window==nil {
            let w=NSWindow(contentRect:NSRect(x:0,y:0,width:650,height:620),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false);w.title="小龙娘设置";w.isReleasedWhenClosed=false
            w.contentView=NSHostingView(rootView:PetSettingsView(state:state,owner:self));w.center();window=w
        }
        NSApp.activate(ignoringOtherApps:true);window?.makeKeyAndOrderFront(nil)
    }
    func setBubbleEnabled(_ enabled:Bool){state.draft.paused = !enabled;state.message="尚未保存。点击保存设置后生效。"}
    @discardableResult func save()->Bool {
        do {
            let candidate=try state.draft.validated()
            shutdown()
            var deferredKey=false
            if !state.key.isEmpty {
                if (try? APIClient.endpoint(candidate.apiURL)) != nil {try APIKeyStore.set(state.key,endpoint:candidate.apiURL);state.key=""}
                else {deferredKey=true}
            }
            try ConfigurationStore.shared.save(candidate)
            state.message=deferredKey ? "设置已保存；API 地址未填好，Key 尚未保存，请勿关闭窗口。":"已保存。"
            onApply?();return true
        }catch{state.message=error.localizedDescription;return false}
    }
    func pickExecutable()->URL? {let panel=NSOpenPanel();panel.message="选择可执行的 CLI 文件";guard panel.runModal() == .OK,let url=panel.url,FileManager.default.isExecutableFile(atPath:url.path) else{return nil};return url}
    func discover(){UsageService.discover{[weak self] sources,error in
        guard let self else{return};if let error{self.state.message=error;return}
        for source in sources where !self.state.draft.quotaSources.contains(where:{$0.id==source.id}) {self.state.draft.quotaSources.append(source)}
        self.state.message="已读取来源列表。修改后点保存。"
    }}
    func addSource(){let id=state.newProviderID.trimmingCharacters(in:.whitespacesAndNewlines);guard id.range(of:"^[a-z0-9-]+$",options:.regularExpression) != nil,!state.draft.quotaSources.contains(where:{$0.id==id}) else{state.message="ID 无效或已存在。";return};state.draft.quotaSources.append(QuotaSource(id:id,name:state.newProviderName.isEmpty ? id:state.newProviderName,enabled:true));state.newProviderID="";state.newProviderName=""}
    func moveSource(_ index:Int,_ delta:Int){let target=index+delta;guard state.draft.quotaSources.indices.contains(target) else{return};state.draft.quotaSources.swapAt(index,target)}
    func testConnection(){
        do {
            guard state.draft.bubbleSource == .local || state.draft.backend != .disabled else{throw ConfigError.message("请先选择说话来源。")}
            _ = try state.draft.validated(forGeneration:true)
        }catch{state.message=error.localizedDescription;return}
        guard save() else{return};testService?.shutdown();state.checking=true
        let config=state.draft
        let service=CompanionService(persona:config.persona);service.origin="连接测试";service.onRecord={TokenHistoryStore.shared.append($0)};service.configuration={var copy=config;copy.paused=false;return copy}
        service.onResult={ [weak self] text,error in guard let self else{return};self.state.checking=false;self.state.message=error ?? "连接成功："+(text ?? "");self.testService=nil }
        testService=service;if !service.speak(){state.checking=false;testService=nil;state.message="没有可用内容，请检查设置。"}
    }
    func setLogin(_ enabled:Bool){do{if enabled{try SMAppService.mainApp.register()}else{try SMAppService.mainApp.unregister()};state.loginEnabled=SMAppService.mainApp.status == .enabled;state.message=SMAppService.mainApp.status == .requiresApproval ? "请在系统设置的登录项里允许启动。":"登录启动设置已更新。"}catch{state.message="无法更新登录项："+error.localizedDescription;state.loginEnabled=SMAppService.mainApp.status == .enabled}}
    func restoreDefaults(){let alert=NSAlert();alert.messageText="恢复默认设置？";alert.informativeText="关闭模型说话并清空额度选择；保留形象和钥匙串 Key。";alert.addButton(withTitle:"恢复");alert.addButton(withTitle:"取消");if alert.runModal() == .alertFirstButtonReturn{state.draft=PetConfiguration.defaults();_ = save()}}
    func deleteKey(){let endpoint=ConfigurationStore.shared.value.apiURL;let alert=NSAlert();alert.messageText="删除已保存接口的 API Key？";alert.informativeText="针对最近保存的接口，不使用未保存的地址草稿。";alert.addButton(withTitle:"删除");alert.addButton(withTitle:"取消");if alert.runModal() == .alertFirstButtonReturn{do{try APIKeyStore.set("",endpoint:endpoint);state.message="已删除 Key。"}catch{state.message=error.localizedDescription}}}
    func exportConfig(){let panel=NSSavePanel();panel.nameFieldStringValue="dragonpet-config.json";if panel.runModal() == .OK,let url=panel.url {do{let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(state.draft.exported()).write(to:url,options:.atomic);state.message="已导出，不含密钥和本机连接信息。"}catch{state.message="导出失败。"}}}
    func importConfig(){let panel=NSOpenPanel();if panel.runModal() == .OK,let url=panel.url {do{let data=try Data(contentsOf:url);guard data.count<100_000 else{throw ConfigError.message("配置文件过大。")};var value=try JSONDecoder().decode(PetConfiguration.self,from:data);value=value.exported();state.draft=try value.validated();state.message="已载入，连接信息已清空。检查后点保存。"}catch{state.message="配置格式无效，请使用桌宠导出的文件。"}}}
    func shutdown(){testService?.onResult=nil;testService?.shutdown();testService=nil;state.checking=false}
}
