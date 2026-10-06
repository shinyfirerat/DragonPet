import Foundation

/// Explicit file-backed isolation; UserDefaults/cfprefsd is never used in test mode.
enum AppPaths {
    static var testRoot:URL? {ProcessInfo.processInfo.environment["DRAGONPET_TEST_ROOT"].map{URL(fileURLWithPath:$0,isDirectory:true)}}
    static var support:URL {testRoot?.appendingPathComponent("runtime") ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("DragonPet")}
}
final class PetPreferences {
    static let shared=PetPreferences(file:AppPaths.testRoot?.appendingPathComponent("preferences.plist"))
    private let file:URL?
    private var values=[String:Any]()
    init(file:URL?=nil){
        self.file=file
        if let file,let data=try? Data(contentsOf:file),let object=try? PropertyListSerialization.propertyList(from:data,format:nil),let map=object as? [String:Any]{values=map}
    }
    func object(forKey key:String)->Any? {file == nil ? UserDefaults.standard.object(forKey:key):values[key]}
    func data(forKey key:String)->Data? {object(forKey:key) as? Data}
    func string(forKey key:String)->String? {object(forKey:key) as? String}
    func integer(forKey key:String)->Int {(object(forKey:key) as? NSNumber)?.intValue ?? 0}
    func double(forKey key:String)->Double {(object(forKey:key) as? NSNumber)?.doubleValue ?? 0}
    func bool(forKey key:String)->Bool {(object(forKey:key) as? NSNumber)?.boolValue ?? false}
    func set(_ value:Any?,forKey key:String){
        guard let file else{UserDefaults.standard.set(value,forKey:key);return}
        values[key]=value
        do {
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try PropertyListSerialization.data(fromPropertyList:values,format:.binary,options:0).write(to:file,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        }catch{preconditionFailure("Cannot write isolated test preferences")}
    }
    func removeObject(forKey key:String){set(nil,forKey:key)}
}
