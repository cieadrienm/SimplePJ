import CryptoKit
import Foundation

/// Standard PJLink TCP/UDP port (JBMIA PJLink specification Class 1 & Class 2).
public let kPJLinkDefaultPort: UInt16 = 4352

/// Power status reported by `%1POWR ?`.
public enum PJLinkPowerState: String, Codable, CaseIterable, Sendable {
    case standby = "0"
    case on = "1"
    case cooling = "2"
    case warming = "3"
    case unknown = "?"

    public init(code: String) {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "0": self = .standby
        case "1": self = .on
        case "2": self = .cooling
        case "3": self = .warming
        default: self = .unknown
        }
    }

    public var label: String {
        switch self {
        case .standby: return "Veille"
        case .on: return "Allumé"
        case .cooling: return "Refroidissement"
        case .warming: return "Préchauffage"
        case .unknown: return "Inconnu"
        }
    }

    public var shortLabel: String {
        switch self {
        case .standby: return "VEILLE"
        case .on: return "ON"
        case .cooling: return "REFROID."
        case .warming: return "CHAUFFE"
        case .unknown: return "—"
        }
    }

    public var isLit: Bool {
        self == .on || self == .warming
    }

    public var isTransitioning: Bool {
        self == .cooling || self == .warming
    }
}

/// Shutter / AV Mute status reported by `%1AVMT ?`.
public enum PJLinkShutterState: String, Codable, CaseIterable, Sendable {
    case open = "30"
    case videoMuted = "11"
    case audioMuted = "21"
    case videoAndAudioMuted = "31"

    public init(code: String) {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "11": self = .videoMuted
        case "21": self = .audioMuted
        case "31": self = .videoAndAudioMuted
        case "10", "20", "30": self = .open
        default: self = .open
        }
    }

    /// True when the video shutter / optical douser is closed (blackout).
    public var isVideoMuted: Bool {
        self == .videoMuted || self == .videoAndAudioMuted
    }

    /// True when audio mute is active.
    public var isAudioMuted: Bool {
        self == .audioMuted || self == .videoAndAudioMuted
    }

    public var label: String {
        switch self {
        case .open: return "Volet ouvert"
        case .videoMuted: return "Volet vidéo fermé"
        case .audioMuted: return "Audio coupé"
        case .videoAndAudioMuted: return "Volet fermé (Noir)"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .open: return "OUVERT"
        case .videoMuted: return "VOLET FERMÉ"
        case .audioMuted: return "AUDIO MUET"
        case .videoAndAudioMuted: return "VOLET FERMÉ"
        }
    }
}

/// Input category defined by the first digit of a 2-digit PJLink input code (`11`..`59`).
public enum PJLinkInputCategory: String, Codable, CaseIterable, Sendable {
    case rgb = "1"
    case video = "2"
    case digital = "3"
    case storage = "4"
    case network = "5"
    case other = "0"

    public init(firstCharacter: Character?) {
        switch firstCharacter {
        case "1": self = .rgb
        case "2": self = .video
        case "3": self = .digital
        case "4": self = .storage
        case "5": self = .network
        default: self = .other
        }
    }

    public var label: String {
        switch self {
        case .rgb: return "RGB / VGA"
        case .video: return "Vidéo"
        case .digital: return "Numérique"
        case .storage: return "Stockage"
        case .network: return "Réseau / HDBaseT"
        case .other: return "Entrée"
        }
    }

    public var symbol: String {
        switch self {
        case .rgb: return "display"
        case .video: return "film"
        case .digital: return "cable.connector.horizontal"
        case .storage: return "externaldrive"
        case .network: return "network"
        case .other: return "arrow.right.to.line"
        }
    }
}

/// A video/audio input source on a PJLink projector.
public struct PJLinkInput: Identifiable, Hashable, Codable, Sendable {
    public var id: String { code }
    public var code: String
    public var customName: String?

