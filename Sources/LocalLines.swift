import Foundation
/// Pure local selection: no process, API, history or keychain access.
final class LocalLines {
    private var previous:String?
    static func lines(_ text:String)->[String] {text.components(separatedBy:.newlines).map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}}
    func next(_ text:String)->String? {
        let lines=Self.lines(text);let choices=lines.count>1 ? lines.filter{$0 != previous}:lines
        let result=(choices.isEmpty ? lines:choices).randomElement();previous=result;return result
    }
}
