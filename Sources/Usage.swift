import AppKit
struct UsageRow {
    var providerID: String = ""
    var title: String
    var lines: [String]
    var timestamp: String?
}
enum UsageParser {
    static func parse(_ data: Data,geminiOnly:Bool = true) throws -> [UsageRow] {
        let value = try JSONSerialization.jsonObject(with:data)
        guard let entries = value as? [[String:Any]] else { throw NSError(domain:"Usage",code:1,userInfo:[NSLocalizedDescriptionKey:"CodexBar 返回格式不兼容"]) }
        return entries.map { entry in
            let id=entry["provider"] as? String ?? "未知来源"
            let name=["codex":"Codex","deepseek":"DeepSeek / Harness","antigravity":"Antigravity"][id] ?? id
            guard let usage=entry["usage"] as? [String:Any] else { return UsageRow(providerID:id,title:name,lines:["暂时无法获取，请在 CodexBar 检查该来源的登录状态。"],timestamp:nil) }
            let labels=entry["rateWindowLabels"] as? [String:String] ?? [:]
            var lines=[String]()
            func window(_ w:[String:Any],_ title:String) {
                if let used=w["usedPercent"] as? Double, used.isFinite { lines.append("\(title)：剩余 \(String(format:"%.1f",max(0,min(100,100-used))))%") }
                else { lines.append("\(title)：额度未知") }
                if let reset=w["resetsAt"] as? String { lines.append("  重置：\(date(reset))") }
            }
            if id=="deepseek" {
                if let p=usage["primary"] as? [String:Any],let text=p["resetDescription"] as? String { lines.append("余额：\(text)") }
                else { lines.append("余额暂时不可用") }
            } else if let extras=usage["extraRateWindows"] as? [[String:Any]],!extras.isEmpty {
                for e in extras {
                    let title=e["title"] as? String ?? "额度"
                    if geminiOnly && id=="antigravity" && !title.localizedCaseInsensitiveContains("gemini") {continue}
                    if let w=e["window"] as? [String:Any] {window(w,title)}
                }
            } else {
                for k in ["primary","secondary","tertiary"] {
                    guard let w=usage[k] as? [String:Any] else { continue }
                    let mins=w["windowMinutes"] as? Int
                    let title=mins==300 ? "5 小时" : mins==10080 ? "每周" : labels[k] ?? "额度"
                    window(w,title)
                }
            }
            if let credits=entry["credits"] as? [String:Any], credits["balanceReadSucceeded"] as? Bool==true,let remaining=credits["remaining"] as? Double { lines.append("额外点数：\(remaining)") }
            if lines.isEmpty { lines=["该来源暂未提供额度"] }
            return UsageRow(providerID:id,title:name,lines:lines,timestamp:usage["updatedAt"] as? String)
        }
    }
    static func date(_ text:String)->String {
        let iso=ISO8601DateFormatter()
        var parsed=iso.date(from:text)
        if parsed==nil {iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds];parsed=iso.date(from:text)}
        guard let d=parsed else{return text}
        let f=DateFormatter();f.dateFormat="MM-dd HH:mm";return f.string(from:d)
    }
}
final class UsageService {
    private(set) var rows=[UsageRow]()
    private(set) var busy=false
    private(set) var error:String?
    private let processLock=NSLock()
    private var processes=[Process]()
    private var pendingRefresh=false
    func cancel(){processLock.lock();let active=processes;processLock.unlock();for p in active where p.isRunning{p.terminate()}}
    var onChange:(()->Void)?
    static func cli()->URL? {
        let fm=FileManager.default
        var candidates=[URL]()
        if let p=PetPreferences.shared.string(forKey:"codexbarCLI") { candidates.append(URL(fileURLWithPath:p)) }
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName=="CodexBar",let bundle=app.bundleURL { candidates.append(bundle.appendingPathComponent("Contents/Helpers/CodexBarCLI")) }
        }
        for p in ["/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",NSHomeDirectory()+"/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI","/opt/homebrew/bin/codexbar","/usr/local/bin/codexbar"] { candidates.append(URL(fileURLWithPath:p)) }
        return candidates.first { fm.isExecutableFile(atPath:$0.path) }
    }
    var configuration:(()->PetConfiguration)?
    static func discover(_ completion:@escaping([QuotaSource],String?)->Void) {
        guard let exe=cli() else{completion([],"找不到 CodexBar，请选择 CLI 或安装 CodexBar。");return}
        DispatchQueue.global(qos:.utility).async {
            let p=Process();p.executableURL=exe;p.arguments=["config","providers","--format","json"]
            let pipe=Pipe();p.standardOutput=pipe;p.standardError=FileHandle.nullDevice
            do {
                try p.run()
                let timeout=DispatchWorkItem{if p.isRunning{p.terminate()}}
                DispatchQueue.global().asyncAfter(deadline:.now()+8,execute:timeout)
                let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();timeout.cancel()
                guard p.terminationStatus==0,let entries=(try JSONSerialization.jsonObject(with:data)) as? [[String:Any]] else{throw ConfigError.message("CodexBar 版本不支持来源列表，可手动添加来源 ID。")}
                let rows=entries.compactMap{entry -> QuotaSource? in
                    guard let id=entry["provider"] as? String,id != "openai-oauth",id.range(of:"^[a-z0-9-]+$",options:.regularExpression) != nil else{return nil}
                    return QuotaSource(id:id,name:entry["displayName"] as? String ?? id,enabled:entry["enabled"] as? Bool ?? false)
                }
                DispatchQueue.main.async{completion(rows,nil)}
            }catch{DispatchQueue.main.async{completion([],"无法读取来源列表，可检查 CodexBar 版本或手动添加 ID。")}}
        }
    }
    func refresh() {
        let config=configuration?() ?? ConfigurationStore.shared.value
        let selected=config.quotaSources.filter{$0.enabled}
        rows.removeAll{row in !selected.contains(where:{$0.id==row.providerID})}
        guard !busy else{pendingRefresh=true;onChange?();return}
        guard !selected.isEmpty else{rows=[];error="在设置里选择想显示的额度来源。";onChange?();return}
        guard let exe=Self.cli() else{error="找不到 CodexBar CLI。请启动 CodexBar，或在菜单中选择 CLI。";onChange?();return}
        busy=true;error=nil;onChange?()
        let group=DispatchGroup()
        for source in selected {
            let id=source.id
            group.enter()
            DispatchQueue.global(qos:.utility).async { [weak self] in
                var result:Result<[UsageRow],Error>
                do {
                    let p=Process();p.executableURL=exe;p.arguments=["usage","--provider",id,"--format","json"]
                    var env=ProcessInfo.processInfo.environment;env["PATH"]="/opt/homebrew/bin:/usr/local/bin:"+(env["PATH"] ?? "/usr/bin:/bin");p.environment=env
                    let output=Pipe();p.standardOutput=output;p.standardError=FileHandle.nullDevice
                    try p.run()
                    self?.processLock.lock();self?.processes.append(p);self?.processLock.unlock()
                    defer{self?.processLock.lock();self?.processes.removeAll{$0 === p};self?.processLock.unlock()}
                    let deadline=DispatchWorkItem{if p.isRunning{p.terminate();DispatchQueue.global().asyncAfter(deadline:.now()+2){if p.isRunning{kill(p.processIdentifier,SIGKILL)}}}}
                    DispatchQueue.global().asyncAfter(deadline:.now()+45,execute:deadline)
                    let data=output.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();deadline.cancel()
                    guard !data.isEmpty else{throw NSError(domain:"Usage",code:3,userInfo:[NSLocalizedDescriptionKey:"查询失败或超时"])}
                    result = .success(try UsageParser.parse(data,geminiOnly:config.geminiOnly))
                } catch {result = .failure(error)}
                DispatchQueue.main.async {
                    defer{group.leave()};guard let self else{return}
                    let current=(self.configuration?() ?? ConfigurationStore.shared.value).quotaSources
                    guard let selectedSource=current.first(where:{$0.id==id && $0.enabled}) else{return}
                    switch result {
                    case .success(let rows):
                        for var row in rows {row.title=selectedSource.name;if let index=self.rows.firstIndex(where:{$0.providerID==row.providerID}){self.rows[index]=row}else{self.rows.append(row)}}
                    case .failure:
                        let title=selectedSource.name
                        if let index=self.rows.firstIndex(where:{$0.providerID==id}){self.rows[index].lines=["⚠ 刷新失败，以下为旧数据"]+self.rows[index].lines.filter{!$0.hasPrefix("⚠")}}
                        else{self.rows.append(UsageRow(providerID:id,title:title,lines:["暂时无法获取，请检查 CodexBar 登录状态。"],timestamp:nil))}
                    }
                    self.rows.sort{ $0.title < $1.title };self.onChange?()
                }
            }
        }
        group.notify(queue:.main){[weak self] in guard let self else{return};self.busy=false;self.onChange?();if self.pendingRefresh{self.pendingRefresh=false;self.refresh()}}
    }
}