    public init(code: String, customName: String? = nil) {
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.customName = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    public var category: PJLinkInputCategory {
        PJLinkInputCategory(firstCharacter: code.first)
    }

    public var channelIndex: Int {
        guard code.count >= 2, let idx = Int(String(code.dropFirst())) else { return 1 }
        return idx
    }

    /// Standard fallback name when Class 2 `%2INNM` is not available.
    public var defaultName: String {
        switch code {
        case "31": return "HDMI 1"
        case "32": return "HDMI 2"
        case "33": return "DVI-D / SDI"
        case "34": return "SDI 1"
        case "35": return "DisplayPort"
        case "51": return "LAN / HDBaseT"
        case "52": return "DIGITAL LINK"
        case "53": return "Art-Net / Réseau"
        default:
            switch category {
            case .rgb: return "RGB \(channelIndex)"
            case .video: return "Vidéo \(channelIndex)"
            case .digital: return "Numérique \(channelIndex)"
            case .storage: return "USB \(channelIndex)"
            case .network: return "Réseau \(channelIndex)"
            case .other: return "Entrée \(code)"
            }
        }
    }

    public var displayName: String {
        customName ?? defaultName
    }

    public var fullLabel: String {
        "\(code) · \(displayName)"
    }

    public static let standardDefaults: [PJLinkInput] = [
        PJLinkInput(code: "31", customName: "HDMI 1"),
        PJLinkInput(code: "32", customName: "HDMI 2"),
        PJLinkInput(code: "33", customName: "SDI / DVI"),
        PJLinkInput(code: "51", customName: "HDBaseT / LAN"),
        PJLinkInput(code: "11", customName: "RGB 1"),
    ]
}

/// Error severity per subsystem in `%1ERST`.
public enum PJLinkErrorLevel: Int, Codable, Comparable, CaseIterable, Sendable {
    case ok = 0
    case warning = 1
    case error = 2

    public static func < (lhs: PJLinkErrorLevel, rhs: PJLinkErrorLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(character: Character) {
        switch character {
        case "1": self = .warning
        case "2": self = .error
        default: self = .ok
        }
    }

    public var label: String {
        switch self {
        case .ok: return "OK"
        case .warning: return "Avertissement"
        case .error: return "Erreur"
        }
    }
}

/// Six-component hardware health status reported by `%1ERST ?` (`000000` when healthy).
public struct PJLinkErrorStatus: Hashable, Codable, Sendable {
    public var fan: PJLinkErrorLevel
    public var lamp: PJLinkErrorLevel
    public var temperature: PJLinkErrorLevel
    public var coverOpen: PJLinkErrorLevel
    public var filter: PJLinkErrorLevel
    public var other: PJLinkErrorLevel

    public init(
        fan: PJLinkErrorLevel = .ok,
        lamp: PJLinkErrorLevel = .ok,
        temperature: PJLinkErrorLevel = .ok,
        coverOpen: PJLinkErrorLevel = .ok,
        filter: PJLinkErrorLevel = .ok,
        other: PJLinkErrorLevel = .ok
    ) {
        self.fan = fan
        self.lamp = lamp
        self.temperature = temperature
        self.coverOpen = coverOpen
        self.filter = filter
        self.other = other
    }

    /// Parses a 6-character PJLink `ERST` string (e.g. `"000000"`, `"001020"`).
    public init(code: String) {
        let chars = Array(code.trimmingCharacters(in: .whitespacesAndNewlines))
        func level(at index: Int) -> PJLinkErrorLevel {
            guard index < chars.count else { return .ok }
            return PJLinkErrorLevel(character: chars[index])
        }
        self.fan = level(at: 0)
        self.lamp = level(at: 1)
        self.temperature = level(at: 2)
        self.coverOpen = level(at: 3)
        self.filter = level(at: 4)
        self.other = level(at: 5)
    }

    public var rawCode: String {
        "\(fan.rawValue)\(lamp.rawValue)\(temperature.rawValue)\(coverOpen.rawValue)\(filter.rawValue)\(other.rawValue)"
    }

    public var highestSeverity: PJLinkErrorLevel {
        [fan, lamp, temperature, coverOpen, filter, other].max() ?? .ok
    }

    public var isHealthy: Bool {
        highestSeverity == .ok
    }

