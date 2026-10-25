import Foundation
import SimplePJCore

enum HeadlessCLI {
    /// `SimplePJ --discover [cidr] [--format txt|csv|json|ip-port]`
    static func runDiscoverAndExit(arguments: [String]) -> Never {
        var range = ""
        var format: FleetExportFormat = .txt
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            if arg == "--format", i + 1 < arguments.count {
                format = FleetExportFormat(rawValue: arguments[i + 1].lowercased()) ?? .txt
                i += 2
            } else if !arg.hasPrefix("-") && range.isEmpty {
                range = arg
                i += 1
            } else {
                i += 1
            }
        }
        if range.isEmpty {
            range = NetworkInterface.scannableInterfaces().first?.cidr ?? "192.168.1.0/24"
        }
        let endpoints = IPv4Range.parseEndpoints(range)
        guard !endpoints.isEmpty else {
            fputs("SimplePJ error: invalid CIDR or range '\(range)'\n", stderr)
            exit(1)
        }
        let discovered = PJLinkDiscovery.scan(endpoints: endpoints)
        print(FleetExporter.render(discovered, format: format), terminator: "")
        exit(0)
    }

    /// `SimplePJ --cmd <ip[:port]> <shutter-close|shutter-open|on|off|status|freeze-on|freeze-off|input:31|raw:...>`
    static func runCommandAndExit(arguments: [String]) -> Never {
        guard arguments.count >= 2 else {
            fputs("Usage: SimplePJ --cmd <ip[:port]> <shutter-close|shutter-open|on|off|status|freeze-on|freeze-off|input:31|raw:%1POWR ?> [--password <pwd>]\n", stderr)
            exit(1)
        }
        let targetSpec = arguments[0]
        let actionSpec = arguments[1]
        var password = ""
        var i = 2
        while i < arguments.count {
            if arguments[i] == "--password", i + 1 < arguments.count {
                password = arguments[i + 1]
                i += 2
            } else {
                i += 1
            }
        }

        let endpoints = IPv4Range.parseEndpoints(targetSpec)
        guard !endpoints.isEmpty else {
            fputs("SimplePJ error: invalid target '\(targetSpec)'\n", stderr)
            exit(1)
        }

        let lowerAction = actionSpec.lowercased()
        for ep in endpoints {
            let pj = Projector(ip: ep.ip, port: ep.port, password: password)
            if lowerAction == "status" {
                let res = PJLinkClient.poll(pj, includeIdentity: true, includeClass2: true, timeout: 1.5)
                let p = res.updatedProjector
                print("\(p.endpointLabel)\t\(p.displayTitle)\tPower=\(p.power.label)\tShutter=\(p.shutter.label)\tInput=\(p.currentInputFullLabel)\tLamp=\(p.lampSummary)\tERST=\(p.errors.rawCode)")
                continue
            }

            let cmd: PJLinkCommand
            switch lowerAction {
            case "shutter-close", "blackout", "mute", "noir":
                cmd = .shutterClose
            case "shutter-open", "unmute", "open", "ouvert":
                cmd = .shutterOpen
            case "on", "power-on":
                cmd = .powerOn
            case "off", "power-off", "standby", "veille":
                cmd = .powerOff
            case "freeze-on", "freeze":
                cmd = .freeze(true)
            case "freeze-off", "unfreeze":
                cmd = .freeze(false)
            default:
                if lowerAction.hasPrefix("input:") {
                    cmd = .inputSelect(String(actionSpec.dropFirst("input:".count)))
                } else if lowerAction.hasPrefix("raw:") {
                    cmd = .raw(String(actionSpec.dropFirst("raw:".count)))
                } else {
                    cmd = .raw(actionSpec)
                }
            }

            do {
                let res = try PJLinkClient.execute(cmd, on: pj, timeout: 1.5)
                let replyStr = res.replies.first.map { "%\($0.pjlinkClass)\($0.command)=\($0.value)" } ?? "OK"
                print("\(ep.ip):\(ep.port)\t\(cmd.wireBody) -> \(replyStr) (\(String(format: "%.1f", res.latencyMs)) ms)")
            } catch {
                fputs("\(ep.ip):\(ep.port)\terror: \(error.localizedDescription)\n", stderr)
                exit(2)
            }
        }
        exit(0)
    }
}
