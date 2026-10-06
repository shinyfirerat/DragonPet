import AppKit
import Darwin
let stub=URL(fileURLWithPath:CommandLine.arguments[1])
func run(_ backend:SpeechBackend,_ model:String,_ cancel:Bool=false)->TokenRecord {
    var config=PetConfiguration.defaults();config.bubbleSource = .model;config.backend=backend;config.paused=false;config.dshModel=model
    let service=CompanionService(persona:"test",executable:stub,responseTimeout:2,patchURL:URL(fileURLWithPath:backend == .codex ? "/nonexistent/unrelated-dsh-template":"Resources/Companion/dsh-lean.yml"))
    service.configuration={config}
    var record:TokenRecord?
    service.onRecord={record=$0}
    assert(service.speak())
    if cancel{DispatchQueue.main.asyncAfter(deadline:.now()+0.3){service.shutdown()}}
    let end=Date(timeIntervalSinceNow:3)
    while record==nil && Date()<end{RunLoop.main.run(until:Date(timeIntervalSinceNow:0.02))}
    assert(record != nil);service.shutdown();return record!
}
let completed=run(.dsh,"aggregate-test")
assert(completed.status=="成功" && completed.counts.input==150 && completed.counts.output==15 && completed.counts.total==165)
let partial=run(.dsh,"partial-test",true)
assert(partial.status=="取消" && partial.partial==true && partial.counts.input==100)
let codex=run(.codex,"unused")
assert(codex.status=="成功" && codex.counts.total==165)
print("PASS: DSH step dedup/final override/late step; cancellation partial; unique private patch; Codex independent of DSH template")

let base=AppPaths.support.appendingPathComponent("CompanionWorkspace")
let ended=Process();ended.executableURL=URL(fileURLWithPath:"/usr/bin/true");try ended.run();ended.waitUntilExit()
let stale=base.appendingPathComponent("run-"+String(ended.processIdentifier))
try FileManager.default.createDirectory(at:stale,withIntermediateDirectories:true)
try Data("private test".utf8).write(to:stale.appendingPathComponent("dragonpet-lean-test.yml"))
let current=base.appendingPathComponent("run-"+String(getpid()))
try FileManager.default.createDirectory(at:current,withIntermediateDirectories:true)
let keep=current.appendingPathComponent("active-test.yml");try Data("active".utf8).write(to:keep)
let cleaner=CompanionService(persona:"unused");assert(cleaner.prepare())
assert(!FileManager.default.fileExists(atPath:stale.path) && FileManager.default.fileExists(atPath:keep.path))
try FileManager.default.removeItem(at:keep)
print("PASS: dead owner workspace removed; live owner workspace preserved")