    public var components: [(name: String, symbol: String, level: PJLinkErrorLevel)] {
        [
            ("Ventilateur", "fan", fan),
            ("Lampe / Laser", "lightbulb", lamp),
            ("Température", "thermometer.high", temperature),
            ("Capot", "lock.open", coverOpen),
            ("Filtre", "aqi.medium", filter),
            ("Autre", "exclamationmark.circle", other),
        ]
    }

    public var activeAlerts: [(name: String, level: PJLinkErrorLevel)] {
        components.filter { $0.level != .ok }.map { ($0.name, $0.level) }
    }

    public var summaryLabel: String {
        let alerts = activeAlerts
        if alerts.isEmpty { return "Aucune alerte" }
        return alerts.map { "\($0.name) (\($0.level.label.lowercased()))" }.joined(separator: ", ")
    }
}

/// Lamp or laser light source hours and lit state reported by `%1LAMP ?`.
public struct PJLinkLamp: Hashable, Codable, Sendable {
    public var index: Int
    public var hours: Int
    public var isOn: Bool

    public init(index: Int = 1, hours: Int, isOn: Bool) {
        self.index = index
        self.hours = hours
        self.isOn = isOn
    }

    /// Parses `"1420 1"` or multi-lamp `"1850 1 1840 0"`.
    public static func parseList(_ value: String) -> [PJLinkLamp] {
        let tokens = value.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 2 else { return [] }
        var lamps: [PJLinkLamp] = []
        var i = 0
        var lampIndex = 1
        while i + 1 < tokens.count {
            if let hours = Int(tokens[i]) {
                let on = tokens[i + 1] == "1"
                lamps.append(PJLinkLamp(index: lampIndex, hours: hours, isOn: on))
                lampIndex += 1
            }
            i += 2
        }
        return lamps
    }
}

/// Protocol error codes returned by a PJLink device (`ERR1`..`ERR4`, `ERRA`).
public enum PJLinkResponseError: String, Error, Codable, Equatable, Sendable, LocalizedError {
    case undefinedCommand = "ERR1"
    case outOfParameter = "ERR2"
    case unavailableTime = "ERR3"
    case projectorFailure = "ERR4"
    case authenticationFailure = "ERRA"

    public var label: String {
        switch self {
        case .undefinedCommand: return "Commande non supportée (ERR1)"
        case .outOfParameter: return "Paramètre hors plage (ERR2)"
        case .unavailableTime: return "Projecteur occupé : veille, chauffe ou refroidissement (ERR3)"
        case .projectorFailure: return "Défaillance matérielle du projecteur (ERR4)"
        case .authenticationFailure: return "Mot de passe PJLink refusé (ERRA)"
        }
    }

    public var errorDescription: String? { label }
}

/// Greeting sent by a PJLink server upon TCP connection on port 4352.
public enum PJLinkGreeting: Equatable, Sendable {
    /// `PJLINK 0` — No password required.
    case noAuth
    /// `PJLINK 1 <random>` — MD5 challenge authentication required.
    case challenge(String)
    /// `PJLINK ERRA` — Authentication error.
    case authError

    public static func parse(_ line: String) -> PJLinkGreeting? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "PJLINK 0" { return .noAuth }
        if trimmed == "PJLINK ERRA" { return .authError }
        if trimmed.hasPrefix("PJLINK 1 ") {
            let token = String(trimmed.dropFirst("PJLINK 1 ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { return .challenge(token) }
        }
        if trimmed == "PJLINK 1" { return .challenge("") }
        return nil
    }
}

/// MD5 challenge-response helper and common factory passwords.
public enum PJLinkAuth {
    /// Common factory default PJLink passwords across major stage projector brands.
    public static let commonPasswords: [String] = [
        "panasonic",
        "admin",
        "pjlink",
        "JBMIA",
        "0000",
        "1234",
        "EPSONWEB",
        "admin1",
        "projector",
    ]

