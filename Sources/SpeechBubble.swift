import AppKit

private final class BubbleView:NSView {
    var phrase:String?
    var phase:Double=0
    var textOpacity:CGFloat=1
    override func draw(_ dirtyRect:NSRect){
        let fill=NSColor(calibratedRed:0.99,green:0.97,blue:0.96,alpha:1)
        let outline=NSColor(calibratedRed:0.83,green:0.76,blue:0.91,alpha:1)
        let rect=bounds.insetBy(dx:2,dy:2).offsetBy(dx:0,dy:4);let body=NSRect(x:rect.minX,y:12,width:rect.width,height:bounds.height-15)
        let path=NSBezierPath(roundedRect:body,xRadius:18,yRadius:18)
        fill.setFill();path.fill();outline.setStroke();path.lineWidth=1;path.stroke()
        let tail=NSBezierPath();tail.move(to:NSPoint(x:bounds.midX-7,y:13));tail.line(to:NSPoint(x:bounds.midX,y:3));tail.line(to:NSPoint(x:bounds.midX+7,y:13));fill.setFill();tail.fill()
        if let phrase {
            let style=NSMutableParagraphStyle();style.alignment = .center;style.lineBreakMode = .byWordWrapping
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor(calibratedRed:0.34,green:0.27,blue:0.44,alpha:textOpacity),.paragraphStyle:style]
            let s=NSAttributedString(string:phrase,attributes:attrs)
            let box=NSRect(x:16,y:body.minY+10,width:bounds.width-32,height:body.height-20)
            s.draw(in:box)
        }else{
            for i in 0..<3 {
                let wave=(sin(phase*2.7-Double(i)*0.8)+1)/2
                NSColor(calibratedRed:0.65,green:0.52,blue:0.79,alpha:0.45+wave*0.45).setFill()
                NSBezierPath(ovalIn:NSRect(x:bounds.midX-17+CGFloat(i)*14,y:body.midY-3+CGFloat(wave)*3,width:6,height:6)).fill()
            }
        }
    }
}
final class SpeechBubble {
    let panel=PetPanel(contentRect:NSRect(x:0,y:0,width:80,height:53),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    private let view=BubbleView()
    private var timer:Timer?
    private var delayed:DispatchWorkItem?
    private var hideTimer:Timer?
    private var revealTimer:Timer?
    private var started=Date()
    private var waiting=false
    var duration:TimeInterval=8
    var anchor:(()->NSRect)?
    init(){panel.contentView=view;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=true;panel.level = .floating;panel.isReleasedWhenClosed=false;panel.hidesOnDeactivate=false;panel.ignoresMouseEvents=true;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]}
    func begin(){
        dismiss();waiting=true;started=Date()
        let work=DispatchWorkItem{[weak self] in guard let self,self.waiting else{return};self.view.phrase=nil;self.panel.setContentSize(NSSize(width:80,height:53));self.follow();self.panel.alphaValue=0;self.panel.orderFrontRegardless();NSAnimationContext.runAnimationGroup{$0.duration=0.18;self.panel.animator().alphaValue=1}}
        delayed=work;DispatchQueue.main.asyncAfter(deadline:.now()+0.55,execute:work)
        timer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){[weak self] _ in guard let self else{return};self.view.phase=Date().timeIntervalSince(self.started);self.view.needsDisplay=true;self.follow()}
        RunLoop.main.add(timer!,forMode:.eventTracking)
    }
    func say(_ phrase:String){
        delayed?.cancel();delayed=nil;waiting=false;hideTimer?.invalidate()
        view.phrase=phrase;view.setAccessibilityElement(true);view.setAccessibilityRole(.staticText);view.setAccessibilityLabel(phrase)
        let width:CGFloat=240
        let measured=(phrase as NSString).boundingRect(with:NSSize(width:width-32,height:200),options:[.usesLineFragmentOrigin],attributes:[.font:NSFont.systemFont(ofSize:13,weight:.medium)])
        let height=max(65,ceil(measured.height)+39)
        let wasVisible=panel.isVisible
        let frame=position(size:NSSize(width:width,height:height))
        view.textOpacity=0;view.alphaValue=1
        if wasVisible {
            NSAnimationContext.runAnimationGroup{$0.duration=0.18;panel.animator().setFrame(frame,display:true)};fadeText()
        }else{panel.setFrame(frame,display:true);panel.alphaValue=1;panel.orderFrontRegardless();fadeText()}
        if timer==nil{timer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true){[weak self] _ in self?.follow()}}
        hideTimer=Timer.scheduledTimer(withTimeInterval:duration,repeats:false){[weak self] _ in self?.dismiss()}
    }
    private func fadeText(){
        revealTimer?.invalidate();let start=Date()
        revealTimer=Timer.scheduledTimer(withTimeInterval:1/60,repeats:true){[weak self] timer in
            guard let self else{timer.invalidate();return}
            self.view.textOpacity=min(1,CGFloat(Date().timeIntervalSince(start)/0.2));self.view.needsDisplay=true
            if self.view.textOpacity>=1 {timer.invalidate();self.revealTimer=nil}
        }
    }
    private func position(size:NSSize)->NSRect {
        let rect=anchor?() ?? .zero
        let screen=NSScreen.screens.first{$0.visibleFrame.intersects(rect)}?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:800,height:600)
        let x=max(screen.minX+8,min(rect.midX-size.width/2,screen.maxX-size.width-8))
        let top=rect.maxY+5
        let y=top+size.height<screen.maxY ? top:max(screen.minY+8,rect.minY-size.height-5)
        return NSRect(origin:NSPoint(x:x,y:y),size:size)
    }
    func follow(){guard panel.isVisible else{return};panel.setFrameOrigin(position(size:panel.frame.size).origin)}
    func dismiss(){revealTimer?.invalidate();revealTimer=nil;delayed?.cancel();delayed=nil;hideTimer?.invalidate();hideTimer=nil;timer?.invalidate();timer=nil;waiting=false;panel.orderOut(nil);view.alphaValue=1}
}
