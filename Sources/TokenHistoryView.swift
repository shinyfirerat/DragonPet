import SwiftUI
import AppKit

struct TokenHistoryView:View {
    @ObservedObject var store=TokenHistoryStore.shared
    @State private var count=10
    @State private var clicksOnly=true
    private var visible:[TokenRecord]{Array(store.records.filter{!clicksOnly || $0.origin=="点击"}.prefix(count))}
    private func number(_ n:Int?)->String{n.map{String($0)} ?? "未知"}
    private var totals:String {
        let known=visible.filter{$0.partial != true}.compactMap{$0.counts.total}
        return "已报告用量的 \(known.count) 次合计 \(known.reduce(0,+)) token"
    }
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Picker("最近",selection:$count){ForEach([10,50,200],id:\.self){Text("\($0) 次").tag($0)}}.frame(width:155)
                Toggle("只看点击",isOn:$clicksOnly)
                Spacer()
                Button("清空记录…"){clear()}
            }
            Text(totals).font(.headline)
            Text("输入已包含缓存；缓存列是其中一部分。未知不按零计算，失败或取消也可能产生消耗。思考 token 通常包含在输出中，不重复加总。").font(.caption).foregroundStyle(.secondary)
            if let error=store.error{Text(error).foregroundStyle(.red).font(.caption)}
            ScrollView {
                LazyVStack(alignment:.leading,spacing:9) {
                    if visible.isEmpty{Text("还没有记录。从现在开始，实际生成请求会记在这里。").font(.callout).padding(.vertical,30)}
                    ForEach(visible){row in
                        VStack(alignment:.leading,spacing:7) {
                            HStack {
                                Text(row.date,format:.dateTime.month().day().hour().minute().second()).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(row.origin+" · "+row.status+String(format:" · %.1f 秒",row.seconds)).font(.caption)
                            }
                            if row.partial == true {Text("部分回传用量，最终消耗未知；不计入合计。").font(.caption).foregroundStyle(.secondary)}
                            Text(row.backend.title+" · "+row.model).font(.system(size:12,weight:.medium))
                            HStack(spacing:18){Text("输入 \(number(row.counts.input))");Text("缓存 \(number(row.counts.cached))");Text("输出 \(number(row.counts.output))");Spacer();Text("合计 \(number(row.counts.total))")}.font(.system(size:11)).monospacedDigit()
                            if let reasoning=row.counts.reasoning,reasoning>0{Text("其中思考输出 \(reasoning)").font(.caption).foregroundStyle(.secondary)}
                        }.padding(12).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:10))
                    }
                }
            }
            Text("仅保存在这台 Mac 的当前用户下，最多 200 条。不保存气泡正文、性格、Key 或 API 地址；不会随设置导出。以前的点击无法补回。").font(.caption).foregroundStyle(.secondary)
        }.padding(15)
    }
    private func clear(){let alert=NSAlert();alert.messageText="清空本机用量记录？";alert.addButton(withTitle:"清空");alert.addButton(withTitle:"取消");if alert.runModal() == .alertFirstButtonReturn{store.clear()}}
}