    /// Computes lowercase 32-hex-char MD5 of `<challenge><password>`.
    public static func md5Digest(challenge: String, password: String) -> String {
        let combined = Data((challenge + password).utf8)
        let digest = Insecure.MD5.hash(data: combined)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Formats a wire command with optional MD5 challenge prefix and trailing `\r`.
    public static func frameCommand(_ command: String, challenge: String? = nil, password: String? = nil) -> String {
        let clean = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = clean.hasPrefix("%") ? clean : "%1\(clean)"
        if let challenge, !challenge.isEmpty {
            let pwd = password ?? ""
            let hash = md5Digest(challenge: challenge, password: pwd)
            return "\(hash)\(body)\r"
        }
        return "\(body)\r"
    }
}

/// Parsed reply from a PJLink projector (`%1POWR=OK`, `%1POWR=1`, `%2INNM=HDMI 1`, `PJLINK ERRA`).
public struct PJLinkReply: Equatable, Sendable {
    public var pjlinkClass: Int
    public var command: String
    public var value: String
    public var error: PJLinkResponseError?

    public init(pjlinkClass: Int, command: String, value: String, error: PJLinkResponseError? = nil) {
        self.pjlinkClass = pjlinkClass
        self.command = command.uppercased()
        self.value = value
        self.error = error
    }

    public var isOK: Bool {
        error == nil && value.uppercased() == "OK"
    }

    public static func parse(_ rawLine: String) -> PJLinkReply? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.uppercased() == "PJLINK ERRA" || trimmed.uppercased().hasSuffix("=ERRA") {
            return PJLinkReply(pjlinkClass: 1, command: "AUTH", value: "ERRA", error: .authenticationFailure)
        }
        guard trimmed.hasPrefix("%"), trimmed.count >= 7,
              let eqIndex = trimmed.firstIndex(of: "=") else {
            return nil
        }
        let classChar = trimmed[trimmed.index(after: trimmed.startIndex)]
        let pjClass = Int(String(classChar)) ?? 1
        let cmdStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
        guard cmdStart < eqIndex else { return nil }
        let cmd = String(trimmed[cmdStart..<eqIndex]).uppercased()
        let val = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let err = PJLinkResponseError(rawValue: val.uppercased())
        return PJLinkReply(pjlinkClass: pjClass, command: cmd, value: val, error: err)
    }
}

/// High-level PJLink Class 1 & Class 2 commands.
public enum PJLinkCommand: Equatable, Sendable {
    // Class 1
    case powerOn
    case powerOff
    case powerQuery
    case shutterClose
    case shutterOpen
    case shutterVideoMute(Bool)
    case shutterAudioMute(Bool)
    case shutterQuery
    case inputSelect(String)
    case inputQuery
    case inputListQuery
    case errorStatusQuery
    case lampQuery
    case nameQuery
    case manufacturerQuery
    case modelQuery
    case extraInfoQuery
    case classQuery

    // Class 2
    case serialNumberQuery
    case firmwareVersionQuery
    case inputNameQuery(String)
    case inputResolutionQuery
    case recommendedResolutionQuery
    case filterUsageQuery
    case replacementLampQuery
    case replacementFilterQuery
    case freeze(Bool)
    case freezeQuery
    case speakerVolume(Bool)
    case micVolume(Bool)
    case searchBroadcast

    // Raw command (e.g. "%1INFO ?" or "%2SNUM ?")
    case raw(String)

    public var wireBody: String {
        switch self {
        case .powerOn: return "%1POWR 1"
        case .powerOff: return "%1POWR 0"
        case .powerQuery: return "%1POWR ?"
        case .shutterClose: return "%1AVMT 31"
        case .shutterOpen: return "%1AVMT 30"
        case .shutterVideoMute(let mute): return mute ? "%1AVMT 11" : "%1AVMT 10"
        case .shutterAudioMute(let mute): return mute ? "%1AVMT 21" : "%1AVMT 20"
        case .shutterQuery: return "%1AVMT ?"
        case .inputSelect(let code): return "%1INPT \(code.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .inputQuery: return "%1INPT ?"
        case .inputListQuery: return "%1INST ?"
        case .errorStatusQuery: return "%1ERST ?"
        case .lampQuery: return "%1LAMP ?"
        case .nameQuery: return "%1NAME ?"
        case .manufacturerQuery: return "%1INF1 ?"
        case .modelQuery: return "%1INF2 ?"
        case .extraInfoQuery: return "%1INFO ?"
        case .classQuery: return "%1CLSS ?"
        case .serialNumberQuery: return "%2SNUM ?"
        case .firmwareVersionQuery: return "%2SVER ?"
        case .inputNameQuery(let code): return "%2INNM ?\(code.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .inputResolutionQuery: return "%2IRES ?"
        case .recommendedResolutionQuery: return "%2RRES ?"
        case .filterUsageQuery: return "%2FILT ?"
        case .replacementLampQuery: return "%2RLMP ?"
        case .replacementFilterQuery: return "%2RFIL ?"
        case .freeze(let on): return on ? "%2FREZ 1" : "%2FREZ 0"
        case .freezeQuery: return "%2FREZ ?"
        case .speakerVolume(let up): return up ? "%2SVOL 1" : "%2SVOL 0"
        case .micVolume(let up): return up ? "%2MVOL 1" : "%2MVOL 0"
        case .searchBroadcast: return "%2SRCH"
        case .raw(let text):
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.hasPrefix("%") ? clean : "%1\(clean)"
        }
    }

