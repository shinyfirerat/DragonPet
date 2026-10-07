import AppKit
private func emitUsageDiagnostic(_ object:[String:Any]) {
    guard let data=try? JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]) else{return}
    let line=data+Data([10])
    if let flag=CommandLine.arguments.firstIndex(of:"--usage-log-path"),CommandLine.arguments.indices.contains(flag+1) {
        let path=CommandLine.arguments[flag+1]
        if !FileManager.default.fileExists(atPath:path){FileManager.default.createFile(atPath:path,contents:nil,attributes:[.posixPermissions:0o600])}
        try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path)
        if let file=FileHandle(forWritingAtPath:path){_ = try? file.seekToEnd();try? file.write(contentsOf:line);try? file.close()}
    }else{try? FileHandle.standardOutput.write(contentsOf:line)}
}

final class AppDelegate:NSObject,NSApplicationDelegate {
    var panel:PetPanel!
    var pet:PetView!
    var skin:PetSkin!
    let audio=PetAudio()
    let service=UsageService()
    var balances:BalancePanel!
    var companion:CompanionService!
    let settingsWindow=SettingsWindow()
    let speech=SpeechBubble()
    var status:NSStatusItem!
    var refreshTimer:Timer?
    var motionProbe:MotionProbe?
    func applicationDidFinishLaunching(_ notification:Notification) {
        let userSkin=AppPaths.support.appendingPathComponent("Skins/white-dragon")
        if !FileManager.default.fileExists(atPath:userSkin.appendingPathComponent("skin.json").path) {
            try? FileManager.default.createDirectory(at:userSkin,withIntermediateDirectories:true)
            for name in ["portrait.png","press.wav","release.wav","skin.json"] {
                if let data=try? Data(contentsOf:bundledSkin.appendingPathComponent(name)) {try? data.write(to:userSkin.appendingPathComponent(name),options:.atomic)}
            }
        }
        do { try loadSkin(PetPreferences.shared.string(forKey:"skinDirectory").map{URL(fileURLWithPath:$0)} ?? userSkin) }
        catch { do { try loadSkin(bundledSkin) } catch { NSApp.terminate(nil);return } }
        panel=PetPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.level = .floating;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
        pet=PetView(skin:skin);panel.contentView=pet
        pet.onPress={ [weak self] down in self?.motionProbe?.note(down ? "press":"release");self?.audio.play(down:down) }
        speech.anchor={ [weak self] in self?.panel.frame ?? .zero }
        companion=CompanionService(persona:PetConfiguration.defaultPersona)
        companion.configuration={ConfigurationStore.shared.value}
        companion.onRecord={TokenHistoryStore.shared.append($0)}
        service.configuration={ConfigurationStore.shared.value}
        if CommandLine.arguments.contains("--usage-diagnostics") {
            companion.onUsage={id,usage in
                emitUsageDiagnostic(["event":"usage","turnId":id,"usage":usage])
            }
        }
        companion.onResult={ [weak self] text,error in guard let self else{return};
            if CommandLine.arguments.contains("--usage-diagnostics"){emitUsageDiagnostic(["event":"reply","text":text ?? error ?? ""])}
ConfigurationStore.shared.diagnostic=error ?? ""
let phrase=text ?? error ?? "刚才走神了，再戳一下？";self.pet.setAccessibilityValue(phrase);self.pet.endThinking();self.speech.say(phrase) }
        pet.onTap={ [weak self] clickedAt in
            guard let self,self.companion.speak(clickedAt:clickedAt) else{return}
            if self.companion.busy {self.pet.setAccessibilityValue("正在想一个小念头…");self.pet.beginThinking();self.speech.begin()}
        }
        pet.onMove={ [weak self] in self?.motionProbe?.note("drag");self?.speech.follow() }
        pet.onMenu={ [weak self] e in guard let self else{return};self.speech.dismiss();self.showBalances() }
        companion.prepare()
        balances=BalancePanel(service:service)
        balances.onSettings={ [weak self] in self?.showSettings() }
        balances.onQuit={NSApp.terminate(nil)}
        settingsWindow.onSize={ [weak self] in self?.resize($0) }
        settingsWindow.onMute={ [weak self] in self?.audio.muted=$0;PetPreferences.shared.set($0,forKey:"muted") }
        settingsWindow.onSkin={ [weak self] in self?.importSkin() }
        settingsWindow.onReload={ [weak self] in self?.reloadSkin() }
        settingsWindow.onOpenSkin={ [weak self] in self?.openSkin() }
        settingsWindow.onReset={ [weak self] in self?.resetPosition() }
        settingsWindow.onHide={ [weak self] in self?.toggle() }
        settingsWindow.onChooseCLI={ [weak self] in self?.chooseCLI() }
        settingsWindow.onApply={ [weak self] in self?.applyConfiguration() }
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);status.button?.image=NSImage(systemSymbolName:"pawprint",accessibilityDescription:"桌宠");status.button?.target=self;status.button?.action=#selector(statusMenu)
        let size=PetPreferences.shared.integer(forKey:"petSize");resize((60...260).contains(size) ? size:Int(skin.manifest.defaultHeight));resetPosition()
        if PetPreferences.shared.object(forKey:"petX") != nil { let p=NSPoint(x:PetPreferences.shared.double(forKey:"petX"),y:PetPreferences.shared.double(forKey:"petY"));let r=NSRect(origin:p,size:panel.frame.size);if NSScreen.screens.contains(where:{$0.visibleFrame.intersects(r)}) {panel.setFrameOrigin(p)} }
        if CommandLine.arguments.contains("--offline-smoke") {
            // Test windows must not briefly impersonate the user's pet on the desktop.
            let screens=NSScreen.screens.map{$0.frame}
            panel.setFrameOrigin(NSPoint(x:(screens.map{$0.maxX}.max() ?? 0)+1024,y:(screens.map{$0.maxY}.max() ?? 0)+1024))
        }
        panel.orderFrontRegardless()
        if CommandLine.arguments.contains("--show-balances") {showBalances()}
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        applyConfiguration()
        motionProbe=MotionProbe(panel:panel,pet:pet)
        if CommandLine.arguments.contains("--show-settings"){showSettings()}
        if CommandLine.arguments.contains("--offline-smoke") {
            let config=ConfigurationStore.shared.value
            let ok=panel.isVisible && pet.skin.image.size.height>0 && config.paused && config.backend == .disabled && config.quotaSources.isEmpty && !companion.busy && !service.busy
            emitUsageDiagnostic(["event":"offline-smoke","result":ok ? "passed":"failed","speechBackend":config.backend.rawValue,"quotaSources":config.quotaSources.count,"bubblesOff":config.paused,"configSource":ConfigurationStore.shared.configSource])
            DispatchQueue.main.asyncAfter(deadline:.now()+0.2){if !ok{exit(1)};NSApp.terminate(nil)}
        }
        if !CommandLine.arguments.contains("--offline-smoke") && ConfigurationStore.shared.value.backend == .disabled && PetPreferences.shared.object(forKey:"setupShown")==nil{PetPreferences.shared.set(true,forKey:"setupShown");pet.setAccessibilityValue("戳我会压扁，右键可以查看额度与打开设置。")}
    }
    func applicationWillTerminate(_ notification:Notification){service.cancel();companion?.shutdown();settingsWindow.shutdown();speech.dismiss()}
    var bundledSkin:URL { (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Skins/white-dragon") }
    func loadSkin(_ url:URL)throws {let s=try PetSkin.load(url);skin=s;audio.load(s)}
    func menu()->NSMenu {
        let m=NSMenu()
        func add(_ title:String,_ action:Selector)->NSMenuItem {let i=NSMenuItem(title:title,action:action,keyEquivalent:"");i.target=self;m.addItem(i);return i}
        _=add("查看所有已启用来源的余额 / 额度",#selector(showBalances))
        m.addItem(.separator());_=add("设置…",#selector(showSettings));_=add("显示 / 隐藏",#selector(toggle));m.addItem(.separator());_=add("退出桌宠",#selector(quit));return m
    }
    func applyConfiguration(){
        motionProbe?.note("apply-configuration")
        companion.shutdown();settingsWindow.shutdown();pet.resetMood();speech.dismiss()
        let config=ConfigurationStore.shared.value;audio.volume=Float(config.volume);speech.duration=config.bubbleSeconds
        balances.render();refreshTimer?.invalidate()
        if CommandLine.arguments.contains("--offline-smoke"){return}
        service.refresh()
        refreshTimer=Timer.scheduledTimer(withTimeInterval:config.refreshSeconds,repeats:true){[weak self] _ in self?.service.refresh()}
    }
    @objc func showSettings(){balances.panel.orderOut(nil);settingsWindow.show()}
    func resize(_ height:Int) {
        let size=NSSize(width:CGFloat(height)*skin.image.size.width/skin.image.size.height*1.3+16,height:CGFloat(height)+16)
        let frame=PetGeometry.resizedFrame(panel.frame,to:size,in:NSScreen.screens.map{$0.visibleFrame})
        panel.setFrame(frame,display:true)
        PetPreferences.shared.set(height,forKey:"petSize")
        if panel.isVisible {PetPreferences.shared.set(frame.minX,forKey:"petX");PetPreferences.shared.set(frame.minY,forKey:"petY")}
        speech.follow()
    }
    @objc func statusMenu(){status.menu=menu();status.button?.performClick(nil);status.menu=nil}
    @objc func showBalances(){balances.show(near:panel.frame)}
    @objc func resetPosition(){guard let s=NSScreen.main?.visibleFrame else{return};panel.setFrameOrigin(NSPoint(x:s.maxX-panel.frame.width-24,y:s.minY+16))}
    @objc func screenChanged(){if CommandLine.arguments.contains("--offline-smoke"){return};motionProbe?.note("screen-parameters-changed");if !NSScreen.screens.contains(where:{$0.visibleFrame.intersects(panel.frame)}){resetPosition()}}
    @objc func toggle(){if panel.isVisible {panel.orderOut(nil);speech.dismiss()}else{panel.orderFrontRegardless()}}
    @objc func quit(){NSApp.terminate(nil)}
    func alert(_ text:String){let a=NSAlert();a.messageText=text;a.runModal()}
    @objc func importSkin(){let picker=NSOpenPanel();picker.canChooseDirectories=true;picker.canChooseFiles=false;picker.message="选择包含 skin.json 和立绘的形象文件夹";if picker.runModal() == .OK,let url=picker.url {do{try loadSkin(url);PetPreferences.shared.set(url.path,forKey:"skinDirectory");applySkin()}catch{alert(error.localizedDescription)}}}
    func applySkin(){pet.skin=skin;pet.setAccessibilityLabel(skin.manifest.name);pet.needsDisplay=true;resize(PetPreferences.shared.integer(forKey:"petSize"))}
    @objc func reloadSkin(){do{try loadSkin(skin.directory);applySkin()}catch{alert(error.localizedDescription)}}
    @objc func openSkin(){NSWorkspace.shared.open(skin.directory)}
    @objc func chooseCLI(){let picker=NSOpenPanel();picker.message="选择 CodexBarCLI 或 codexbar 可执行文件";if picker.runModal() == .OK,let url=picker.url,FileManager.default.isExecutableFile(atPath:url.path){PetPreferences.shared.set(url.path,forKey:"codexbarCLI");service.refresh()}}
}
if CommandLine.arguments.contains("--check-fixtures") {
    for path in CommandLine.arguments.dropFirst(2) {
        do { let rows=try UsageParser.parse(Data(contentsOf:URL(fileURLWithPath:path)));guard !rows.isEmpty else{fatalError("empty fixture")};print(URL(fileURLWithPath:path).lastPathComponent,rows.map{$0.title+": "+$0.lines.joined(separator:" | ")}.joined(separator:"\n")) }
        catch {fputs("Fixture parse failed\n",stderr);exit(1)}
    }
} else {
    let app=NSApplication.shared;app.setActivationPolicy(.accessory);let delegate=AppDelegate();app.delegate=delegate;app.run()
}
