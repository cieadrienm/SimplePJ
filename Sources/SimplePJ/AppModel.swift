import AppKit
import Foundation
import Observation
import SimplePJCore
import UniformTypeIdentifiers

enum MainViewMode: String, CaseIterable, Identifiable, Sendable {
    case cards
    case table

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cards: return L("Plateau", "Stage")
        case .table: return L("Liste", "List")
        }
    }

    var symbol: String {
        switch self {
        case .cards: return "square.grid.2x2"
        case .table: return "list.bullet"
        }
    }
}

@Observable
@MainActor
final class AppModel {
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct PowerConfirmRequest: Identifiable {
        let id = UUID()
        let turnOn: Bool
        let targets: [Projector]
    }

    let fleet: FleetController

    var language: AppLanguage = Localization.current {
        didSet {
            Localization.current = language
        }
    }

    var viewMode: MainViewMode = .cards
    var showSidebar: Bool = true
    var showInspector: Bool = true
    var showConsoleDrawer: Bool = false

    // Sheets & modals
    var showAddProjector: Bool = false
    var showExport: Bool = false
    var showOSCGuide: Bool = false
    var showShortcuts: Bool = false
    var showHelp: Bool = false
    var showAbout: Bool = false
    var renamingRange: SavedRange? = nil
    var powerConfirm: PowerConfirmRequest? = nil
    var alert: AlertItem? = nil

    // Export options
    var exportFormat: FleetExportFormat = .txt
    var exportVisibleOnly: Bool = false

    // Focus triggers
    var searchFocusRequest: Int = 0
    var labelFocusRequest: Int = 0

    // Ephemeral flash message
    var flashMessage: String? = nil

    init(startServices: Bool = true, persistEnabled: Bool = true) {
        self.fleet = FleetController(startServices: startServices, persistEnabled: persistEnabled)
    }

    var inspectedProjector: Projector? {
        guard fleet.selection.count == 1, let id = fleet.selection.first else { return nil }
        return fleet.projectors.first { $0.id == id }
    }

    var currentInterface: NetworkInterface? {
        NetworkInterface.scannableInterfaces().first { $0.cidr == fleet.rangeInput }
    }

    func useInterface(_ iface: NetworkInterface) {
        fleet.rangeInput = iface.cidr
    }

    func toggleInspector() {
        showInspector.toggle()
    }

    func revealInspector() {
        if !showInspector { showInspector = true }
    }