    public var humanDescription: String {
        switch self {
        case .powerOn: return "Allumer (POWR 1)"
        case .powerOff: return "Mettre en veille (POWR 0)"
        case .powerQuery: return "État d'alimentation (POWR ?)"
        case .shutterClose: return "Fermer le volet / Noir (AVMT 31)"
        case .shutterOpen: return "Ouvrir le volet (AVMT 30)"
        case .shutterVideoMute(let m): return m ? "Fermer volet vidéo (AVMT 11)" : "Ouvrir volet vidéo (AVMT 10)"
        case .shutterAudioMute(let m): return m ? "Couper l'audio (AVMT 21)" : "Rétablir l'audio (AVMT 20)"
        case .shutterQuery: return "État du volet (AVMT ?)"
        case .inputSelect(let code): return "Entrée \(code) (INPT \(code))"
        case .inputQuery: return "Entrée active (INPT ?)"
        case .inputListQuery: return "Liste des entrées (INST ?)"
        case .errorStatusQuery: return "Diagnostic santé (ERST ?)"
        case .lampQuery: return "Heures lampe/laser (LAMP ?)"
        case .nameQuery: return "Nom PJLink (NAME ?)"
        case .manufacturerQuery: return "Fabricant (INF1 ?)"
        case .modelQuery: return "Modèle (INF2 ?)"
        case .extraInfoQuery: return "Info complémentaire (INFO ?)"
        case .classQuery: return "Classe PJLink (CLSS ?)"
        case .serialNumberQuery: return "Numéro de série (SNUM ?)"
        case .firmwareVersionQuery: return "Version firmware (SVER ?)"
        case .inputNameQuery(let code): return "Nom de l'entrée \(code) (INNM ?\(code))"
        case .inputResolutionQuery: return "Résolution du signal (IRES ?)"
        case .recommendedResolutionQuery: return "Résolution native (RRES ?)"
        case .filterUsageQuery: return "Heures filtre (FILT ?)"
        case .replacementLampQuery: return "Référence lampe (RLMP ?)"
        case .replacementFilterQuery: return "Référence filtre (RFIL ?)"
        case .freeze(let on): return on ? "Geler l'image (FREZ 1)" : "Dégeler l'image (FREZ 0)"
        case .freezeQuery: return "État du gel d'image (FREZ ?)"
        case .speakerVolume(let up): return up ? "Volume HP + (SVOL 1)" : "Volume HP − (SVOL 0)"
        case .micVolume(let up): return up ? "Volume Micro + (MVOL 1)" : "Volume Micro − (MVOL 0)"
        case .searchBroadcast: return "Recherche réseau Class 2 (SRCH)"
        case .raw(let s): return "Commande directe (\(s))"
        }
    }
}

/// A recorded protocol exchange for the live PJLink diagnostic console.
public struct PJLinkExchange: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var projectorIP: String
    public var projectorTitle: String
    public var tx: String
    public var rx: String
    public var durationMs: Double
    public var isError: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        projectorIP: String,
        projectorTitle: String,
        tx: String,
        rx: String,
        durationMs: Double,
        isError: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.projectorIP = projectorIP
        self.projectorTitle = projectorTitle
        self.tx = tx
        self.rx = rx
        self.durationMs = durationMs
        self.isError = isError
    }
}
