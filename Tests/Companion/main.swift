import AppKit
let app=NSApplication.shared
let stub=URL(fileURLWithPath:CommandLine.arguments[1])
let service=CompanionService(persona:"测试",executable:stub,responseTimeout:0.3,patchURL:URL(fileURLWithPath:"Resources/Companion/dsh-lean.yml"))
service.configuration={var c=PetConfiguration.defaults();c.bubbleSource = .model;c.backend = .dsh;c.paused=false;return c}
var results=0
service.onResult={text,error in assert(text==nil);assert(error != nil);results+=1}
service.prepare();assert(service.speak());assert(!service.speak())
let start=Date()
while results==0 && Date().timeIntervalSince(start)<2 {RunLoop.main.run(until:Date(timeIntervalSinceNow:0.02))}
assert(results==1);assert(!service.busy)
assert(service.speak());service.shutdown()
RunLoop.main.run(until:Date(timeIntervalSinceNow:0.4))
assert(results==1);assert(!service.busy)
print("PASS: timeout clears busy, duplicate clicks rejected, retry accepted, shutdown suppresses late results")
