import Foundation

/// Serializable show fleet document (`.simplepj` JSON).
public struct FleetDocument: Codable, Equatable, Sendable {
    public static let fileExtension = "simplepj"
    public var version: Int
    public var createdAt: Date
    public var showTitle: String?
    public var scanRange: String?
    public var projectors: [Projector]

    public init(
        version: Int = 1,
        createdAt: Date = Date(),
        showTitle: String? = nil,
        scanRange: String? = nil,
        projectors: [Projector]
    ) {
        self.version = version
        self.createdAt = createdAt
        self.showTitle = showTitle
        self.scanRange = scanRange
        self.projectors = projectors
    }

    public func encodeJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decodeJSON(_ data: Data) throws -> FleetDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FleetDocument.self, from: data)
    }
}

/// Export formats for stage technical sheets, CSV inventories, and JSON backups.
public enum FleetExportFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case csv
    case json
    case ipPort = "ip-port"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .txt: return L("Fiche technique plateau (.txt)", "Stage technical sheet (.txt)")
        case .csv: return L("Tableau CSV (.csv)", "CSV spreadsheet (.csv)")
        case .json: return L("Parc complet JSON (.json)", "Full JSON fleet (.json)")
        case .ipPort: return L("Liste d'adresses IP:port (.txt)", "IP:port address list (.txt)")
        }
    }

    public var detail: String {
        switch self {
        case .txt: return L("Rapport lisible : noms de plateau, IP/MAC, modèles, numéros de série, entrées, heures lampe/filtre et alertes.", "Readable report: stage names, IP/MAC, models, serial numbers, inputs, lamp/filter hours, and alerts.")
        case .csv: return L("Colonnes séparées par des virgules pour tableur ou régie.", "Comma-separated columns for spreadsheets or stage management.")
        case .json: return L("Structure complète compatible avec l'ouverture dans SimplePJ.", "Full fleet structure compatible with reopening in SimplePJ.")
        case .ipPort: return L("Une adresse IP (ou IP:port) par ligne.", "One IP (or IP:port) address per line.")
        }
    }

    public var defaultExtension: String {
        switch self {
        case .txt, .ipPort: return "txt"
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

public enum FleetExporter {
    public static func render(_ projectors: [Projector], format: FleetExportFormat, showTitle: String? = nil) -> String {
        switch format {
        case .ipPort:
            return projectors.map(\.endpointLabel).joined(separator: "\n") + (projectors.isEmpty ? "" : "\n")

        case .json:
            let doc = FleetDocument(showTitle: showTitle, projectors: projectors)
            guard let data = try? doc.encodeJSON(), let text = String(data: data, encoding: .utf8) else { return "{}" }
            return text

        case .csv:
            var lines = ["Nom,IP,Port,MAC,Fabricant,Modele,Classe,Serie,Firmware,Alimentation,Volet,Entree,Signal,HeuresLampe,HeuresFiltre,Erreurs,Notes"]
            for pj in projectors {
                let row: [String] = [
                    csvEscape(pj.displayTitle),
                    csvEscape(pj.ip),
                    "\(pj.port)",
                    csvEscape(pj.mac ?? ""),
                    csvEscape(pj.manufacturer ?? ""),
                    csvEscape(pj.modelName ?? ""),
                    "\(pj.pjlinkClass)",
                    csvEscape(pj.serialNumber ?? ""),
                    csvEscape(pj.firmwareVersion ?? ""),
                    csvEscape(pj.power.label),
                    csvEscape(pj.shutter.label),
                    csvEscape(pj.currentInputFullLabel),
                    csvEscape(pj.inputResolution ?? ""),
                    csvEscape(pj.lampSummary),
                    pj.filterHours.map { "\($0)" } ?? "",
                    csvEscape(pj.errors.rawCode),
                    csvEscape(pj.notes ?? ""),
                ]
                lines.append(row.joined(separator: ","))
            }
            return lines.joined(separator: "\n") + "\n"

        case .txt:
            var out: [String] = []
            let title = showTitle?.isEmpty == false ? showTitle! : "Parc Vidéoprojecteurs PJLink"
            out.append("==================================================================")
            out.append("SIMPLEPJ — \(title.uppercased())")
            out.append("cie Adrien M · \(projectors.count) vidéoprojecteur\(projectors.count > 1 ? "s" : "")")
            out.append("==================================================================")
            out.append("")
            for (idx, pj) in projectors.enumerated() {
                let tags = pj.tags.isEmpty ? "" : "  [\(pj.tags.joined(separator: " "))]"
                out.append("[\(idx + 1)] \(pj.displayTitle)\(tags)")
                out.append("    Adresse      : \(pj.endpointLabel)" + (pj.mac.map { "  (MAC \($0))" } ?? ""))
                out.append("    Appareil     : \(pj.hardwareTitle.isEmpty ? "—" : pj.hardwareTitle)  (PJLink Classe \(pj.pjlinkClass))")
                if let sn = pj.serialNumber {
                    out.append("    Série / FW   : \(sn)" + (pj.firmwareVersion.map { " · FW \($0)" } ?? ""))
                }
                out.append("    État         : \(pj.connectionState.label) · Alimentation : \(pj.power.label) · \(pj.shutter.label)" + (pj.freeze ? " · GEL ACTIF" : ""))
                out.append("    Entrée       : \(pj.currentInputFullLabel)" + (pj.inputResolution.map { " · Signal \($0)" } ?? "") + (pj.nativeResolution.map { " (natif \($0))" } ?? ""))
                out.append("    Lampe/Filtre : \(pj.lampSummary)" + (pj.filterHours.map { " · Filtre \($0) h" } ?? ""))
                out.append("    Santé (ERST) : \(pj.errors.rawCode) — \(pj.errors.summaryLabel)")
                if let notes = pj.notes, !notes.isEmpty {
                    out.append("    Notes        : \(notes)")
                }
                out.append("")
            }
            return out.joined(separator: "\n")
        }
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

/// Imports saved projectors from SIGMASIX ProjectorManager (`ch.sigmasix.ProjectorManager`).
public enum ProjectorManagerImporter {
    public static let domain = "ch.sigmasix.ProjectorManager"

    public struct Entry: Equatable, Sendable {
        public let ip: String
        public let port: UInt16
        public let password: String

        public init(ip: String, port: UInt16 = kPJLinkDefaultPort, password: String = "") {
            self.ip = ip
            self.port = port
            self.password = password
        }
    }

    /// Reads the user's saved projector list from `ch.sigmasix.ProjectorManager` preferences.
    public static func readPreferencesEntries() -> [Entry] {
        if let raw = CFPreferencesCopyAppValue("projs" as CFString, domain as CFString) {
            let parsed = parseProjsObject(raw)
            if !parsed.isEmpty { return parsed }
        }
        let plistPath = ("~/Library/Preferences/\(domain).plist" as NSString).expandingTildeInPath
        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)) {
            return parsePlistData(data)
        }
        return []
    }

    /// Parses a `ch.sigmasix.ProjectorManager.plist` binary or XML property list.
    public static func parsePlistData(_ data: Data) -> [Entry] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let projs = dict["projs"]
        else { return [] }
        return parseProjsObject(projs)
    }

    public static func parseProjsObject(_ raw: Any) -> [Entry] {
        guard let rows = raw as? [Any] else { return [] }
        var seen: Set<String> = []
        var entries: [Entry] = []
        for row in rows {
            if let pair = row as? [Any], let first = pair.first as? String {
                let rawHost = first.trimmingCharacters(in: .whitespacesAndNewlines)
                let pwd = (pair.count > 1 ? (pair[1] as? String) : nil) ?? ""
                guard let ep = IPv4Range.parseEndpoints(rawHost).first else { continue }
                let key = "\(ep.ip):\(ep.port)"
                if seen.insert(key).inserted {
                    entries.append(Entry(ip: ep.ip, port: ep.port, password: pwd))
                }
            }
        }
        return entries
    }
}

