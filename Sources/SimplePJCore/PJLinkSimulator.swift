import Darwin
import Foundation

/// Configuration and mutable state of a simulated PJLink Class 1/2 projector on loopback TCP.
public final class PJLinkSimulatedServer: @unchecked Sendable {
    public struct Config: Sendable {
        public var name: String
        public var manufacturer: String
        public var modelName: String
        public var extraInfo: String
        public var pjlinkClass: Int
        public var serialNumber: String
        public var firmwareVersion: String
        public var nativeResolution: String
        public var inputResolution: String
        public var replacementLamp: String
        public var replacementFilter: String
        public var password: String
        public var initialPower: PJLinkPowerState
        public var initialShutter: PJLinkShutterState
        public var initialInput: String
        public var inputs: [PJLinkInput]
        public var lamps: [PJLinkLamp]
        public var filterHours: Int
        public var errors: PJLinkErrorStatus
        public var transitionDuration: TimeInterval
        public var closeAfterEachCommand: Bool

        public init(
            name: String = "VP-COUR",
            manufacturer: String = "Panasonic",
            modelName: String = "PT-RZ990",
            extraInfo: String = "Laser 1-Chip DLP 9400lm",
            pjlinkClass: Int = 2,
            serialNumber: String = "SW2640918",
            firmwareVersion: String = "2.14.0",
            nativeResolution: String = "1920x1200",
            inputResolution: String = "1920x1080",
            replacementLamp: String = "LASER-SOLID-STATE",
            replacementFilter: String = "ET-RFV500",
            password: String = "",
            initialPower: PJLinkPowerState = .on,
            initialShutter: PJLinkShutterState = .open,
            initialInput: String = "31",
            inputs: [PJLinkInput] = [
                PJLinkInput(code: "31", customName: "HDMI 1"),
                PJLinkInput(code: "32", customName: "HDMI 2"),
                PJLinkInput(code: "33", customName: "SDI IN"),
                PJLinkInput(code: "52", customName: "DIGITAL LINK"),
            ],
            lamps: [PJLinkLamp] = [PJLinkLamp(index: 1, hours: 1420, isOn: true)],
            filterHours: Int = 340,
            errors: PJLinkErrorStatus = PJLinkErrorStatus(),
            transitionDuration: TimeInterval = 0.05,
            closeAfterEachCommand: Bool = false
        ) {
            self.name = name
            self.manufacturer = manufacturer
            self.modelName = modelName
            self.extraInfo = extraInfo
            self.pjlinkClass = pjlinkClass
            self.serialNumber = serialNumber
            self.firmwareVersion = firmwareVersion
            self.nativeResolution = nativeResolution
            self.inputResolution = inputResolution
            self.replacementLamp = replacementLamp
            self.replacementFilter = replacementFilter
            self.password = password
            self.initialPower = initialPower
            self.initialShutter = initialShutter
            self.initialInput = initialInput
            self.inputs = inputs
            self.lamps = lamps
            self.filterHours = filterHours
            self.errors = errors
            self.transitionDuration = transitionDuration
            self.closeAfterEachCommand = closeAfterEachCommand
        }
    }

    private let lock = NSLock()
    public let config: Config
    public private(set) var port: UInt16 = 0
    private var listenFD: Int32 = -1
    private var running = false

    private var powerState: PJLinkPowerState
    private var shutterState: PJLinkShutterState
    private var currentInput: String
    private var freezeState: Bool = false
    private var errorStatus: PJLinkErrorStatus
    private var lampList: [PJLinkLamp]
    private var filterHours: Int
    private var pjlinkName: String

    public init(config: Config = Config()) {
        self.config = config
        self.powerState = config.initialPower
        self.shutterState = config.initialShutter
        self.currentInput = config.initialInput
        self.errorStatus = config.errors
        self.lampList = config.lamps
        self.filterHours = config.filterHours
        self.pjlinkName = config.name
    }

