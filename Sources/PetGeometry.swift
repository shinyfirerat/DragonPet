import AppKit

enum PetGeometry {
    static func resizedFrame(_ current:NSRect,to size:NSSize,in screens:[NSRect])->NSRect {
        guard !screens.isEmpty else{return NSRect(origin:current.origin,size:size)}
        func overlap(_ screen:NSRect)->CGFloat {let intersection=screen.intersection(current);return intersection.isNull ? 0:intersection.width*intersection.height}
        let screen=screens.max{overlap($0)<overlap($1)}!
        let selected: NSRect
        if overlap(screen)>0 {selected=screen}
        else {selected=screens.min{hypot($0.midX-current.midX,$0.midY-current.midY)<hypot($1.midX-current.midX,$1.midY-current.midY)}!}
        let x=max(selected.minX,min(current.minX,selected.maxX-size.width))
        let y=max(selected.minY,min(current.minY,selected.maxY-size.height))
        return NSRect(x:x,y:y,width:size.width,height:size.height)
    }
}