    func flash(_ text: String) {
        flashMessage = text
        fleet.statusMessage = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            if self?.flashMessage == text {
                self?.flashMessage = nil
            }
        }
    }

    // MARK: - Power Confirmation Safety (Bypassed with Option key)

    func requestPower(on: Bool, targets: [Projector]? = nil) {
        let list = targets ?? fleet.activeTargets
        guard !list.isEmpty else { return }
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        // Turning off a projector mid-show takes minutes to cool and warm back up;
        // ask confirmation unless Option (⌥) is held.
        if !on && !optionHeld {
            powerConfirm = PowerConfirmRequest(turnOn: false, targets: list)
        } else {
            fleet.setPower(on: on, on: list)
        }
    }

    // MARK: - Selection & Clipboard

    func selectAll() {
        fleet.selection = Set(fleet.visibleProjectors.map(\.id))
    }

    func deleteSelected() {
        guard !fleet.selection.isEmpty else { return }
        let count = fleet.selection.count
        fleet.removeProjectors(ids: fleet.selection)
        flash(L("\(Format.count(count, "projecteur")) retiré\(count > 1 ? "s" : "")", "\(count) projector\(count > 1 ? "s" : "") removed"))
    }

    func copySelectedIPs() {
        let ips = fleet.selectedProjectors.map(\.endpointLabel).joined(separator: "\n")
        guard !ips.isEmpty else { return }
        Self.copyToPasteboard(ips)
        flash(L("Adresse\(fleet.selectedProjectors.count > 1 ? "s" : "") copiée\(fleet.selectedProjectors.count > 1 ? "s" : "")", "Address\(fleet.selectedProjectors.count > 1 ? "es" : "") copied"))
    }

    static func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Host Actions (Web UI, Wake-on-LAN, Ping)

    func openWebInterface(_ pj: Projector) {
        guard let url = URL(string: "http://\(pj.ip)") else { return }
        NSWorkspace.shared.open(url)
    }

    func wakeProjectors(_ targets: [Projector]? = nil) {
        let list = (targets ?? fleet.activeTargets).filter { $0.mac != nil }
        guard !list.isEmpty else { return }
        var sent = 0
        for pj in list {
            if let mac = pj.mac, WakeOnLAN.send(mac: mac) {
                sent += 1
            }
        }
        flash(L("Paquet Wake-on-LAN envoyé à \(Format.count(sent, "projecteur"))", "Wake-on-LAN packet sent to \(sent) projector\(sent > 1 ? "s" : "")"))
    }

    // MARK: - Open / Save `.simplepj` Fleet & Export

    func openFleetPanel() {
        let panel = NSOpenPanel()
        panel.title = L("Ouvrir un parc SimplePJ", "Open SimplePJ Fleet")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.json, UTType.plainText, UTType.propertyList]
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func importFromProjectorManager() {
        let count = fleet.importFromProjectorManager()
        if count > 0 {
            flash(L("\(Format.count(count, "projecteur")) importé\(count > 1 ? "s" : "") depuis ProjectorManager", "\(count) projector\(count > 1 ? "s" : "") imported from ProjectorManager"))
        } else {
            alert = AlertItem(
                title: L("Aucun projecteur ProjectorManager", "No ProjectorManager projectors found"),
                message: L(
                    "Aucune liste de vidéoprojecteurs n'a été trouvée dans les préférences de ProjectorManager (ch.sigmasix.ProjectorManager).",
                    "No saved projector list was found in ProjectorManager preferences (ch.sigmasix.ProjectorManager)."
                )
            )
        }
    }

    func open(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let doc = try? FleetDocument.decodeJSON(data) {
                fleet.projectors = doc.projectors
                if let range = doc.scanRange, !range.isEmpty {
                    fleet.rangeInput = range
                }
                if let first = doc.projectors.first {
                    fleet.selection = [first.id]
                }
                fleet.saveFleet()
                fleet.refreshAll(includeIdentity: true)
                flash(L("Parc « \(url.deletingPathExtension().lastPathComponent) » chargé (\(Format.count(doc.projectors.count, "projecteur")))", "Fleet \"\(url.deletingPathExtension().lastPathComponent)\" loaded (\(doc.projectors.count) projector\(doc.projectors.count > 1 ? "s" : ""))"))
            } else {
                let pmEntries = ProjectorManagerImporter.parsePlistData(data)
                if !pmEntries.isEmpty {
                    let count = fleet.importEntries(pmEntries, sourceLabel: url.lastPathComponent)
                    flash(L("\(Format.count(count, "projecteur")) importé\(count > 1 ? "s" : "") depuis \(url.lastPathComponent)", "\(count) projector\(count > 1 ? "s" : "") imported from \(url.lastPathComponent)"))
                } else if let text = String(data: data, encoding: .utf8) {
                    let endpoints = IPv4Range.parseEndpoints(text)
                    guard !endpoints.isEmpty else {
                        throw NSError(domain: "SimplePJ", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Aucune adresse IP valide trouvée dans \(url.lastPathComponent)", "No valid IP address found in \(url.lastPathComponent)")])
                    }
                    for ep in endpoints {
                        fleet.addProjector(ip: ep.ip, port: ep.port)
                    }
                    flash(L("\(Format.count(endpoints.count, "projecteur")) importé\(endpoints.count > 1 ? "s" : "")", "\(endpoints.count) projector\(endpoints.count > 1 ? "s" : "") imported"))
                }
            }
        } catch {
            alert = AlertItem(title: L("Ouverture impossible", "Cannot open file"), message: error.localizedDescription)
        }
    }

    func saveFleetPanel() {
        let panel = NSSavePanel()
        panel.title = L("Enregistrer le parc de vidéoprojecteurs", "Save Projector Fleet")
        panel.nameFieldStringValue = "\(L("Plateau", "Stage")).\(FleetDocument.fileExtension)"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let doc = FleetDocument(
                    showTitle: url.deletingPathExtension().lastPathComponent,
                    scanRange: fleet.rangeInput,
                    projectors: fleet.projectors
                )
                let data = try doc.encodeJSON()
                try data.write(to: url, options: .atomic)
                flash(L("Parc enregistré dans \(url.lastPathComponent)", "Fleet saved to \(url.lastPathComponent)"))
            } catch {
                alert = AlertItem(title: L("Enregistrement impossible", "Cannot save file"), message: error.localizedDescription)
            }
        }
    }

    func copyExport() {
        let list = exportVisibleOnly ? fleet.visibleProjectors : fleet.projectors
        let text = FleetExporter.render(list, format: exportFormat)
        Self.copyToPasteboard(text)
        showExport = false
        flash(L("Export copié dans le presse-papiers", "Export copied to clipboard"))
    }

    func saveExport() {
        let list = exportVisibleOnly ? fleet.visibleProjectors : fleet.projectors
        let text = FleetExporter.render(list, format: exportFormat)
        let panel = NSSavePanel()
        panel.title = L("Exporter la fiche des vidéoprojecteurs", "Export Projector Sheet")
        panel.nameFieldStringValue = "\(L("Videoprojecteurs", "Projectors")).\(exportFormat.defaultExtension)"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try Data(text.utf8).write(to: url, options: .atomic)
                showExport = false
                flash(L("Export enregistré dans \(url.lastPathComponent)", "Export saved to \(url.lastPathComponent)"))
            } catch {
                alert = AlertItem(title: L("Export impossible", "Cannot export"), message: error.localizedDescription)
            }
        }
    }
}
