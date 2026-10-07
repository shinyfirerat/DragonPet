import AppKit
final class PetView: NSView {
    var skin: PetSkin
    var pointerPosition:()->NSPoint = {NSEvent.mouseLocation}
    var onPress: ((Bool)->Void)?
    var onTap:((TimeInterval)->Void)?
    var onMove:(()->Void)?
    var onMenu: ((NSEvent)->Void)?
    private var tapTimestamp:TimeInterval=0
    private var startMouse = NSPoint.zero
    private var startOrigin = NSPoint.zero
    private var moved = false
    private var amount: CGFloat = 0
    private var target: CGFloat = 0
    private var timer: Timer?
    private var moodTimer:Timer?
    private var moodStart=Date()
    private var moodTime=0.0
    private var thinking=false
    private var bounceStart:Date?
    var motionState:String {"thinking=\(thinking);press=\(String(format:"%.3f",Double(amount)));bounce=\(bounceStart != nil);timer=\(moodTimer != nil)"}
    var isMoodAnimating:Bool {moodTimer != nil}
    func resetMood(){
        thinking=false;bounceStart=nil;moodTime=0
        moodTimer?.invalidate();moodTimer=nil;needsDisplay=true
    }
    func beginThinking(){thinking=true;moodStart=Date();startMoodTimer()}
    func endThinking(){thinking=false;bounceStart=Date();startMoodTimer()}
    private func startMoodTimer(){
        guard moodTimer==nil else{return}
        moodTimer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){[weak self] timer in
            guard let self else{timer.invalidate();return}
            self.moodTime=Date().timeIntervalSince(self.moodStart)
            if !self.thinking,self.bounceStart.map({Date().timeIntervalSince($0)>0.65}) ?? true {timer.invalidate();self.moodTimer=nil;self.bounceStart=nil}
            self.needsDisplay=true
        }
        RunLoop.main.add(moodTimer!,forMode:.eventTracking)
    }
    init(skin: PetSkin) { self.skin = skin; super.init(frame: .zero);setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel(skin.manifest.name);setAccessibilityHelp("左键按压回弹，拖动移动，右键查看额度") }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let height = bounds.height - 16
        let sx = 1 + amount * (skin.manifest.pressScaleX - 1)
        let sy = 1 + amount * (skin.manifest.pressScaleY - 1)
        let width = height * skin.image.size.width / skin.image.size.height * sx
        NSGraphicsContext.saveGraphicsState()
        var angle=0.0
        if thinking {angle=moodTime<0.6 ? sin(moodTime*10)*2.4 : sin((moodTime-0.6)*1.25)*1.1}
        let bounce=bounceStart.map{max(0,sin(min(1,Date().timeIntervalSince($0)/0.55)*Double.pi))*3} ?? 0
        let transform=NSAffineTransform();transform.translateX(by:bounds.midX,yBy:8+CGFloat(bounce));transform.rotate(byDegrees:CGFloat(angle));transform.translateX(by:-bounds.midX,yBy:-8);transform.concat()
        skin.image.draw(in: NSRect(x:(bounds.width-width)/2,y:8,width:width,height:height*sy),from:.zero,operation:.sourceOver,fraction:1)
        NSGraphicsContext.restoreGraphicsState()
    }
    private func animate(_ value: CGFloat) {
        target = value; timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.amount += (self.target-self.amount)*0.3
            if abs(self.target-self.amount)<0.002 { self.amount=self.target;timer.invalidate() }
            self.needsDisplay=true
        }
        RunLoop.main.add(timer!,forMode:.eventTracking)
    }
    override func mouseDown(with event: NSEvent) {
        tapTimestamp=event.timestamp;startMouse=pointerPosition();startOrigin=window?.frame.origin ?? .zero;moved=false
        amount=0.55;animate(1);needsDisplay=true;onPress?(true)
    }
    override func mouseDragged(with event: NSEvent) {
        let p=pointerPosition();let dx=p.x-startMouse.x,dy=p.y-startMouse.y
        guard abs(dx)+abs(dy)>4 || moved else { return }
        if !moved { moved=true;animate(0) }
        window?.setFrameOrigin(NSPoint(x:startOrigin.x+dx,y:startOrigin.y+dy));onMove?()
    }
    override func mouseUp(with event: NSEvent) {
        animate(0);onPress?(false);if !moved {onTap?(tapTimestamp)}
        if let p=window?.frame.origin { PetPreferences.shared.set(p.x,forKey:"petX");PetPreferences.shared.set(p.y,forKey:"petY") }
    }
    override func accessibilityPerformPress()->Bool {
        let clickedAt=ProcessInfo.processInfo.systemUptime
        amount=0.55;animate(1);needsDisplay=true;onPress?(true)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.15){[weak self] in self?.animate(0);self?.onPress?(false);self?.onTap?(clickedAt)}
        return true
    }
    override func rightMouseDown(with event: NSEvent) { onMenu?(event) }
}
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
