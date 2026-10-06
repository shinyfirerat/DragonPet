import AppKit
let service=CompanionService(persona:"测试",executable:URL(fileURLWithPath:CommandLine.arguments[1]),responseTimeout:2,patchURL:URL(fileURLWithPath:"Resources/Companion/dsh-lean.yml"))
service.configuration={var c=PetConfiguration.defaults();c.bubbleSource = .model;c.backend = .dsh;c.paused=false;return c}
let clickedAt=ProcessInfo.processInfo.systemUptime
var results=[String]()
service.onResult={text,error in
    assert(error==nil);results.append(text!)
    if results.count==1 {
        // These two clicks happened during the first wait, but were delivered after its completion.
        assert(!service.speak(clickedAt:clickedAt));assert(!service.speak(clickedAt:clickedAt+0.01))
        assert(service.speak()) // An actual new click after completion remains allowed.
    }
}
service.prepare();assert(service.speak(clickedAt:clickedAt));assert(!service.speak());assert(!service.speak())
let start=Date()
while results.count<2 && Date().timeIntervalSince(start)<4 {RunLoop.main.run(until:Date(timeIntervalSinceNow:0.02))}
RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3))
assert(results==["正文1","正文2"]);assert(!service.busy);service.shutdown()
print("PASS: triple-click single request; delayed waiting-clicks discarded; one final per completed process; fresh click returns once")
