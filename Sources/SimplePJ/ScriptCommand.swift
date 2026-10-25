import AppKit
import Foundation
import SimplePJCore

/// AppleScript command handler compatible with SIGMASIX ProjectorManager (`ProjectorManager Suite` / `PJst`):
/// - `tell application "SimplePJ" to PowerOn 0` (0 = all projectors, 1..N = 1-based projector index)
/// - `tell application "SimplePJ" to PowerOff 0`
/// - `tell application "SimplePJ" to AvMute 0`
/// - `tell application "SimplePJ" to AvUnMute 0`
/// - `tell application "SimplePJ" to Inpt {31, 0}` (`{inputCode, projectorIndex}`)
@objc(SimplePJScriptCommand)
final class SimplePJScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let cmdName = commandDescription.commandName
        let param = directParameter
        return MainActor.assumeIsolated {
            Self.executeOnMain(cmdName: cmdName, param: param)
        }
    }

    @MainActor
    private static func executeOnMain(cmdName: String, param: Any?) -> String {
        guard let delegate = NSApp?.delegate as? AppDelegate else {
            return "ERR: SimplePJ non initialisé"
        }
        let fleet = delegate.model.fleet

        func resolveTargets(_ index: Int) -> [Projector] {
            if index <= 0 {
                return fleet.projectors
            }
            guard index >= 1, index <= fleet.projectors.count else {
                return []
            }
            return [fleet.projectors[index - 1]]
        }

        switch cmdName {
        case "PowerOn":
            let idx = (param as? Int) ?? (param as? NSNumber)?.intValue ?? 0
            let targets = resolveTargets(idx)
            fleet.setPower(on: true, on: targets)
            return "OK PowerOn (\(targets.count))"

        case "PowerOff":
            let idx = (param as? Int) ?? (param as? NSNumber)?.intValue ?? 0
            let targets = resolveTargets(idx)
            fleet.setPower(on: false, on: targets)
            return "OK PowerOff (\(targets.count))"

        case "AvMute":
            let idx = (param as? Int) ?? (param as? NSNumber)?.intValue ?? 0
            let targets = resolveTargets(idx)
            fleet.setShutter(closed: true, on: targets)
            return "OK AvMute (\(targets.count))"

        case "AvUnMute":
            let idx = (param as? Int) ?? (param as? NSNumber)?.intValue ?? 0
            let targets = resolveTargets(idx)
            fleet.setShutter(closed: false, on: targets)
            return "OK AvUnMute (\(targets.count))"

        case "Inpt":
            if let list = param as? [Any], list.count >= 2 {
                let rawInput = "\(list[0])"
                let idx = (list[1] as? Int) ?? (list[1] as? NSNumber)?.intValue ?? Int("\(list[1])") ?? 0
                let targets = resolveTargets(idx)
                fleet.setInput(rawInput, on: targets)
                return "OK Inpt \(rawInput) (\(targets.count))"
            }
            return "ERR: Inpt attend {codeEntrée, indexProjecteur}"

        default:
            return "ERR: Commande AppleScript inconnue \(cmdName)"
        }
    }
}
