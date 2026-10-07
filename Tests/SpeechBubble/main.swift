import AppKit
let app=NSApplication.shared
let bubble=SpeechBubble();bubble.presentationEnabled=false
bubble.anchor={NSRect(x:10000,y:10000,width:100,height:100)}
bubble.begin();assert(abs(bubble.refreshInterval!-1/30)<0.00001)
bubble.say("本地测试正文")
assert(bubble.refreshInterval==0.1)
RunLoop.main.run(until:Date(timeIntervalSinceNow:0.25))
assert(bubble.refreshInterval==0.1)
bubble.say("第二句");assert(bubble.refreshInterval==0.1)
bubble.dismiss();assert(bubble.refreshInterval==nil && !bubble.panel.isVisible)
print("PASS: thinking 30Hz becomes speech 10Hz; replacing/dismissing cleans up timers")
