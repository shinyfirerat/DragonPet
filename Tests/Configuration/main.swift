import AppKit
let preferenceFile=AppPaths.testRoot!.appendingPathComponent("configuration-test.plist")
let defaults=PetPreferences(file:preferenceFile)
let fresh=ConfigurationStore(defaults:defaults)
assert(fresh.value.backend == .disabled && fresh.value.paused && fresh.value.quotaSources.isEmpty)
// Relaunch without saving after the appearance layer persists a size.
defaults.set(110,forKey:"petSize")
let secondLaunch=ConfigurationStore(defaults:PetPreferences(file:preferenceFile))
assert(secondLaunch.value.backend == .disabled && secondLaunch.value.paused && secondLaunch.value.quotaSources.isEmpty)
// A legacy appearance preference alone must not enable external sources.
defaults.removeObject(forKey:"petConfiguration")
let appearanceOnly=ConfigurationStore(defaults:defaults)
assert(appearanceOnly.value.backend == .disabled && appearanceOnly.value.quotaSources.isEmpty)
let damaged=Data("not-json".utf8);defaults.set(damaged,forKey:"petConfiguration")
let damagedStore=ConfigurationStore(defaults:defaults)
assert(damagedStore.value.backend == .disabled && damagedStore.value.paused && damagedStore.value.quotaSources.isEmpty)
assert(!damagedStore.diagnostic.isEmpty && defaults.data(forKey:"petConfiguration")==damaged)
var config=fresh.value
config.bubbleSource = .model;config.backend = .api;config.apiURL="https://api.example.com/v1";config.apiModel="example-model"
config.codexPath="/private/path/codex";config.dshPath="/private/path/dsh"
config.quotaSources=[QuotaSource(id:"codex",name:"自定义名字",enabled:true)]
try fresh.save(config)
let loaded=ConfigurationStore(defaults:defaults);assert(loaded.value.apiModel=="example-model")
let exported=config.exported();assert(exported.backend == .disabled && exported.apiURL.isEmpty && exported.codexPath.isEmpty && exported.dshPath.isEmpty)
let json=String(data:try JSONEncoder().encode(exported),encoding:.utf8)!
assert(!json.contains("private/path"));assert(!json.contains("apiKey"))
do {let result=try APIClient.endpoint("https://api.example.com/v1").path=="/v1/chat/completions";assert(result)}
let canonical=try APIClient.endpoint("https://api.example.com/v1")
for address in ["https://api.example.com/v1/","https://api.example.com/v1/chat/completions","https://api.example.com/v1/chat/completions/","https://api.example.com/v1/chat/completions///"] {
    let normalized=try APIClient.endpoint(address)
    assert(normalized==canonical) // Also preserves the canonical identity used by Keychain.
}
let rootEndpoint=try APIClient.endpoint("https://api.example.com/");assert(rootEndpoint.path=="/chat/completions")
for address in ["http://remote.example.com/v1","https://key:secret@example.com/v1","https://example.com/v1?key=secret","file:///tmp/a"] {
 do{_ = try APIClient.endpoint(address);fatalError("accepted unsafe endpoint") }catch{}
}
do {let result=try APIClient.endpoint("http://127.0.0.1:1234/v1").path=="/v1/chat/completions";assert(result)}
let reply=Data("{\"choices\":[{\"message\":{\"content\":\"小念头\"}}]}".utf8)
do {let result=try APIClient.response(reply,status:200)=="小念头";assert(result)}
for code in [401,402,429,500]{do{_ = try APIClient.response(reply,status:code);fatalError("bad status accepted")}catch{assert(!error.localizedDescription.contains("secret"))}}
let quota=Data("[{\"provider\":\"antigravity\",\"usage\":{\"extraRateWindows\":[{\"title\":\"Claude\",\"window\":{\"usedPercent\":25}},{\"title\":\"Gemini\",\"window\":{\"usedPercent\":10}}]}}]".utf8)
do {let result=try UsageParser.parse(quota,geminiOnly:false)[0].lines.count==2;assert(result)}
do {let result=try UsageParser.parse(quota,geminiOnly:true)[0].lines.count==1;assert(result)}
let missing=CompanionService(persona:"test",executable:URL(fileURLWithPath:"/nonexistent/dsh"),responseTimeout:1,patchURL:URL(fileURLWithPath:"Resources/Companion/dsh-lean.yml"))
missing.configuration={var c=PetConfiguration.defaults();c.bubbleSource = .model;c.backend = .dsh;c.paused=false;return c}
var failures=0;missing.onResult={text,error in assert(text==nil && error != nil);failures+=1}
assert(missing.speak());assert(!missing.busy);assert(failures==1)
let paused=CompanionService(persona:"test");paused.configuration={fresh.value};var pausedConfig=fresh.value;pausedConfig.paused=true;paused.configuration={pausedConfig};assert(!paused.speak())
print("PASS: fresh install offline; persistence; safe export; endpoint/status validation; Gemini filter; missing dependency; pause")

