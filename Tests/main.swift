import AppKit
let codex=try UsageParser.parse(Data("""
[{"provider":"codex","usage":{"primary":{"usedPercent":25,"windowMinutes":300},"secondary":{"usedPercent":100,"windowMinutes":10080},"updatedAt":"2026-10-06T00:00:00Z"}}]
""".utf8))
assert(codex[0].lines[0].contains("75.0%"));assert(codex[0].lines[1].contains("0.0%"))
let deep=try UsageParser.parse(Data("""
[{"provider":"deepseek","usage":{"primary":{"usedPercent":0,"resetDescription":"¥7.08"}}}]
""".utf8))
assert(deep[0].lines==["余额：¥7.08"])
let missing=try UsageParser.parse(Data("""
[{"provider":"codex","usage":{"primary":{}}},{"provider":"deepseek","error":{"message":"offline"}}]
""".utf8))
assert(missing[0].lines==["额度：额度未知"]);assert(!missing[1].lines.joined().contains("0%"))
let skin=try PetSkin.load(URL(fileURLWithPath:CommandLine.arguments[1]));assert(skin.image.size.width>0)
for name in [skin.manifest.pressSound,skin.manifest.releaseSound]{assert(skin.asset(name).flatMap{NSSound(contentsOf:$0,byReference:false)} != nil)}
print("PASS: quota percentages, unknown/error, currency preservation, resource manifest, PNG and two audio files")
let audio=PetAudio();audio.load(skin);audio.muted=true
let pet=PetView(skin:skin)
var taps=0;pet.onTap={_ in taps+=1}
var events=[Bool]();pet.onPress={events.append($0)}
let down=NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1)!
let up=NSEvent.mouseEvent(with:.leftMouseUp,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:2,clickCount:1,pressure:0)!
pet.mouseDown(with:down);pet.mouseUp(with:up);assert(events==[true,false]);assert(taps==1)
assert(skin.asset("../outside.png")==nil)
for name in [skin.manifest.pressSound,skin.manifest.releaseSound]{let sound=NSSound(contentsOf:skin.asset(name)!,byReference:false)!;sound.volume=0.1;assert(sound.play());sound.stop()}
print("PASS: press/release event routing, skin directory boundary, native audio playback accepted")

let window=PetPanel(contentRect:NSRect(x:100,y:100,width:180,height:120),styleMask:[.borderless],backing:.buffered,defer:false)
window.contentView=pet
var point=NSPoint(x:100,y:100);pet.pointerPosition={point}
pet.mouseDown(with:down)
point=NSPoint(x:140,y:125)
pet.mouseDragged(with:down)
assert(window.frame.origin==NSPoint(x:140,y:125))
pet.mouseUp(with:up)
assert(taps==1);assert(events==[true,false,true,false])
print("PASS: dragging moves window by pointer delta without resize or phrase request")

let fixture=try UsageParser.parse(Data(contentsOf:URL(fileURLWithPath:"Tests/Fixtures/quotas.json")))
assert(fixture.count==3 && fixture[0].lines.contains(where:{$0.contains("75.0%")}))
assert(fixture[0].lines.contains(where:{$0.contains("额度未知")}))
assert(fixture[1].lines.contains(where:{$0.contains("3.50")}))
assert(fixture[2].lines.count==1 && fixture[2].lines[0].contains("Gemini"))
print("PASS: synthetic CodexBar schema fixtures")

let stableOrigin=window.frame.origin
pet.beginThinking();assert(pet.isMoodAnimating)
pet.resetMood();assert(!pet.isMoodAnimating)
RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1))
assert(window.frame.origin==stableOrigin && !pet.isMoodAnimating)
pet.endThinking();assert(pet.isMoodAnimating) // Actual reply arrival may still bounce.
pet.resetMood();assert(!pet.isMoodAnimating)
print("PASS: cancellation/reset does not bounce or move the pet; actual reply animation remains available")

assert(UsageParser.date("2026-01-01T00:00:00.930Z")==UsageParser.date("2026-01-01T00:00:00Z"))
assert(UsageParser.date("2026-01-01T08:00:00.930+08:00")==UsageParser.date("2026-01-01T00:00:00Z"))
assert(UsageParser.date("invalid-date")=="invalid-date")
let screen=NSRect(x:0,y:30,width:1000,height:700)
let edge=PetGeometry.resizedFrame(NSRect(x:900,y:30,width:100,height:100),to:NSSize(width:250,height:180),in:[screen])
assert(screen.contains(edge) && edge.minX==750 && edge.minY==30)
let left=NSRect(x:-1000,y:0,width:1000,height:700)
let onLeft=PetGeometry.resizedFrame(NSRect(x:-100,y:10,width:90,height:80),to:NSSize(width:250,height:120),in:[left,screen])
assert(left.contains(onLeft))
let unchanged=PetGeometry.resizedFrame(NSRect(x:200,y:100,width:100,height:100),to:NSSize(width:150,height:150),in:[screen]);assert(unchanged.origin==NSPoint(x:200,y:100))
do{_ = try APIKeyStore.deletionEndpoint("");fatalError("empty key endpoint accepted")}catch{assert(error.localizedDescription.contains("没有可删除"))}
let savedEndpoint=try APIKeyStore.deletionEndpoint("https://api.example.com/v1");assert(savedEndpoint=="https://api.example.com/v1")
print("PASS: fractional timestamps, invalid-date fallback, resize edge/multi-screen clamping, empty saved-key guidance")