    deinit {
        stop()
    }

    public func start(preferredPort: UInt16 = 0) throws -> UInt16 {
        lock.lock()
        if running {
            let p = port
            lock.unlock()
            return p
        }
        lock.unlock()

        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw PJLinkClientError.networkFailure("simulator socket() failed")
        }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = preferredPort.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindRes < 0 {
            Darwin.close(fd)
            throw PJLinkClientError.networkFailure("simulator bind() failed errno \(errno)")
        }

        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(fd, $0, &len)
            }
        }
        let assignedPort = UInt16(bigEndian: boundAddr.sin_port)

        guard Darwin.listen(fd, 32) == 0 else {
            Darwin.close(fd)
            throw PJLinkClientError.networkFailure("simulator listen() failed")
        }

        lock.lock()
        self.listenFD = fd
        self.port = assignedPort
        self.running = true
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop(fd: fd)
        }
        return assignedPort
    }

    public func stop() {
        lock.lock()
        running = false
        let fd = listenFD
        listenFD = -1
        lock.unlock()
        if fd >= 0 {
            Darwin.shutdown(fd, SHUT_RDWR)
            Darwin.close(fd)
        }
    }

    public func setSimulatedErrors(_ errors: PJLinkErrorStatus) {
        lock.lock()
        self.errorStatus = errors
        lock.unlock()
    }

    private func acceptLoop(fd: Int32) {
        while true {
            lock.lock()
            let active = running
            lock.unlock()
            if !active { break }

            var clientAddr = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(fd, $0, &len)
                }
            }
            if clientFD < 0 {
                if errno == EINTR { continue }
                break
            }
            var one: Int32 = 1
            setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(clientFD, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { Darwin.close(fd) }

        let challenge = "498e4a67"
        let needsAuth = !config.password.isEmpty
        let greeting = needsAuth ? "PJLINK 1 \(challenge)\r" : "PJLINK 0\r"
        guard sendRaw(fd: fd, text: greeting) else { return }

        var authenticated = !needsAuth
        var commandCount = 0

        while let line = readCommandLine(fd: fd) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            var cmdText = trimmed
            if !authenticated {
                let expectedHash = PJLinkAuth.md5Digest(challenge: challenge, password: config.password)
                guard cmdText.lowercased().hasPrefix(expectedHash.lowercased()) else {
                    _ = sendRaw(fd: fd, text: "PJLINK ERRA\r")
                    return
                }
                cmdText = String(cmdText.dropFirst(expectedHash.count))
                authenticated = true
            } else if let pctIndex = cmdText.firstIndex(of: "%"), pctIndex != cmdText.startIndex {
                // Client included an MD5 hash even though auth was not required or already done
                cmdText = String(cmdText[pctIndex...])
            }

            let response = processCommand(cmdText)
            guard sendRaw(fd: fd, text: response + "\r") else { return }
            commandCount += 1
            if config.closeAfterEachCommand && commandCount >= 1 {
                return
            }
        }
    }

    private func processCommand(_ raw: String) -> String {
        guard raw.hasPrefix("%"), raw.count >= 6 else {
            return "%1ERR1=ERR1"
        }
        let classChar = raw[raw.index(after: raw.startIndex)]
        let cmdStart = raw.index(raw.startIndex, offsetBy: 2)
        let cmdEnd = raw.index(cmdStart, offsetBy: 4, limitedBy: raw.endIndex) ?? raw.endIndex
        let cmd = String(raw[cmdStart..<cmdEnd]).uppercased()
        let param = raw.count > 6 ? String(raw[cmdEnd...]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let prefix = "%\(classChar)\(cmd)="

        lock.lock()
        defer { lock.unlock() }

        switch cmd {
        case "POWR":
            if param == "?" { return "\(prefix)\(powerState.rawValue)" }
            if param == "1" {
                if powerState == .standby || powerState == .unknown {
                    if config.transitionDuration > 0 {
                        powerState = .warming
                        let delay = config.transitionDuration
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                            guard let self else { return }
                            self.lock.lock()
                            if self.powerState == .warming {
                                self.powerState = .on
                                for i in self.lampList.indices { self.lampList[i].isOn = true }
                            }
                            self.lock.unlock()
                        }
                    } else {
                        powerState = .on
                        for i in lampList.indices { lampList[i].isOn = true }
                    }
                }
                return "\(prefix)OK"
            }
            if param == "0" {
                if powerState == .on || powerState == .warming {
                    if config.transitionDuration > 0 {
                        powerState = .cooling
                        let delay = config.transitionDuration
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                            guard let self else { return }
                            self.lock.lock()
                            if self.powerState == .cooling {
                                self.powerState = .standby
                                for i in self.lampList.indices { self.lampList[i].isOn = false }
                            }
                            self.lock.unlock()
                        }
                    } else {
                        powerState = .standby
                        for i in lampList.indices { lampList[i].isOn = false }
                    }
                }
                return "\(prefix)OK"
            }
            return "\(prefix)ERR2"

        case "AVMT":
            if param == "?" { return "\(prefix)\(shutterState.rawValue)" }
            switch param {
            case "11": shutterState = .videoMuted; return "\(prefix)OK"
            case "21": shutterState = .audioMuted; return "\(prefix)OK"
            case "31": shutterState = .videoAndAudioMuted; return "\(prefix)OK"
            case "10", "20", "30": shutterState = .open; return "\(prefix)OK"
            default: return "\(prefix)ERR2"
            }

        case "INPT":
            if param == "?" { return "\(prefix)\(currentInput)" }
            if config.inputs.contains(where: { $0.code == param }) {
                currentInput = param
                return "\(prefix)OK"
            }
            return "\(prefix)ERR2"

        case "INST":
            if param == "?" {
                return "\(prefix)\(config.inputs.map(\.code).joined(separator: " "))"
            }
            return "\(prefix)ERR2"

        case "ERST":
            if param == "?" { return "\(prefix)\(errorStatus.rawCode)" }
            return "\(prefix)ERR2"

        case "LAMP":
            if param == "?" {
                let isLit = (powerState == .on || powerState == .warming)
                let str = lampList.map { "\($0.hours) \(isLit ? 1 : 0)" }.joined(separator: " ")
                return "\(prefix)\(str)"
            }
            return "\(prefix)ERR2"

        case "NAME":
            if param == "?" { return "\(prefix)\(pjlinkName)" }
            return "\(prefix)ERR2"

        case "INF1":
            if param == "?" { return "\(prefix)\(config.manufacturer)" }
            return "\(prefix)ERR2"

        case "INF2":
            if param == "?" { return "\(prefix)\(config.modelName)" }
            return "\(prefix)ERR2"

        case "INFO":
            if param == "?" { return "\(prefix)\(config.extraInfo)" }
            return "\(prefix)ERR2"

        case "CLSS":
            if param == "?" { return "\(prefix)\(config.pjlinkClass)" }
            return "\(prefix)ERR2"

        // Class 2 commands
        case "SNUM":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(config.serialNumber)" : "\(prefix)ERR2"

        case "SVER":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(config.firmwareVersion)" : "\(prefix)ERR2"

        case "INNM":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            let code = param.hasPrefix("?") ? String(param.dropFirst()) : param
            if let found = config.inputs.first(where: { $0.code == code }) {
                return "\(prefix)\(found.displayName)"
            }
            return "\(prefix)ERR2"

        case "IRES":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(powerState == .on ? config.inputResolution : "0")" : "\(prefix)ERR2"

        case "RRES":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(config.nativeResolution)" : "\(prefix)ERR2"

        case "FILT":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(filterHours)" : "\(prefix)ERR2"

        case "RLMP":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(config.replacementLamp)" : "\(prefix)ERR2"

        case "RFIL":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            return param == "?" ? "\(prefix)\(config.replacementFilter)" : "\(prefix)ERR2"

        case "FREZ":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            if param == "?" { return "\(prefix)\(freezeState ? "1" : "0")" }
            if param == "1" { freezeState = true; return "\(prefix)OK" }
            if param == "0" { freezeState = false; return "\(prefix)OK" }
            return "\(prefix)ERR2"

        case "SVOL", "MVOL":
            guard config.pjlinkClass >= 2 else { return "\(prefix)ERR1" }
            if param == "0" || param == "1" { return "\(prefix)OK" }
            return "\(prefix)ERR2"

        default:
            return "\(prefix)ERR1"
        }
    }

    private func sendRaw(fd: Int32, text: String) -> Bool {
        let bytes = Array(text.utf8)
        let n = bytes.withUnsafeBytes { ptr in
            Darwin.send(fd, ptr.baseAddress!, bytes.count, 0)
        }
        return n == bytes.count
    }

    private func readCommandLine(fd: Int32) -> String? {
        var buf: [UInt8] = []
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        while true {
            let ready = Darwin.poll(&pfd, 1, 5000)
            if ready <= 0 { return buf.isEmpty ? nil : String(decoding: buf, as: UTF8.self) }
            var b: UInt8 = 0
            let n = Darwin.recv(fd, &b, 1, 0)
            if n <= 0 { return buf.isEmpty ? nil : String(decoding: buf, as: UTF8.self) }
            if b == 0x0D || b == 0x0A {
                if !buf.isEmpty { return String(decoding: buf, as: UTF8.self) }
                continue
            }
            buf.append(b)
            if buf.count >= 512 { return String(decoding: buf, as: UTF8.self) }
        }
    }
}

