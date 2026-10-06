import AppKit
let port=CommandLine.arguments[1]
let client=APIClient()
for path in ["v1","completion","no-limit","unauthorized","limited","redirect"] {
    var config=PetConfiguration.defaults();config.bubbleSource = .model;config.backend = .api;config.apiModel="test-model";config.apiURL="http://127.0.0.1:\(port)/\(path)"
    config.apiTokenParameter=path=="completion" ? "max_completion_tokens":path=="no-limit" ? "":"max_tokens"
    var done=false
    try client.request(config:config,persona:"仅一句。",key:"synthetic-test-only"){text,error in
        if ["v1","completion","no-limit"].contains(path){assert(text=="这是本机模拟回复。" && error==nil)}else{assert(text==nil && error != nil);assert(!error!.contains("synthetic-test-only"))}
        done=true
    }
    let deadline=Date(timeIntervalSinceNow:5)
    while !done && Date()<deadline{RunLoop.main.run(until:Date(timeIntervalSinceNow:0.02))}
    assert(done);client.cancel()
}
print("PASS: real local HTTP request, Bearer/body schema, 401/429, redirect denied, safe errors")
