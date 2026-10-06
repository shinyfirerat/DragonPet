import AppKit
import Darwin

/// One DSH request at a time; art and personality remain independent resources.
final class CompanionService {
    private let local=LocalLines()
    private var patchFile:URL?
    private var usageFinal=false
    private var process:Process?
    private let api=APIClient()
    var configuration:(()->PetConfiguration)?
    var lastError:String?
    private var activeBackend:SpeechBackend = .dsh
    private var reader:FileHandle?
    private var buffer=Data()
    private var generation=UUID()
    private var timeout:Timer?
    private var lastSettledAt:TimeInterval = -1
    private var finalText:String?
    private var failed=false
    private var sessionID=UUID().uuidString
    private let patchOverride:URL?
    private let persona:String
    private let executableOverride:URL?
    private let responseTimeout:TimeInterval
    private(set) var busy=false
    var onRecord:((TokenRecord)->Void)?
    var origin="点击"
    private var usageSteps=Set<String>()
    private var receivedUsage=false
    private var recordID=UUID()
    private var recordStarted=Date()
    private var recordModel=""
    private var recordCounts=TokenCounts(input:nil,cached:nil,output:nil,reasoning:nil)
    var onResult:((String?,String?)->Void)?
    var onUsage:((String,[String:Any])->Void)?
    init(persona:String,executable:URL?=nil,responseTimeout:TimeInterval=35,patchURL:URL?=nil){self.patchOverride=patchURL;self.persona=persona;self.executableOverride=executable;self.responseTimeout=responseTimeout}
    static func executable()->URL? {
        return ExecutableLocator.find("dsh")
    }
    private var workspaceBase:URL {AppPaths.support.appendingPathComponent("CompanionWorkspace")}
    private var workspace:URL {workspaceBase.appendingPathComponent("run-"+String(getpid()))}
    @discardableResult func prepare()->Bool {
        do {
            let fm=FileManager.default
            try fm.createDirectory(at:workspaceBase,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:workspaceBase.path)
            for item in (try? fm.contentsOfDirectory(at:workspaceBase,includingPropertiesForKeys:nil)) ?? [] {
                guard item.lastPathComponent.range(of:"^run-[0-9]+$",options:.regularExpression) != nil,
                      let pid=Int32(item.lastPathComponent.dropFirst(4)),pid>0,pid != getpid(),
                      let attrs=try? fm.attributesOfItem(atPath:item.path),attrs[.type] as? FileAttributeType == .typeDirectory,
                      (attrs[.ownerAccountID] as? NSNumber)?.uint32Value==getuid() else{continue}
                if kill(pid,0) == -1 && errno==ESRCH {try? fm.removeItem(at:item)}
            }
            try fm.createDirectory(at:workspace,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:workspace.path)
            return true
        }catch{lastError="本机无法写入临时配置，请检查磁盘空间和目录权限。";return false}
    }
    @discardableResult func speak(clickedAt:TimeInterval=ProcessInfo.processInfo.systemUptime)->Bool {
        guard !busy,clickedAt>lastSettledAt else{return false}
        guard let actualConfig=configuration?() else{return false}
        let config:PetConfiguration?=actualConfig
        if let config {
            guard !config.paused else{return false}
            if config.bubbleSource == .local {
                guard let line=local.next(config.localLines) else{return false}
                onResult?(String(line.prefix(config.maxCharacters)),nil);return true
            }
            guard config.backend != .disabled else{return false}
        }
        activeBackend=config?.backend ?? .dsh
        usageSteps.removeAll();receivedUsage=false;usageFinal=false;recordID=UUID();recordStarted=Date();recordCounts=TokenCounts(input:nil,cached:nil,output:nil,reasoning:nil)
        recordModel=activeBackend == .api ? config?.apiModel ?? "" : activeBackend == .codex ? config?.codexModel ?? "" : config?.dshModel ?? "deepseek-flash"
        if recordModel.isEmpty{recordModel="客户端默认"}
        let instructions=(config?.persona ?? persona)+"\n只输出一句正文，最多\(config?.maxCharacters ?? 40)个字。"
        busy=true;buffer.removeAll();finalText=nil;failed=false;lastError=nil;sessionID=UUID().uuidString
        if activeBackend == .api,let config {
            let token=UUID();generation=token
            api.onUsage={ [weak self] usage in guard let self,self.generation==token,self.busy else{return};self.acceptUsage(usage,final:true)}
            timeout=Timer.scheduledTimer(withTimeInterval:responseTimeout,repeats:false){[weak self] _ in self?.finish(nil,"请求超时了，再戳一下？")}
            do {try api.request(config:config,persona:instructions,key:APIKeyStore.get(endpoint:config.apiURL)){[weak self] text,error in guard let self,self.generation==token else{return};self.finish(text,error)}}catch{finish(nil,error.localizedDescription)}
            return true
        }
        guard prepare() else{finish(nil,lastError);return true}
        let kind=activeBackend == .codex ? "codex":"dsh"
        let path=activeBackend == .codex ? config?.codexPath:config?.dshPath
        guard let exe=executableOverride ?? ExecutableLocator.find(kind,override:path ?? "") else {finish(nil,"找不到 \(kind == "dsh" ? "DeepSeek Harness":"Codex") 的程序文件，请在设置里选择位置。");return true}
        var patch:URL?
        if activeBackend == .dsh {
        guard let resource=patchOverride ?? Bundle.main.resourceURL?.appendingPathComponent("Companion/dsh-lean.yml"),let base=try? String(contentsOf:resource,encoding:.utf8) else {finish(nil,"桌宠的文件位置变了，请退出后重新打开我。");return true}
        let file=workspace.appendingPathComponent("dragonpet-lean-"+sessionID+".yml");patch=file;patchFile=file
        // JSON strings are valid YAML scalars. Do not interpolate personality as executable YAML.
        guard let encoded=try? JSONSerialization.data(withJSONObject:instructions,options:.fragmentsAllowed),let scalar=String(data:encoded,encoding:.utf8) else{finish(nil,"这会儿没想出来，再戳一下？");return true}
        guard base.components(separatedBy:"personaPrefix: \"\"").count==2 else{finish(nil,"Harness 配置模板不兼容，请更新桌宠。");return true}
        var patched=base.replacingOccurrences(of:"personaPrefix: \"\"",with:"personaPrefix: "+scalar)
        if let config {
            for (old,value) in [("provider: deepseek-account",config.dshProvider),("model: deepseek-flash",config.dshModel),("reasoningEffort: off",config.dshEffort)] {
                guard patched.components(separatedBy:old).count==2 else{finish(nil,"Harness 配置模板不兼容，请更新桌宠。");return true}
                let key=String(old.split(separator:":")[0])
                guard let encoded=try? JSONSerialization.data(withJSONObject:value,options:.fragmentsAllowed),let scalar=String(data:encoded,encoding:.utf8) else{finish(nil,"模型配置无法编码，请检查设置。");return true}
                patched=patched.replacingOccurrences(of:old,with:key+": "+scalar)
            }
        }
        do {try patched.write(to:file,atomically:true,encoding:.utf8);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)}catch{finish(nil,"本机无法写入临时配置，请检查磁盘空间和目录权限。");return true}
        }
        let token=UUID();generation=token
        let p=Process();p.executableURL=exe;p.currentDirectoryURL=workspace
        var input:Pipe?
        if activeBackend == .codex {
            var args=["exec","--ignore-user-config","--ephemeral","--skip-git-repo-check","--json","-s","read-only","-c","features.shell_tool=false","-c","features.apply_patch_freeform=false","-c","features.multi_agent=false","-c","web_search=\"disabled\"","-c","model_reasoning_effort=\"\(config?.codexEffort ?? "low")\""]
            if let model=config?.codexModel,!model.isEmpty{args += ["-m",model]}
            args.append("-");input=Pipe()
            p.arguments=args
        }else{p.arguments=["headless","--patch",patch!.path,"--json","随口说一句话。"]}
        let pipe=Pipe();p.standardOutput=pipe;p.standardError=FileHandle.nullDevice;p.standardInput=input ?? FileHandle.nullDevice
        reader=pipe.fileHandleForReading;process=p
        reader?.readabilityHandler={ [weak self] handle in
            let data=handle.availableData
            DispatchQueue.main.async {guard let self,self.generation==token else{return};if !data.isEmpty{self.receive(data)}}
        }
        p.terminationHandler={ [weak self] ended in
            DispatchQueue.main.asyncAfter(deadline:.now()+0.05) {
                guard let self,self.generation==token else{return}
                self.reader?.readabilityHandler=nil
                if let remaining=try? self.reader?.readToEnd(),!remaining.isEmpty{self.receive(remaining)}
                let text=self.finalText?.trimmingCharacters(in:.whitespacesAndNewlines)
                if ended.terminationStatus==0,!self.failed,let text,!text.isEmpty{self.finish(String(text.prefix(100)),nil)}else{self.finish(nil,self.lastError ?? "生成失败，请在设置中检查登录、模型和客户端版本。") }
            }
        }
        timeout=Timer.scheduledTimer(withTimeInterval:responseTimeout,repeats:false){[weak self] _ in self?.stop();self?.finish(nil,"刚才走神了，再戳一下？")}
        do {
            try p.run()
            if let input {
                // The child owns the read end; close our copy so cancellation releases a blocked writer.
                try? input.fileHandleForReading.close()
                let writer=input.fileHandleForWriting
                _ = fcntl(writer.fileDescriptor,F_SETNOSIGPIPE,1)
                let data=Data((instructions+"\n随口说一句话。禁止使用任何工具。").utf8)
                DispatchQueue.global(qos:.utility).async { [weak self] in
                    defer{try? writer.close()}
                    do {try writer.write(contentsOf:data)}
                    catch {DispatchQueue.main.async{guard let self,self.generation==token,self.busy else{return};self.finish(nil,"无法向客户端发送提示，请检查客户端版本。")}}
                }
            }
        }catch{stop();finish(nil,"这会儿连不上 DeepSeek，再戳一下？")}
        return true
    }
    private func receive(_ data:Data){
        buffer.append(data)
        while let newline=buffer.firstIndex(of:10){
            let line=Data(buffer[..<newline]);buffer.removeSubrange(...newline)
            guard let event=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any] else{continue}
            switch event["type"] as? String {
            case "session":sessionID=event["sessionId"] as? String ?? sessionID
            case "final":finalText=event["text"] as? String
            case "error","tool_call","turn.failed":
                failed=true
                let detail=(event["message"] as? String) ?? ((event["error"] as? [String:Any])?["message"] as? String) ?? ""
                lastError=Self.classifyError(detail)
            case "item.completed":
                if let item=event["item"] as? [String:Any],item["type"] as? String=="agent_message"{finalText=item["text"] as? String}
            case "turn.completed":if let usage=event["usage"] as? [String:Any]{acceptUsage(usage,final:true)}
            case "status":
                if event["phase"] as? String=="step_end",let usage=event["usage"] as? [String:Any]{acceptUsage(usage,step:String(describing:event["turn"] ?? 0)+":"+String(describing:event["step"] ?? 0))}
                if event["phase"] as? String=="turn_end",let reason=event["reason"] as? [String:Any],reason["kind"] as? String != "completed"{failed=true;lastError=Self.classifyError(String(describing:reason))}
            default:break
            }
        }
    }
    private func acceptUsage(_ usage:[String:Any],step:String?=nil,final:Bool=false){
        if usageFinal && !final{return}
        if let step{guard usageSteps.insert(step).inserted else{return}}
        let counts=TokenCounts.parse(usage,backend:activeBackend)
        if final{usageFinal=true}
        if activeBackend == .dsh,receivedUsage,!final{recordCounts=recordCounts.adding(counts)}else{recordCounts=counts}
        receivedUsage=true;onUsage?(sessionID,usage)
    }
    private func record(_ status:String){onRecord?(TokenRecord(id:recordID,date:recordStarted,backend:activeBackend,model:String(recordModel.prefix(128)),origin:origin,seconds:Date().timeIntervalSince(recordStarted),status:status,counts:recordCounts,partial:status != "成功" && receivedUsage && !usageFinal))}
    static func classifyError(_ detail:String)->String {
        let text=detail.lowercased()
        if text.contains("401") || text.contains("unauthor") || text.contains("login") || text.contains("authentication"){return "账户未登录或认证失效，请在对应客户端重新登录。"}
        if text.contains("402") || text.contains("balance") || text.contains("insufficient"){return "账户余额或额度不足，请检查账户。"}
        if text.contains("429") || text.contains("rate limit") || text.contains("quota"){return "请求受限或额度不足，请稍后重试。"}
        if text.contains("model"){return "模型或思考强度不受支持，请检查设置。"}
        return "生成失败，请检查网络、登录和客户端版本。"
    }
    private func finish(_ text:String?,_ error:String?){guard busy else{return};record(error==nil ? "成功":"失败");lastError=error;lastSettledAt=ProcessInfo.processInfo.systemUptime;busy=false;timeout?.invalidate();timeout=nil;stop();onResult?(text.map{String($0.prefix(configuration?().maxCharacters ?? 100))},error)}
    func stop(){
        generation=UUID();api.cancel();
        if let file=patchFile{try? FileManager.default.removeItem(at:file);patchFile=nil}
reader?.readabilityHandler=nil;reader=nil
        let owned=process;process=nil;owned?.terminationHandler=nil
        if let owned,owned.isRunning{owned.terminate();DispatchQueue.global().asyncAfter(deadline:.now()+2){if owned.isRunning{kill(owned.processIdentifier,SIGKILL)}}}
    }
    func shutdown(){if busy{record("取消");lastSettledAt=ProcessInfo.processInfo.systemUptime};timeout?.invalidate();timeout=nil;busy=false;stop()}
    deinit{process?.terminate()}
}
