import AppKit
import SwiftUI

private let ink=Color(red:0.29,green:0.23,blue:0.38)
private let lavender=Color(red:0.65,green:0.53,blue:0.79)
private let cream=Color(red:0.99,green:0.97,blue:0.94)
final class CardState:ObservableObject {
    @Published var rows=[UsageRow]()
    @Published var busy=false
    @Published var error:String?
}
private struct BalanceCard:View {
    @ObservedObject var state:CardState
    let owner:BalancePanel
    var body:some View {
        VStack(spacing:14) {
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text("我的能量卡").font(.system(size:19,weight:.semibold))
                    Text("陪你慢慢把事情做好").font(.system(size:11)).foregroundStyle(ink.opacity(0.55))
                }
                Spacer()
                Button(action:{owner.panel.orderOut(nil)}) {Image(systemName:"xmark").font(.system(size:11,weight:.semibold)).frame(width:25,height:25).background(lavender.opacity(0.12),in:Circle())}.buttonStyle(.plain).accessibilityLabel("关闭卡片")
            }
            balances
            HStack {
                Text(state.busy ? "正在更新…":"来自 CodexBar").font(.system(size:10)).foregroundStyle(ink.opacity(0.5))
                Spacer()
                Button(action:{owner.onSettings?()}){Image(systemName:"gearshape")}.accessibilityLabel("桌宠设置").help("设置")
                Button(action:{owner.onQuit?()}){Image(systemName:"rectangle.portrait.and.arrow.right")}.accessibilityLabel("退出桌宠").help("退出桌宠")
            }.font(.system(size:13)).buttonStyle(.plain)
        }.padding(20).foregroundStyle(ink)
            .frame(width:350,height:510)
            .background(LinearGradient(colors:[cream,Color(red:0.95,green:0.91,blue:0.98)],startPoint:.topLeading,endPoint:.bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius:24))
            .overlay(RoundedRectangle(cornerRadius:24).stroke(.white.opacity(0.85),lineWidth:1))
            .environment(\.colorScheme,.light)
    }
    var balances:some View {
        ScrollView {
            VStack(spacing:10) {
                if let error=state.error {Text(error).font(.system(size:11)).padding(12)}
                if state.rows.isEmpty {Text(state.busy ? "正在收集你的额度…":"暂时没有额度数据").font(.system(size:13)).padding(.vertical,40)}
                ForEach(Array(state.rows.enumerated()),id:\.offset) { _,row in
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            Circle().fill(lavender).frame(width:6,height:6)
                            Text(row.title.replacingOccurrences(of:" / Harness",with:"")).font(.system(size:14,weight:.semibold))
                            Spacer()
                        }
                        ForEach(Array(row.lines.enumerated()),id:\.offset) { _,line in
                            if let range=line.range(of:"：剩余 "),line.hasSuffix("%"),let value=Double(line[range.upperBound...].dropLast()) {
                                VStack(spacing:5) {
                                    HStack {Text(String(line[..<range.lowerBound])).font(.system(size:11));Spacer();Text(String(format:"剩余 %.0f%%",value)).font(.system(size:12,weight:.medium)).monospacedDigit()}
                                    GeometryReader { proxy in
                                        ZStack(alignment:.leading) {
                                            Capsule().fill(lavender.opacity(0.13))
                                            Capsule().fill(lavender).frame(width:proxy.size.width*max(0,min(1,value/100)))
                                        }
                                    }.frame(height:5)
                                }
                            } else {
                                Text(line.trimmingCharacters(in:.whitespaces)).font(.system(size:line.contains("重置") ? 10:12)).foregroundStyle(ink.opacity(line.contains("重置") ? 0.5:0.85)).fixedSize(horizontal:false,vertical:true)
                            }
                        }
                        Text("更新 "+(row.timestamp.map(UsageParser.date) ?? "未知")).font(.system(size:9)).foregroundStyle(ink.opacity(0.4))
                    }.padding(13).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.65),in:RoundedRectangle(cornerRadius:15))
                }
            }
        }.scrollIndicators(.hidden).frame(maxHeight:.infinity)
    }

}
private final class CardPanel:NSPanel { override var canBecomeKey:Bool { true } }
final class BalancePanel:NSObject {
    let panel:NSPanel=CardPanel(contentRect:NSRect(x:0,y:0,width:350,height:510),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    let service:UsageService
    let state=CardState()
    var onSettings:(()->Void)?
    var onQuit:(()->Void)?
    private var outside:Any?
    private var inside:Any?
    init(service:UsageService) {
        self.service=service;super.init()
        panel.isReleasedWhenClosed=false;panel.level = .floating;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=true;panel.hidesOnDeactivate=false
        panel.contentView=NSHostingView(rootView:BalanceCard(state:state,owner:self))
        service.onChange={ [weak self] in self?.render() }
        outside=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]){[weak self] _ in guard let self,self.panel.isVisible else{return};self.panel.orderOut(nil)}
        inside=NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown,.keyDown]){[weak self] event in
            if event.type == .keyDown && event.keyCode==53 {self?.panel.orderOut(nil)}
            else if event.type != .keyDown,event.window !== self?.panel {self?.panel.orderOut(nil)}
            return event
        }
    }
    deinit {if let outside {NSEvent.removeMonitor(outside)};if let inside {NSEvent.removeMonitor(inside)}}
    func show(near rect:NSRect) {
        let screen=NSScreen.screens.first{$0.visibleFrame.intersects(rect)}?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:800,height:600)
        let x=rect.minX-panel.frame.width-12
        panel.setFrameOrigin(NSPoint(x:max(screen.minX+8,min(x,screen.maxX-panel.frame.width-8)),y:max(screen.minY+8,min(rect.minY,screen.maxY-panel.frame.height-8))))
        panel.makeKeyAndOrderFront(nil);render();service.refresh()
    }
    func render(){let order=ConfigurationStore.shared.value.quotaSources.map{$0.id};state.rows=service.rows.sorted{(order.firstIndex(of:$0.providerID) ?? 999)<(order.firstIndex(of:$1.providerID) ?? 999)};state.busy=service.busy;state.error=service.error}
}