/// Manages a complete 4-projector simulated stage rig on `127.0.0.1` for rehearsals and live testing.
public final class PJLinkDemoRig: @unchecked Sendable {
    private let lock = NSLock()
    private var servers: [PJLinkSimulatedServer] = []

    public init() {}

    deinit {
        stopAll()
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !servers.isEmpty
    }

    public func startStageRig(transitionDuration: TimeInterval = 0.6) throws -> [Projector] {
        stopAll()

        let presets: [(label: String, mac: String, notes: String, config: PJLinkSimulatedServer.Config)] = [
            (
                label: "Face Cour #face #cour",
                mac: "70:B3:D5:8A:10:01",
                notes: "Pont de face cour · Optique 0.8–1.0:1 · Patch HDMI 1 = Mac Studio",
                config: PJLinkSimulatedServer.Config(
                    name: "VP-FACE-COUR",
                    manufacturer: "Panasonic",
                    modelName: "PT-RZ990",
                    extraInfo: "1-Chip DLP Laser 9400lm",
                    pjlinkClass: 2,
                    serialNumber: "SW2640911",
                    firmwareVersion: "2.14.0",
                    nativeResolution: "1920x1200",
                    inputResolution: "1920x1080",
                    initialPower: .on,
                    initialShutter: .open,
                    initialInput: "31",
                    lamps: [PJLinkLamp(index: 1, hours: 1420, isOn: true)],
                    filterHours: 310,
                    transitionDuration: transitionDuration
                )
            ),
            (
                label: "Face Jardin #face #jardin",
                mac: "70:B3:D5:8A:10:02",
                notes: "Pont de face jardin · Optique 0.8–1.0:1 · Patch HDMI 1 = Mac Studio",
                config: PJLinkSimulatedServer.Config(
                    name: "VP-FACE-JARDIN",
                    manufacturer: "Panasonic",
                    modelName: "PT-RZ990",
                    extraInfo: "1-Chip DLP Laser 9400lm",
                    pjlinkClass: 2,
                    serialNumber: "SW2640912",
                    firmwareVersion: "2.14.0",
                    nativeResolution: "1920x1200",
                    inputResolution: "1920x1080",
                    initialPower: .on,
                    initialShutter: .open,
                    initialInput: "31",
                    lamps: [PJLinkLamp(index: 1, hours: 1385, isOn: true)],
                    filterHours: 295,
                    transitionDuration: transitionDuration
                )
            ),
            (
                label: "Cyclo Lointain #cyclo #fond",
                mac: "AC:1F:6B:44:22:03",
                notes: "Ultra-courte focale ELPLX02S · Volet fermé pendant l'entrée public",
                config: PJLinkSimulatedServer.Config(
                    name: "VP-CYCLO-HAUT",
                    manufacturer: "EPSON",
                    modelName: "EB-PU2010B",
                    extraInfo: "3LCD Laser 10000lm",
                    pjlinkClass: 2,
                    serialNumber: "X9JW41082",
                    firmwareVersion: "1.08",
                    nativeResolution: "1920x1200",
                    inputResolution: "1920x1200",
                    initialPower: .on,
                    initialShutter: .videoAndAudioMuted,
                    initialInput: "52",
                    inputs: [
                        PJLinkInput(code: "31", customName: "HDMI"),
                        PJLinkInput(code: "32", customName: "DVI-D"),
                        PJLinkInput(code: "34", customName: "SDI"),
                        PJLinkInput(code: "52", customName: "HDBaseT"),
                    ],
                    lamps: [PJLinkLamp(index: 1, hours: 860, isOn: true)],
                    filterHours: 860,
                    errors: PJLinkErrorStatus(filter: .warning),
                    transitionDuration: transitionDuration
                )
            ),
            (
                label: "Tulle Avant-Scène #tulle #sol",
                mac: "00:0F:E2:91:C0:04",
                notes: "3-Chip DLP 4K · En veille avant le tableau 3",
                config: PJLinkSimulatedServer.Config(
                    name: "VP-TULLE-4K",
                    manufacturer: "Barco",
                    modelName: "UDX-4K32",
                    extraInfo: "3-Chip DLP Laser 31000lm",
                    pjlinkClass: 2,
                    serialNumber: "BC9980142",
                    firmwareVersion: "2.8.11",
                    nativeResolution: "3840x2400",
                    inputResolution: "3840x2160",
                    initialPower: .standby,
                    initialShutter: .videoAndAudioMuted,
                    initialInput: "34",
                    inputs: [
                        PJLinkInput(code: "31", customName: "HDMI 2.0"),
                        PJLinkInput(code: "34", customName: "12G-SDI"),
                        PJLinkInput(code: "35", customName: "DisplayPort 1.2"),
                        PJLinkInput(code: "52", customName: "HDBaseT"),
                    ],
                    lamps: [
                        PJLinkLamp(index: 1, hours: 2140, isOn: false),
                        PJLinkLamp(index: 2, hours: 2138, isOn: false),
                    ],
                    filterHours: 610,
                    transitionDuration: transitionDuration
                )
            ),
        ]

        var startedServers: [PJLinkSimulatedServer] = []
        var projectors: [Projector] = []

        for preset in presets {
            let server = PJLinkSimulatedServer(config: preset.config)
            let p = try server.start()
            startedServers.append(server)
            var pj = Projector(
                ip: "127.0.0.1",
                port: p,
                mac: preset.mac,
                label: preset.label,
                password: preset.config.password,
                notes: preset.notes,
                isSimulated: true
            )
            let polled = PJLinkClient.poll(pj, includeIdentity: true, includeClass2: true, timeout: 1.0)
            pj = polled.updatedProjector
            projectors.append(pj)
        }

        lock.lock()
        self.servers = startedServers
        lock.unlock()

        return projectors
    }

    public func stopAll() {
        lock.lock()
        let current = servers
        servers.removeAll()
        lock.unlock()
        for s in current {
            s.stop()
        }
    }
}
