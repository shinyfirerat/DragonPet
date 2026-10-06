import Foundation
import Combine
import CoreFoundation

struct TokenCounts:Codable,Equatable {
    var input:Int?
    var cached:Int?
    var output:Int?
    var reasoning:Int?
    var total:Int? {guard let input,let output else{return nil};let sum=input.addingReportingOverflow(output);return sum.overflow ? nil:sum.partialValue}
    func adding(_ other:TokenCounts)->TokenCounts {
        func sum(_ a:Int?,_ b:Int?)->Int? {guard let a,let b else{return nil};let sum=a.addingReportingOverflow(b);return sum.overflow ? nil:sum.partialValue}
        return TokenCounts(input:sum(input,other.input),cached:sum(cached,other.cached),output:sum(output,other.output),reasoning:sum(reasoning,other.reasoning))
    }
    static func parse(_ raw:[String:Any],backend:SpeechBackend)->TokenCounts {
        func number(_ object:[String:Any],_ key:String)->Int? {
            guard let n=object[key] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID() else{return nil}
            let d=n.doubleValue;guard d.isFinite,d>=0,d<=1_000_000_000_000,d.rounded()==d else{return nil};return n.intValue
        }
        var input:Int?,cache:Int?,output:Int?,reasoning:Int?
        switch backend {
        case .dsh:
            let fresh=number(raw,"inputTokens");cache=number(raw,"cacheReadTokens");output=number(raw,"outputTokens")
            if let fresh,let cache{input=fresh+cache}
            reasoning=number(raw,"reasoningTokens")
        case .codex:
            input=number(raw,"input_tokens");cache=number(raw,"cached_input_tokens");output=number(raw,"output_tokens");reasoning=number(raw,"reasoning_output_tokens")
        case .api:
            input=number(raw,"prompt_tokens");output=number(raw,"completion_tokens")
            let details=raw["prompt_tokens_details"] as? [String:Any] ?? [:]
            cache=number(details,"cached_tokens") ?? number(raw,"prompt_cache_hit_tokens")
            reasoning=number(raw["completion_tokens_details"] as? [String:Any] ?? [:],"reasoning_tokens")
        case .disabled:break
        }
        if let i=input,let c=cache,c>i{cache=nil}
        return TokenCounts(input:input,cached:cache,output:output,reasoning:reasoning)
    }
}
struct TokenRecord:Codable,Identifiable {
    var id:UUID
    var date:Date
    var backend:SpeechBackend
    var model:String
    var origin:String
    var seconds:Double
    var status:String
    var counts:TokenCounts
    var partial:Bool? = nil
}
final class TokenHistoryStore:ObservableObject {
    static let shared=TokenHistoryStore()
    @Published private(set) var records=[TokenRecord]()
    @Published private(set) var error:String?
    private let url:URL
    init(url:URL?=nil) {
        self.url=url ?? AppPaths.support.appendingPathComponent("token-history.json")
        if let data=try? Data(contentsOf:self.url),let decoded=try? JSONDecoder().decode([TokenRecord].self,from:data){records=Array(decoded.prefix(200))}
    }
    func append(_ record:TokenRecord){guard !records.contains(where:{$0.id==record.id}) else{return};records.insert(record,at:0);records=Array(records.prefix(200));persist()}
    func clear(){records=[];persist()}
    private func persist(){do{try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(records).write(to:url,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path);error=nil}catch{self.error="用量记录暂时无法保存。"}}
}