var off=PetConfiguration.defaults();off.bubbleSource = .model;off.backend = .dsh;off.paused=true
let noRequest=CompanionService(persona:"test",executable:URL(fileURLWithPath:"/nonexistent/should-not-launch"))
noRequest.configuration={off}
var callbacks=0
noRequest.onRecord={_ in callbacks+=1};noRequest.onResult={_,_ in callbacks+=1};noRequest.onUsage={_,_ in callbacks+=1}
for backend in [SpeechBackend.dsh,.codex,.api]{off.backend=backend;for _ in 0..<10{assert(!noRequest.speak())}}
assert(!noRequest.busy && callbacks==0)
print("PASS: bubbles off rejects thirty clicks across three backends before launch/API/history; zero generation callbacks")

var incompleteAPI=PetConfiguration.defaults();incompleteAPI.bubbleSource = .model;incompleteAPI.backend = .api
incompleteAPI.volume=0.6
try fresh.save(incompleteAPI)
assert(fresh.value.volume==0.6 && fresh.value.paused)
do{_ = try incompleteAPI.validated(forGeneration:true);fatalError("incomplete API accepted for generation")}catch{}
incompleteAPI.paused=false
do{_ = try incompleteAPI.validated();fatalError("incomplete enabled API accepted")}catch{}
incompleteAPI.apiURL="https://api.example.com/v1";incompleteAPI.apiModel="test-model"
_ = try incompleteAPI.validated(forGeneration:true)
print("PASS: disabled bubbles allow incomplete API settings; enabled bubbles and explicit test require valid connection")

let unconfigured=CompanionService(persona:"test");assert(!unconfigured.speak())
let encodedConfig=try JSONEncoder().encode(config)
let raw=try JSONSerialization.jsonObject(with:encodedConfig) as! [String:Any]
for key in raw.keys {
    var old=raw;old.removeValue(forKey:key)
    _ = try JSONDecoder().decode(PetConfiguration.self,from:JSONSerialization.data(withJSONObject:old))
}
var old=raw;old.removeValue(forKey:"bubbleSource")
let migrated=try JSONDecoder().decode(PetConfiguration.self,from:JSONSerialization.data(withJSONObject:old))
assert(migrated.bubbleSource == .model)
let local=CompanionService(persona:"unused",executable:URL(fileURLWithPath:"/must-not-run"))
var localConfig=PetConfiguration.defaults();localConfig.paused=false;localConfig.localLines="  第一行  \n\n第二行"
local.configuration={localConfig}
var localReplies=[String]();var localRecords=0
local.onResult={text,error in assert(error==nil);localReplies.append(text!)}
local.onRecord={_ in localRecords+=1};local.onUsage={_,_ in fatalError("local usage")}
for _ in 0..<20{assert(local.speak());assert(!local.busy)}
assert(localRecords==0 && localReplies.count==20 && Set(localReplies)==Set(["第一行","第二行"]))
assert(zip(localReplies,localReplies.dropFirst()).allSatisfy{$0 != $1})
print("PASS: missing-field compatibility, legacy model selection, fail-closed service, twenty local replies without model/history")

assert(Set(Mirror(reflecting:PetConfiguration()).children.compactMap{$0.label})==Set(raw.keys))
print("PASS: stored keys cover every configuration field")

let equivalent=try APIClient.endpoint("https://API.example.com:443/v1/");assert(equivalent==canonical)
