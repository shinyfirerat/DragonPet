import Foundation

/// No redirects: an Authorization header must never follow a server to another host.
final class APIClient:NSObject,URLSessionTaskDelegate {
    var onUsage:(([String:Any])->Void)?
    private var session:URLSession?
    private var task:URLSessionDataTask?
    static func endpoint(_ text:String)throws->URL {
        guard var components=URLComponents(string:text.trimmingCharacters(in:.whitespacesAndNewlines)),let host=components.host,!host.isEmpty,components.user==nil,components.password==nil,components.query==nil,components.fragment==nil,components.scheme=="https" || (components.scheme=="http" && ["localhost","127.0.0.1","::1"].contains(host)) else{throw ConfigError.message("地址须为 HTTPS；本机 localhost 可使用 HTTP。地址中不要放密钥或参数。")}
        components.host=host.lowercased()
        if (components.scheme=="https" && components.port==443) || (components.scheme=="http" && components.port==80){components.port=nil}
        // Normalize trailing slashes before deciding whether this is a full endpoint.
        while components.path.hasSuffix("/"){components.path.removeLast()}
        if !components.path.hasSuffix("/chat/completions"){components.path += "/chat/completions"}
        guard let url=components.url else{throw ConfigError.message("API 地址无效。")};return url
    }
    static func response(_ data:Data,status:Int)throws->String {
        guard (200...299).contains(status) else{throw ConfigError.message(status==401 || status==403 ? "API 认证失败，请检查 Key 和权限。":status==402 ? "API 余额不足。":status==429 ? "API 请求受限或额度不足，请稍后重试。":"API 服务返回 HTTP \(status)，请检查设置或稍后重试。")}
        guard let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let choices=object["choices"] as? [[String:Any]],let message=choices.first?["message"] as? [String:Any],let text=message["content"] as? String,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ConfigError.message("API 返回格式不兼容，需支持 Chat Completions 的文本回复。")}
        return text
    }
    func request(config:PetConfiguration,persona:String,key:String?,completion:@escaping(String?,String?)->Void)throws {
        let url=try Self.endpoint(config.apiURL)
        var request=URLRequest(url:url);request.httpMethod="POST";request.timeoutInterval=35
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let key,!key.isEmpty{request.setValue("Bearer "+key,forHTTPHeaderField:"Authorization")}
        var body:[String:Any]=["model":config.apiModel,"messages":[["role":"system","content":persona],["role":"user","content":"随口说一句话。"]],"stream":false]
        if !config.apiTokenParameter.isEmpty{body[config.apiTokenParameter]=512}
        if !config.apiEffort.isEmpty{body["reasoning_effort"]=config.apiEffort}
        request.httpBody=try JSONSerialization.data(withJSONObject:body)
        let options=URLSessionConfiguration.ephemeral;options.timeoutIntervalForResource=35;options.httpCookieStorage=nil;options.urlCache=nil
        session=URLSession(configuration:options,delegate:self,delegateQueue:nil)
        task=session!.dataTask(with:request){data,response,error in
            let result:String?,failure:String?
            if let error {result=nil;failure=(error as NSError).code==NSURLErrorTimedOut ? "请求超时了，再戳一下？":"API 网络连接失败，请检查地址与网络。"}
            else {do{result=try Self.response(data ?? Data(),status:(response as? HTTPURLResponse)?.statusCode ?? 0);failure=nil}catch{result=nil;failure=error.localizedDescription}}
            let usage=data.flatMap{try? JSONSerialization.jsonObject(with:$0)}.flatMap{$0 as? [String:Any]}?["usage"] as? [String:Any]
            DispatchQueue.main.async{if let usage{self.onUsage?(usage)};completion(result,failure)}
        };task?.resume()
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
    func cancel(){task?.cancel();task=nil;session?.invalidateAndCancel();session=nil}
}
