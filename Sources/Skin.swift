import AppKit
struct SkinManifest: Codable {
    var name: String
    var portrait: String
    var pressSound: String?
    var releaseSound: String?
    var defaultHeight: Double
    var pressScaleX: Double
    var pressScaleY: Double
}
struct PetSkin {
    let directory: URL
    let manifest: SkinManifest
    let image: NSImage
    func asset(_ name: String?) -> URL? {
        guard let name, !name.contains("/"), !name.contains("..") else { return nil }
        return directory.appendingPathComponent(name)
    }
    static func load(_ directory: URL) throws -> PetSkin {
        let m:SkinManifest
        do {m=try JSONDecoder().decode(SkinManifest.self,from:Data(contentsOf:directory.appendingPathComponent("skin.json")))}
        catch {throw ConfigError.message("无法读取 skin.json，请检查文件和 JSON 格式。") }
        guard !m.portrait.contains("/"), !m.portrait.contains(".."),
              (60...260).contains(m.defaultHeight), (0.8...1.3).contains(m.pressScaleX), (0.5...1).contains(m.pressScaleY),
              let image = NSImage(contentsOf: directory.appendingPathComponent(m.portrait)), image.size.height > 0 else {
            throw NSError(domain: "Skin", code: 1, userInfo: [NSLocalizedDescriptionKey:"形象配置或立绘无效"])
        }
        return PetSkin(directory: directory, manifest: m, image: image)
    }
}
final class PetAudio {
    var muted = PetPreferences.shared.bool(forKey: "muted")
    var volume:Float=0.35 {didSet{press?.volume=volume;release?.volume=volume}}
    private var press: NSSound?
    private var release: NSSound?
    func load(_ skin: PetSkin) {
        press = skin.asset(skin.manifest.pressSound).flatMap { NSSound(contentsOf: $0, byReference: false) }
        release = skin.asset(skin.manifest.releaseSound).flatMap { NSSound(contentsOf: $0, byReference: false) }
        press?.volume = volume; release?.volume = volume
    }
    func play(down: Bool) { guard !muted else { return }; let sound = down ? press : release; sound?.stop(); sound?.play() }
}
