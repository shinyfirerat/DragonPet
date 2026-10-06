import AppKit

/// Opt-in local investigation. No absolute coordinates, screen capture, text, or account data.
final class MotionProbe {
    private var timer:Timer?
    private var observer:NSObjectProtocol?
    private var lastFrame:NSRect
    private var lastState:String=""
    private var events=0
    private let started=Date()
    private let file:URL
    private let panel:NSPanel
    private let pet:PetView
    init?(panel:NSPanel,pet:PetView){
        guard CommandLine.arguments.contains("--motion-diagnostics") else{return nil}
        self.panel=panel;self.pet=pet;lastFrame=panel.frame
        file=AppPaths.support.appendingPathComponent("motion-diagnostic.jsonl")
        do {
            try FileManager.default.createDirectory(at:AppPaths.support,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:AppPaths.support.path)
            if !FileManager.default.fileExists(atPath:file.path){FileManager.default.createFile(atPath:file.path,contents:nil,attributes:[.posixPermissions:0o600])}
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        }catch{return nil}
        write(["event":"motion-start","bubblesOff":ConfigurationStore.shared.value.paused])
        observer=NotificationCenter.default.addObserver(forName:NSWindow.didMoveNotification,object:panel,queue:.main){[weak self] _ in self?.sample("window-moved")}
        timer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true){[weak self] _ in self?.sample("state-changed")}
        sample("initial")
    }
    func note(_ reason:String){sample(reason,force:true)}
    private func sample(_ reason:String,force:Bool=false){
        let frame=panel.frame;let state=pet.motionState
        let moved=frame != lastFrame
        guard moved || state != lastState || force else{return}
        write(["event":reason,"dx":frame.minX-lastFrame.minX,"dy":frame.minY-lastFrame.minY,"resized":frame.size != lastFrame.size,"animation":state,"visible":panel.isVisible])
        lastFrame=frame;lastState=state;events+=1
    }
    private func write(_ value:[String:Any]){
        var object=value;object["elapsedSeconds"]=Date().timeIntervalSince(started)
        guard let data=try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys),let handle=FileHandle(forWritingAtPath:file.path) else{return}
        defer{try? handle.close()};_ = try? handle.seekToEnd();try? handle.write(contentsOf:data+Data([10]))
    }
    deinit{timer?.invalidate();if let observer{NotificationCenter.default.removeObserver(observer)}}
}
