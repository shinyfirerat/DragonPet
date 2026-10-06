import AppKit
let directory=URL(fileURLWithPath:CommandLine.arguments[1])
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels=size*scale
        let image=NSImage(size:NSSize(width:pixels,height:pixels))
        image.lockFocus()
        NSColor(calibratedRed:0.91,green:0.85,blue:0.97,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:0,y:0,width:pixels,height:pixels),xRadius:CGFloat(pixels)*0.22,yRadius:CGFloat(pixels)*0.22).fill()
        if let symbol=NSImage(systemSymbolName:"pawprint.fill",accessibilityDescription:nil) {
            NSColor(calibratedRed:0.44,green:0.30,blue:0.60,alpha:1).set()
            let inset=CGFloat(pixels)*0.22
            symbol.draw(in:NSRect(x:inset,y:inset,width:CGFloat(pixels)-2*inset,height:CGFloat(pixels)-2*inset))
        }
        image.unlockFocus()
        let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
        try bitmap.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent("icon_\(size)x\(size)"+(scale==2 ? "@2x":"")+".png"))
    }
}
