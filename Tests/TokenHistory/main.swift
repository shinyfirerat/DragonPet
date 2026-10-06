import Foundation
let dsh=TokenCounts.parse(["inputTokens":196,"cacheReadTokens":5376,"outputTokens":14],backend:.dsh)
assert(dsh.input==5572 && dsh.cached==5376 && dsh.total==5586)
assert(dsh.adding(dsh).total==11172)
let codex=TokenCounts.parse(["input_tokens":13930,"cached_input_tokens":13696,"output_tokens":21],backend:.codex)
assert(codex.input==13930 && codex.total==13951)
let api=TokenCounts.parse(["prompt_tokens":120,"completion_tokens":10,"prompt_tokens_details":["cached_tokens":80],"completion_tokens_details":["reasoning_tokens":4]],backend:.api)
assert(api.total==130 && api.cached==80 && api.reasoning==4)
let missing=TokenCounts.parse([:],backend:.api);assert(missing.input==nil && missing.output==nil && missing.total==nil)
assert(TokenCounts.parse(["prompt_tokens":true,"completion_tokens":-1],backend:.api).total==nil)
let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer{try? FileManager.default.removeItem(at:directory)}
let file=directory.appendingPathComponent("history.json")
let store=TokenHistoryStore(url:file)
let id=UUID()
let row=TokenRecord(id:id,date:Date(),backend:.dsh,model:"deepseek-flash",origin:"点击",seconds:1,status:"成功",counts:dsh)
store.append(row);store.append(row);assert(store.records.count==1)
for _ in 0..<205 {store.append(TokenRecord(id:UUID(),date:Date(),backend:.api,model:"test-model",origin:"连接测试",seconds:1,status:"失败",counts:missing))}
assert(store.records.count==200)
let restored=TokenHistoryStore(url:file);assert(restored.records.count==200 && restored.records[0].counts.total==nil)
let data=try Data(contentsOf:file);let text=String(data:data,encoding:.utf8)!
assert(!text.contains("apiKey") && !text.contains("persona") && !text.contains("apiURL"))
restored.clear();assert(TokenHistoryStore(url:file).records.isEmpty)
print("PASS: DSH/Codex/API token accounting; no cache double-count; missing/invalid unknown; dedup; persistence cap; clear")
