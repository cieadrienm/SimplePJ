import Foundation

/// Live reachability and authentication state of a projector.
public enum ProjectorConnectionState: String, Codable, CaseIterable, Sendable {
    case online
    case polling
    case authRequired
    case offline
    case unknown

    public var label: String {
        switch self {
        case .online: return L("En ligne", "Online")
        case .polling: return L("Interrogation…", "Polling…")
        case .authRequired: return L("Mot de passe requis", "Password required")
        case .offline: return L("Hors ligne", "Offline")
        case .unknown: return L("Non interrogé", "Not polled")
        }
    }
}

/// A PJLink-controlled video projector in the stage fleet.
public struct Projector: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ip: String
    public var port: UInt16
    public var mac: String?

    /// User-assigned stage name (e.g. "Face Cour #face #cour", "Cyclo Haut #cyclo").
    public var label: String?
    /// Password for PJLink Class 1/2 MD5 authentication (empty if `PJLINK 0`).
    public var password: String
    /// Optional operator notes (lens ratio, throw distance, patch, IP subnet).
    public var notes: String?
    /// Whether this projector is hosted by the local built-in simulator.
    public var isSimulated: Bool

    // MARK: - PJLink Identity (`NAME`, `INF1`, `INF2`, `INFO`, `CLSS`, `SNUM`, `SVER`, `RRES`, `RLMP`, `RFIL`)
    public var pjlinkName: String?
    public var manufacturer: String?
    public var modelName: String?
    public var extraInfo: String?
    public var pjlinkClass: Int
    public var serialNumber: String?
    public var firmwareVersion: String?
    public var nativeResolution: String?
    public var replacementLamp: String?
    public var replacementFilter: String?

    // MARK: - Live Operational State
    public var connectionState: ProjectorConnectionState
    public var requiresAuth: Bool
    public var power: PJLinkPowerState
    public var shutter: PJLinkShutterState
    public var freeze: Bool
    public var currentInput: String
    public var availableInputs: [PJLinkInput]
    public var inputResolution: String?
    public var lamps: [PJLinkLamp]
    public var filterHours: Int?
    public var errors: PJLinkErrorStatus
    public var latencyMs: Double?
    public var lastSeen: Date?
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        ip: String,
        port: UInt16 = kPJLinkDefaultPort,
        mac: String? = nil,
        label: String? = nil,
        password: String = "",
        notes: String? = nil,
        isSimulated: Bool = false,
        pjlinkName: String? = nil,
        manufacturer: String? = nil,
        modelName: String? = nil,
        extraInfo: String? = nil,
        pjlinkClass: Int = 1,
        serialNumber: String? = nil,
        firmwareVersion: String? = nil,
        nativeResolution: String? = nil,
        replacementLamp: String? = nil,
        replacementFilter: String? = nil,
        connectionState: ProjectorConnectionState = .unknown,
        requiresAuth: Bool = false,
        power: PJLinkPowerState = .unknown,
        shutter: PJLinkShutterState = .open,
        freeze: Bool = false,
        currentInput: String = "31",
        availableInputs: [PJLinkInput] = PJLinkInput.standardDefaults,
        inputResolution: String? = nil,
        lamps: [PJLinkLamp] = [],
        filterHours: Int? = nil,
        errors: PJLinkErrorStatus = PJLinkErrorStatus(),
        latencyMs: Double? = nil,
        lastSeen: Date? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.ip = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = port
        self.mac = mac
        self.label = label
        self.password = password
        self.notes = notes
        self.isSimulated = isSimulated
        self.pjlinkName = pjlinkName
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.extraInfo = extraInfo
        self.pjlinkClass = pjlinkClass
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.nativeResolution = nativeResolution
        self.replacementLamp = replacementLamp
        self.replacementFilter = replacementFilter
        self.connectionState = connectionState
        self.requiresAuth = requiresAuth
        self.power = power
        self.shutter = shutter
        self.freeze = freeze
        self.currentInput = currentInput
        self.availableInputs = availableInputs
        self.inputResolution = inputResolution
        self.lamps = lamps
        self.filterHours = filterHours
        self.errors = errors
        self.latencyMs = latencyMs
        self.lastSeen = lastSeen
        self.lastError = lastError
    }

    // MARK: - Computed Stage Presentation

    /// Clean stage name without `#tag` tokens.
    public var cleanLabel: String? {
        guard let label else { return nil }
        let words = label.split(whereSeparator: \.isWhitespace).filter { !$0.hasPrefix("#") }
        let joined = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    /// Lowercase `#tag` tokens extracted from `label` (e.g. `["#face", "#cour"]`).
    public var tags: [String] {
        guard let label else { return [] }
        var seen: Set<String> = []
        var result: [String] = []
        for token in label.split(whereSeparator: \.isWhitespace) where token.hasPrefix("#") && token.count > 1 {
            let tag = String(token).lowercased()
            if seen.insert(tag).inserted {
                result.append(tag)
            }
        }
        return result
    }

    /// Primary display title: stage label -> PJLink `NAME` -> `INF1 INF2` -> IP.
    public var displayTitle: String {
        if let clean = cleanLabel { return clean }
        if let name = pjlinkName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        let hw = hardwareTitle
        if !hw.isEmpty { return hw }
        return endpointLabel
    }

    /// Manufacturer + model (e.g. `"Panasonic PT-RZ990"`).
    public var hardwareTitle: String {
        let mfg = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mdl = modelName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !mfg.isEmpty && !mdl.isEmpty {
            if mdl.lowercased().hasPrefix(mfg.lowercased()) { return mdl }
            return "\(mfg) \(mdl)"
        }
        return !mdl.isEmpty ? mdl : mfg
    }

    /// `"192.168.1.21"` or `"127.0.0.1:14352"` when using a non-standard port.
    public var endpointLabel: String {
        port == kPJLinkDefaultPort ? ip : "\(ip):\(port)"
    }

    /// Human-readable active input name (e.g. `"HDMI 1"`).
    public var currentInputDisplayName: String {
        if let found = availableInputs.first(where: { $0.code == currentInput }) {
            return found.displayName
        }
        return PJLinkInput(code: currentInput).displayName
    }

    /// `"31 · HDMI 1"`
    public var currentInputFullLabel: String {
        "\(currentInput) · \(currentInputDisplayName)"
    }

    /// True when the video shutter is closed.
    public var isShutterClosed: Bool {
        shutter.isVideoMuted
    }

    /// True when the projector is actively projecting light onto the stage (Power On + Shutter Open).
    public var isProjectingLight: Bool {
        connectionState == .online && power == .on && !shutter.isVideoMuted
    }

    /// Maximum lamp/laser hours across installed light sources.
    public var maxLampHours: Int? {
        lamps.map(\.hours).max()
    }

    /// Summary of lamp hours (`"1 420 h"` or `"1 850 h / 1 840 h"`).
    public var lampSummary: String {
        guard !lamps.isEmpty else { return "—" }
        return lamps.map { "\($0.hours) h" }.joined(separator: " · ")
    }

    // MARK: - Applying PJLink Replies

    /// Updates the projector model in place from a parsed `PJLinkReply`.
    public mutating func apply(reply: PJLinkReply) {
        if let error = reply.error {
            if error == .authenticationFailure {
                connectionState = .authRequired
                lastError = error.label
            } else if error != .undefinedCommand && error != .unavailableTime {
                lastError = "\(reply.command) : \(error.label)"
            }
            return
        }

        let val = reply.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard val.uppercased() != "OK" else { return }

        switch reply.command {
        case "POWR":
            let parsed = PJLinkPowerState(code: val)
            if parsed != .unknown { power = parsed }
        case "AVMT":
            shutter = PJLinkShutterState(code: val)
        case "INPT":
            if !val.isEmpty { currentInput = val }
        case "INST":
            let codes = val.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
            if !codes.isEmpty {
                var merged: [PJLinkInput] = []
                for code in codes {
                    let existingName = availableInputs.first(where: { $0.code == code })?.customName
                    merged.append(PJLinkInput(code: code, customName: existingName))
                }
                availableInputs = merged
            }
        case "ERST":
            if val.count >= 6 {
                errors = PJLinkErrorStatus(code: val)
            }
        case "LAMP":
            let parsed = PJLinkLamp.parseList(val)
            if !parsed.isEmpty { lamps = parsed }
        case "NAME":
            pjlinkName = val.isEmpty ? nil : val
        case "INF1":
            manufacturer = val.isEmpty ? nil : val
        case "INF2":
            modelName = val.isEmpty ? nil : val
        case "INFO":
            extraInfo = val.isEmpty ? nil : val
        case "CLSS":
            if let cls = Int(val), (1...2).contains(cls) { pjlinkClass = cls }
        case "SNUM":
            serialNumber = (val.isEmpty || val == "0") ? nil : val
        case "SVER":
            firmwareVersion = val.isEmpty ? nil : val
        case "IRES":
            inputResolution = (val == "0" || val == "-" || val.isEmpty) ? "Aucun signal" : val
        case "RRES":
            nativeResolution = (val == "0" || val == "-" || val.isEmpty) ? nil : val
        case "FILT":
            if let hours = Int(val) { filterHours = hours }
        case "RLMP":
            replacementLamp = val.isEmpty ? nil : val
        case "RFIL":
            replacementFilter = val.isEmpty ? nil : val
        case "FREZ":
            freeze = (val == "1")
        default:
            break
        }
    }

    /// Updates a specific input's custom name from a Class 2 `%2INNM ?<code>` reply.
    public mutating func applyInputName(code: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, PJLinkResponseError(rawValue: trimmed.uppercased()) == nil else { return }
        if let idx = availableInputs.firstIndex(where: { $0.code == code }) {
            availableInputs[idx].customName = trimmed
        } else {
            availableInputs.append(PJLinkInput(code: code, customName: trimmed))
        }
    }
}
