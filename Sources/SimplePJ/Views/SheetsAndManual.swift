import SimplePJCore
import SwiftUI

// MARK: - Add Projector Sheet

struct AddProjectorSheet: View {
    @Bindable var model: AppModel
    @State private var ip: String = ""
    @State private var port: String = "4352"
    @State private var label: String = ""
    @State private var password: String = ""
    @State private var notes: String = ""
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(L("Ajouter un vidéoprojecteur PJLink", "Add PJLink Projector"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)

            FieldRow(L("Adresse IPv4", "IPv4 Address"), width: 105) {
                TextField("192.168.1.21", text: $ip)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            FieldRow(L("Port TCP", "TCP Port"), width: 105) {
                TextField("4352", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 90)
            }
            FieldRow(L("Nom & #groupes", "Name & #groups"), width: 105) {
                TextField(L("Face Cour #face #cour", "Stage Left #front #left"), text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            FieldRow(L("Mot de passe", "Password"), width: 105) {
                TextField(L("Optionnel (ex. panasonic, admin)", "Optional (e.g. panasonic, admin)"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            FieldRow(L("Notes régie", "Stage notes"), width: 105) {
                TextField(L("Optique, circuit, serveur vidéo…", "Lens, circuit, media server…"), text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger.swiftUI)
            }

            HStack {
                Button(L("Annuler", "Cancel")) { model.showAddProjector = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: L("Ajouter & Interroger", "Add & Poll"), symbol: "plus", prominent: true) {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }

    private func submit() {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard IPv4Range.uint32(from: cleanIP) != nil else {
            error = L("Adresse IPv4 invalide (ex. 192.168.1.21).", "Invalid IPv4 address (e.g. 192.168.1.21).")
            return
        }
        let p = UInt16(port.trimmingCharacters(in: .whitespaces)) ?? kPJLinkDefaultPort
        model.fleet.addProjector(ip: cleanIP, port: p, label: label, password: password, notes: notes)
        model.showAddProjector = false
    }
}

// MARK: - Power Off Safety Confirmation Sheet

struct PowerConfirmSheet: View {
    let request: AppModel.PowerConfirmRequest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.standby.swiftUI)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Mettre en veille \(Format.count(request.targets.count, "vidéoprojecteur")) ?", "Put \(request.targets.count) projector\(request.targets.count > 1 ? "s" : "") into standby?"))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text(L("Pour un noir plateau immédiat sans couper la lampe/laser, utilisez plutôt « Fermer le volet (Noir) » (⌘B).", "For an instant stage blackout without powering down the lamp/laser, use \"Close Shutter (Blackout)\" (⌘B) instead."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(request.targets.prefix(6)) { pj in
                    HStack(spacing: 8) {
                        Circle().fill(Theme.statusColor(pj).swiftUI).frame(width: 6, height: 6)
                        Text(pj.displayTitle).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.text.swiftUI)
                        Spacer()
                        Text(pj.endpointLabel).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textDim.swiftUI)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))

            Text(L("Astuce : maintenez la touche ⌥ (Option) en cliquant sur « Veille » pour ignorer cette confirmation.", "Tip: hold ⌥ (Option) while clicking \"Standby\" to bypass this confirmation."))
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint.swiftUI)

            HStack {
                Button(L("Annuler", "Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: L("Fermer le volet (Noir) plutôt", "Close Shutter (Blackout) Instead"), symbol: "eye.slash.fill", tint: Theme.accent.swiftUI) {
                    onCancel()
                }
                TextButton(title: L("Éteindre (POWR 0)", "Power Off (POWR 0)"), symbol: "power", destructive: true) {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Exporter la fiche du parc", "Export Fleet Technical Sheet"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)

            SectionHeader("Format")
            VStack(spacing: 4) {
                ForEach(FleetExportFormat.allCases) { format in
                    let active = model.exportFormat == format
                    Button { model.exportFormat = format } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: active ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(active ? Theme.accent.swiftUI : Theme.textFaint.swiftUI)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.text.swiftUI)
                                Text(format.detail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(active ? Theme.laneSelected.swiftUI : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            SectionHeader(L("Périmètre", "Scope"))
            HStack(spacing: 6) {
                scopeButton(L("Tous les projecteurs (\(model.fleet.projectors.count))", "All Projectors (\(model.fleet.projectors.count))"), selected: !model.exportVisibleOnly) {
                    model.exportVisibleOnly = false
                }
                scopeButton(L("Vue filtrée (\(model.fleet.visibleProjectors.count))", "Filtered View (\(model.fleet.visibleProjectors.count))"), selected: model.exportVisibleOnly) {
                    model.exportVisibleOnly = true
                }
            }

            HStack {
                Button(L("Annuler", "Cancel")) { model.showExport = false }.keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: L("Copier", "Copy"), symbol: "doc.on.doc") { model.copyExport() }
                TextButton(title: L("Enregistrer…", "Save…"), symbol: "square.and.arrow.down", prominent: true) { model.saveExport() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 450)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }

    private func scopeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Theme.background.swiftUI : Theme.textDim.swiftUI)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Theme.accent.swiftUI : Color.white.opacity(0.05)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OSC & HTTP Reference Sheet

struct OSCGuideSheet: View {
    @Bindable var model: AppModel
    let close: () -> Void

    private static var oscExamples: [(String, String, String)] {
        [
            ("/simplepj/all/shutter", L("1 ou 0", "1 or 0"), L("Fermer (1 = Noir plateau) ou ouvrir (0) tous les volets", "Close (1 = Stage Blackout) or open (0) all shutters")),
            ("/simplepj/all/power", L("1 ou 0", "1 or 0"), L("Allumer (1) ou mettre en veille (0) tout le parc", "Power on (1) or standby (0) entire fleet")),
            ("/simplepj/all/freeze", L("1 ou 0", "1 or 0"), L("Geler (1) ou dégeler (0) l'image sur tout le parc (Classe 2)", "Freeze (1) or unfreeze (0) image on entire fleet (Class 2)")),
            ("/simplepj/all/input", L("\"31\" ou \"HDMI 1\"", "\"31\" or \"HDMI 1\""), L("Basculer l'entrée de tous les projecteurs", "Switch input on all projectors")),
            ("/simplepj/group/face/shutter", L("1 ou 0", "1 or 0"), L("Fermer ou ouvrir les volets du groupe #face", "Close or open shutters of group #face")),
            ("/simplepj/group/cyclo/shutter", L("1 ou 0", "1 or 0"), L("Fermer ou ouvrir les volets du groupe #cyclo", "Close or open shutters of group #cyclo")),
            ("/simplepj/pj/1/shutter", L("1 ou 0", "1 or 0"), L("Piloter le projecteur n°1 (ou par nom / IP)", "Control projector #1 (or by name / IP)")),
            ("/simplepj/pj/face-cour/input", "\"52\"", L("Basculer l'entrée du projecteur nommé « Face Cour »", "Switch input on projector named \"Face Cour\"")),
            ("/simplepj/pj/1/raw", "\"%1LAMP ?\"", L("Envoyer une commande PJLink brute", "Send raw PJLink command")),
            ("/simplepj/refresh", L("(aucun)", "(none)"), L("Relancer une interrogation immédiate du parc", "Trigger an immediate fleet poll")),
        ]
    }

    private static let mcpConfigJSON = """
    {
      "mcpServers": {
        "simplepj": {
          "command": "/Applications/SimplePJ.app/Contents/MacOS/simplepj-mcp"
        }
      }
    }
    """

    var body: some View {
        let oscPort = model.fleet.oscServer?.port ?? kSimplePJDefaultOSCInPort
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Pilotage OSC, API HTTP & Serveur MCP — SimplePJ", "OSC Control, HTTP API & MCP Server — SimplePJ"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text(L("Pilotage des vidéoprojecteurs depuis OSCScore, Montage, eMotion, QLab, Chataigne ou un agent MCP.", "Control projectors from OSCScore, Montage, eMotion, QLab, Chataigne, or an MCP agent."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                Spacer()
                Chip(text: "OSC UDP :\(oscPort)", tint: Theme.osc.swiftUI, filled: true)
                Chip(text: "HTTP/MCP :\(model.fleet.httpPort)", tint: Theme.tcp.swiftUI)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            SectionHeader(L("Adresses OSC entrantes (cliquer pour copier)", "Incoming OSC Addresses (click to copy)"))
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(Self.oscExamples, id: \.0) { addr, arg, desc in
                        Button {
                            AppModel.copyToPasteboard(addr)
                            model.flash(L("Copié : \(addr)", "Copied: \(addr)"))
                        } label: {
                            HStack(spacing: 10) {
                                Text(addr)
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.osc.swiftUI)
                                    .frame(width: 225, alignment: .leading)
                                Text(arg)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(Theme.accent.swiftUI)
                                    .frame(width: 105, alignment: .leading)
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textFaint.swiftUI)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 235)

            SectionHeader(L("Serveur MCP (simplepj-mcp), AppleScript, CLI & API HTTP", "MCP Server (simplepj-mcp), AppleScript, CLI & HTTP API"))
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "MCP (stdio) : /Applications/SimplePJ.app/Contents/MacOS/simplepj-mcp  (simplepj_state, simplepj_shutter, simplepj_input, simplepj_snapshot…)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.tcp.swiftUI)
                    .textSelection(.enabled)
                Text(verbatim: "AppleScript : tell application \"SimplePJ\" to AvMute 0   |   PowerOn 0   |   PowerOff 0   |   Inpt {31, 0}")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.text.swiftUI)
                    .textSelection(.enabled)
                Text(verbatim: "CLI : SimplePJ --cmd all shutter-close   |   HTTP : POST http://127.0.0.1:\(model.fleet.httpPort)/v1/shutter {\"target\":\"all\",\"closed\":true}")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .textSelection(.enabled)
            }

            HStack {
                TextButton(title: L("Copier config MCP JSON", "Copy MCP JSON Config"), symbol: "doc.on.doc", compact: true) {
                    AppModel.copyToPasteboard(Self.mcpConfigJSON)
                    model.flash(L("Configuration MCP copiée", "MCP configuration copied"))
                }
                Spacer()
                Button(L("Fermer", "Close"), action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 760)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }
}

// MARK: - About Sheet

struct AboutSheet: View {
    @Bindable var model: AppModel
    let openHelp: () -> Void
    let close: () -> Void
    @State private var copiedVersion = false

    private struct Feature: Identifiable {
        var id: String { title }
        let icon: String
        let tint: NSColor
        let title: String
        let detail: String
    }

    private static var features: [Feature] {
        [
            Feature(
                icon: "sun.max.fill",
                tint: Theme.accent,
                title: L("PJLink Classe 1 & Classe 2 complet", "Full PJLink Class 1 & Class 2"),
                detail: L("Volet optique (AVMT), alimentation, entrées nommées (INNM), gel d'image (FREZ), résolution du signal (IRES), heures lampe/filtre et diagnostic 6 capteurs (ERST).", "Optical shutter (AVMT), power, named inputs (INNM), freeze (FREZ), signal resolution (IRES), lamp/filter hours, and 6-sensor diagnostics (ERST).")
            ),
            Feature(
                icon: "dot.radiowaves.left.and.right",
                tint: Theme.alive,
                title: L("Découverte éclair (:4352) & Déverrouillage", "Fast Discovery (:4352) & Auto-Unlock"),
                detail: L("Scan TCP :4352 parallèle d'un /24 en ~1,5 s + broadcast UDP %2SRCH + table ARP MAC + test automatique des mots de passe PJLink d'usine.", "Parallel TCP :4352 /24 scan in ~1.5 s + UDP %2SRCH broadcast + ARP MAC lookup + automatic factory PJLink password probing.")
            ),
            Feature(
                icon: "antenna.radiowaves.left.and.right",
                tint: Theme.osc,
                title: L("Groupes #tags, OSC, HTTP & MCP", "#tag Groups, OSC, HTTP & MCP"),
                detail: L("Groupement des projecteurs (#face, #cyclo, #sol) et pilotage au clavier, en OSC (:9130), HTTP (/v1 :17930), AppleScript ou via le serveur MCP (simplepj-mcp).", "Group projectors (#front, #cyclo, #floor) and control them via keyboard, OSC (:9130), HTTP (/v1 :17930), AppleScript, or the MCP server (simplepj-mcp).")
            ),
            Feature(
                icon: "play.tv",
                tint: Theme.tcp,
                title: L("Simulateur de plateau & Import", "Stage Simulator & Import"),
                detail: L("4 serveurs TCP PJLink Classe 2 embarqués sur 127.0.0.1 pour préparer les conduites hors plateau, et import en 1 clic depuis ProjectorManager.", "4 embedded PJLink Class 2 TCP servers on 127.0.0.1 for offline show preparation, plus 1-click import from ProjectorManager.")
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: 0x222731)), Color(nsColor: NSColor(hex: 0x0E1014))], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
                    ProjectorHeroGraphic(active: false, size: 58)
                }
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("SimplePJ")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        Button {
                            AppModel.copyToPasteboard(AppVersion.current.cliLine)
                            copiedVersion = true
                        } label: {
                            Text(copiedVersion ? L("copié", "copied") : AppVersion.current.shortLabel)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.background.swiftUI)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent.swiftUI))
                        }
                        .buttonStyle(.plain)
                    }
                    Text(L("Contrôleur de vidéoprojecteurs PJLink natif ultra-léger — volets, entrées, groupes #tags, simulateur & OSC/MCP", "Ultra-lightweight native PJLink projector controller — shutters, inputs, #tag groups, simulator & OSC/MCP"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        pill(icon: "bolt.fill", text: "PJLink Cl. 1 & 2", tint: Theme.accent)
                        pill(icon: "waveform.path", text: "OSC UDP :\(model.fleet.oscServer?.port ?? kSimplePJDefaultOSCInPort)", tint: Theme.osc)
                        pill(icon: "network", text: "HTTP / MCP :\(model.fleet.httpPort)", tint: Theme.tcp)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("POINTS FORTS", "HIGHLIGHTS"))
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textFaint.swiftUI)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Self.features) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.tint.swiftUI)
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.swiftUI.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Theme.text.swiftUI)
                                Text(item.detail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }
                }
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Adrien Mondot ·")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.text.swiftUI)
                        Button {
                            if let url = URL(string: "https://adrien-m.net") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("cie Adrien M")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .underline()
                                Text("(adrien-m.net)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 9.5))
                            }
                            .foregroundStyle(Theme.accent.swiftUI)
                        }
                        .buttonStyle(.plain)
                        .help("https://adrien-m.net")
                    }
                    Text(L("Licence publique générale GNU (GPL v3+). Zéro dépendance externe, aucune télémétrie.", "GNU General Public License (GPL v3+). Zero external dependencies, zero telemetry."))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint.swiftUI)
                }
                Spacer()
                Button {
                    close()
                    DispatchQueue.main.async {
                        model.showUpdater = true
                        model.updater.checkForUpdates(silent: false)
                    }
                } label: {
                    Label(
                        model.updater.availableRelease.map { L("↑ MAJ v\($0.version)", "↑ Update v\($0.version)") }
                            ?? L("Mises à jour…", "Check for Updates…"),
                        systemImage: "arrow.down.circle"
                    )
                    .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.updater.availableRelease != nil ? Theme.accent.swiftUI : Theme.textDim.swiftUI)

                Button { close(); openHelp() } label: {
                    Label(L("Guide (⌘?)", "Guide (⌘?)"), systemImage: "book.closed").font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textDim.swiftUI)
                Button("OK", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 650)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }

    private func pill(icon: String, text: String, tint: NSColor) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(tint.swiftUI)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.swiftUI.opacity(0.12)))
    }
}

// MARK: - Shortcuts Sheet

struct ShortcutsSheet: View {
    let close: () -> Void

    static var groups: [(String, [(String, String)])] {
        [
            (L("Plateau, Volets & Optique", "Stage, Shutters & Lens"), [
                ("⌘B", L("NOIR PLATEAU : Fermer les volets de la cible (AVMT 31)", "STAGE BLACKOUT: Close target shutters (AVMT 31)")),
                ("⇧⌘B", L("Ouvrir les volets de la cible (AVMT 30)", "Open target shutters (AVMT 30)")),
                ("⌃⌘F", L("Geler / Dégeler l'image sur la cible (FREZ)", "Toggle image freeze on target (FREZ)")),
                ("⌘G", L("Afficher / Masquer la grille de calage (Optoma ZU / Epson EB-L)", "Toggle alignment grid (Optoma ZU / Epson EB-L)")),
                ("↑ ↓ ← →", L("Lens Shift H/V du projecteur sélectionné (Optoma / Epson)", "Lens Shift H/V on selected projector (Optoma / Epson)")),
                ("⇧ + ↑ ↓ ← →", L("Lens Shift rapide (×3 pas moteur)", "Fast Lens Shift (×3 motor steps)")),
                (L("⌥ + Clic Veille", "⌥ + Click Standby"), L("Mettre en veille sans fenêtre de confirmation", "Put into standby without confirmation dialog")),
            ]),
            (L("Découverte & Parc", "Discovery & Fleet"), [
                ("⇧⌘D", L("Découvrir les projecteurs PJLink (:4352) sur le réseau", "Discover PJLink projectors (:4352) on the network")),
                ("⌘.", L("Arrêter la découverte en cours", "Stop active discovery")),
                ("⌘N", L("Ajouter un vidéoprojecteur par IP", "Add projector by IP")),
                ("⇧⌘I", L("Importer depuis ProjectorManager", "Import from ProjectorManager")),
                ("⌘R", L("Actualiser l'état PJLink de tout le parc", "Refresh PJLink status of entire fleet")),
                ("⌘O / ⌘S", L("Ouvrir / Enregistrer un fichier de parc (.simplepj)", "Open / Save a fleet file (.simplepj)")),
                ("⌘E", L("Exporter la fiche technique (TXT, CSV, JSON)", "Export technical sheet (TXT, CSV, JSON)")),
            ]),
            (L("Navigation & Affichage", "Navigation & View"), [
                ("⌘1 / ⌘2", L("Basculer entre la vue Plateau (cartes) et la vue Liste", "Switch between Stage view (cards) and List view")),
                ("⌘A", L("Tout sélectionner", "Select all")),
                ("⌘F", L("Filtrer par nom, #tag, IP ou modèle", "Filter by name, #tag, IP, or model")),
                ("⏎", L("Renommer / #grouper le projecteur sélectionné", "Rename / #tag selected projector")),
                ("⌥⌘S / ⌥⌘I", L("Afficher ou masquer la barre latérale / l'inspecteur", "Show or hide sidebar / inspector")),
                ("⌥⌘L", L("Afficher ou masquer la console protocole PJLink", "Show or hide PJLink protocol console")),
            ]),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("Raccourcis clavier — SimplePJ", "Keyboard Shortcuts — SimplePJ"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                Button(L("Fermer", "Close"), action: close).keyboardShortcut(.defaultAction)
            }
            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)
            HStack(alignment: .top, spacing: 16) {
                ForEach(Self.groups, id: \.0) { groupTitle, items in
                    VStack(alignment: .leading, spacing: 7) {
                        SectionHeader(groupTitle)
                        ForEach(items, id: \.0) { key, label in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(key)
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.accent.swiftUI)
                                    .frame(width: 92, alignment: .leading)
                                Text(label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(width: 860)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Multi-Section Help Manual Sheet (Simple family layout)

struct HelpManualSheet: View {
    let openShortcuts: () -> Void
    let close: () -> Void

    enum SectionID: String, CaseIterable, Identifiable {
        case quickStart
        case stageAndGroups
        case pjlinkProtocol
        case projectorManager
        case oscAndMCP

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quickStart: return L("Démarrage rapide", "Quick Start")
            case .stageAndGroups: return L("Plateau & Groupes", "Stage & Groups")
            case .pjlinkProtocol: return L("PJLink Classe 1 & 2", "PJLink Class 1 & 2")
            case .projectorManager: return "ProjectorManager"
            case .oscAndMCP: return L("OSC, API HTTP & MCP", "OSC, HTTP API & MCP")
            }
        }

        var icon: String {
            switch self {
            case .quickStart: return "play.circle"
            case .stageAndGroups: return "sun.max.fill"
            case .pjlinkProtocol: return "bolt.horizontal.circle"
            case .projectorManager: return "square.and.arrow.down"
            case .oscAndMCP: return "antenna.radiowaves.left.and.right"
            }
        }
    }

    @State private var selectedSection: SectionID = .quickStart

    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent.swiftUI)
                Text(L("Guide d’utilisation — SimplePJ", "User Guide — SimplePJ"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                Text(AppVersion.current.shortLabel)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.header.swiftUI)

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            // Sidebar + Content
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 204)
                Rectangle().fill(Theme.separator.swiftUI).frame(width: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionContent(selectedSection)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Theme.panel.swiftUI)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            // Footer
            HStack {
                Button {
                    close()
                    openShortcuts()
                } label: {
                    Label(L("Raccourcis clavier (⌘/)", "Keyboard Shortcuts (⌘/)"), systemImage: "command")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textDim.swiftUI)

                Spacer()

                Button("OK", action: close)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.header.swiftUI)
        }
        .frame(width: 760, height: 520)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(SectionID.allCases) { section in
                let isSelected = selectedSection == section
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? Theme.accent.swiftUI : Theme.textDim.swiftUI)
                            .frame(width: 16)
                        Text(section.title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Theme.laneSelected.swiftUI : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(10)
        .background(Theme.background.swiftUI)
    }

    @ViewBuilder
    private func sectionContent(_ section: SectionID) -> some View {
        switch section {
        case .quickStart:
            quickStartSection
        case .stageAndGroups:
            stageAndGroupsSection
        case .pjlinkProtocol:
            pjlinkProtocolSection
        case .projectorManager:
            projectorManagerSection
        case .oscAndMCP:
            oscAndMCPSection
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: L("Démarrage rapide", "Quick Start"),
                subtitle: L("Découvrir, nommer et piloter un parc de vidéoprojecteurs PJLink en quatre étapes.", "Discover, name, and control a fleet of PJLink projectors in four steps.")
            )
            numberedStep(
                number: "1",
                title: L("Découvrir le réseau (:4352) ou lancer le plateau simulé", "Discover the network (:4352) or launch the simulated stage rig"),
                body: L("Choisir l'interface réseau en haut à gauche puis cliquer sur « Découvrir » (⇧⌘D) : SimplePJ sonde un sous-réseau /24 complet en ~1,5 s. Hors plateau, cliquer sur « Simuler un plateau (4 VP) » pour lancer 4 serveurs PJLink Classe 2 réels sur 127.0.0.1.", "Pick a network interface at the top left and click \"Discover\" (⇧⌘D): SimplePJ probes a full /24 subnet in ~1.5 s. Offline, click \"Simulate Stage Rig (4 PJ)\" to launch 4 real PJLink Class 2 TCP servers on 127.0.0.1.")
            )
            numberedStep(
                number: "2",
                title: L("Déverrouiller les mots de passe d'usine en un clic", "Unlock factory passwords in one click"),
                body: L("Si un projecteur répond PJLINK 1 (mot de passe requis), cliquer sur « Tester mots de passe » : SimplePJ teste automatiquement les mots de passe d'usine courants (panasonic, admin, pjlink, JBMIA, 0000…).", "If a projector answers PJLINK 1 (password required), click \"Test Passwords\": SimplePJ automatically probes common factory passwords (panasonic, admin, pjlink, JBMIA, 0000…).")
            )
            numberedStep(
                number: "3",
                title: L("Basculer entre la vue Plateau (⌘1) et la vue Liste (⌘2)", "Switch between Stage View (⌘1) and List View (⌘2)"),
                body: L("La vue Plateau affiche de grandes cartes de régie ; la vue Liste embarque des commutateurs directs [ON | OFF], [OUV | NOIR], Mute Audio, un menu déroulant d'entrée vidéo et un popover de diagnostic Lampe / ERST sur chaque ligne.", "Stage View displays large show-control cards; List View embeds inline [ON | OFF], [OPEN | BLK], Audio Mute switches, an input dropdown menu, and a Lamp / ERST diagnostics popover on every row.")
            )
            numberedStep(
                number: "4",
                title: L("Enregistrer (.simplepj) ou exporter la fiche technique (⌘E)", "Save (.simplepj) or export the technical sheet (⌘E)"),
                body: L("Enregistrer le parc en .simplepj (⌘S) ou exporter une fiche technique complète (TXT, CSV, JSON, IP:port) incluant modèles, numéros de série, entrées et heures de lampe.", "Save the fleet as .simplepj (⌘S) or export a complete technical sheet (TXT, CSV, JSON, IP:port) with models, serial numbers, inputs, and lamp hours.")
            )
            calloutBox(
                icon: "eye.slash.fill",
                tint: Theme.accent,
                title: L("Volet optique (Noir plateau) vs Extinction", "Optical Shutter (Stage Blackout) vs Power Off"),
                text: L("En spectacle, utilisez toujours « VOLET FERMÉ · NOIR » (AVMT 31, raccourci ⌘B) pour couper le faisceau instantanément. L'extinction (« Veille », POWR 0) demande une confirmation de sécurité (maintenez ⌥ pour contourner).", "During a show, always use \"SHUTTER CLOSED · BLACKOUT\" (AVMT 31, shortcut ⌘B) to cut the beam instantly. Powering off (\"Standby\", POWR 0) asks for safety confirmation (hold ⌥ to bypass).")
            )
        }
    }

    private var stageAndGroupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: L("Conduite de plateau & Groupes #tags", "Stage Control & #tag Groups"),
                subtitle: L("Piloter un projecteur, une sélection multiple ou un groupe de plateau d'un seul geste.", "Control a single projector, a multi-selection, or a stage group in a single action.")
            )
            bulletList([
                (L("Groupes automatiques par #tags", "Automatic #tag groups"), L("Ajouter des #tags directement dans le nom d'un projecteur (ex. « Face Cour #face #cour », « Cyclo #cyclo »). Les groupes apparaissent automatiquement dans la barre latérale gauche : un clic filtre la vue, et un clic droit permet d'ouvrir/fermer les volets de tout le groupe.", "Add #tags directly in a projector's name (e.g. \"Stage Left #front #left\", \"Cyclo #cyclo\"). Groups appear automatically in the left sidebar: click to filter, or right-click to open/close shutters for the entire group.")),
                (L("Barre maîtresse de plateau", "Stage Master Bar"), L("Les boutons « NOIR · Fermer volets » (⌘B), « Ouvrir volets » (⇧⌘B), « Allumer », « Veille », « Gel » et « Entrée… » agissent sur la sélection active, le groupe filtré ou tout le parc.", "The \"BLACKOUT · Close Shutters\" (⌘B), \"Open Shutters\" (⇧⌘B), \"Power On\", \"Standby\", \"Freeze\", and \"Input…\" buttons act on the active selection, filtered group, or entire fleet.")),
                (L("Wake-on-LAN & Interface Web", "Wake-on-LAN & Web UI"), L("SimplePJ relève automatiquement l'adresse MAC de chaque projecteur dans la table ARP macOS pour permettre le réveil réseau (Wake-on-LAN, ⇧⌘W) et l'ouverture directe de l'interface HTTP du projecteur.", "SimplePJ automatically reads each projector's MAC address from the macOS ARP table to support network wake-up (Wake-on-LAN, ⇧⌘W) and direct opening of the projector's HTTP web interface."))
            ])
        }
    }

    private var pjlinkProtocolSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: L("Protocole PJLink Classe 1 & Classe 2", "PJLink Class 1 & Class 2 Protocol"),
                subtitle: L("Commandes normalisées JBMIA sur TCP/UDP 4352 et console temps réel (⌥⌘L).", "Standardized JBMIA commands over TCP/UDP 4352 and real-time console (⌥⌘L).")
            )
            bulletList([
                (L("Classe 1 (%1) — Alimentation, Volet, Entrées, Lampes, ERST", "Class 1 (%1) — Power, Shutter, Inputs, Lamps, ERST"), L("Support complet de POWR (0/1/2/3), AVMT (10/11 vidéo, 20/21 audio, 30/31 volet complet), INPT, INST, LAMP (multi-lampes/laser), ERST (6 capteurs : Ventilateur, Lampe, Température, Capot, Filtre, Autre), NAME, INF1, INF2, INFO, CLSS.", "Full support for POWR (0/1/2/3), AVMT (10/11 video, 20/21 audio, 30/31 full shutter), INPT, INST, LAMP (multi-lamp/laser), ERST (6 sensors: Fan, Lamp, Temperature, Cover, Filter, Other), NAME, INF1, INF2, INFO, CLSS.")),
                (L("Classe 2 (%2) — Gel, Noms d'entrées, Résolutions, Série", "Class 2 (%2) — Freeze, Input Names, Resolutions, Serial"), L("Support de %2FREZ (gel d'image), %2INNM ?<code> (vrais noms des entrées : HDMI 1, HDBaseT, SDI), %2IRES / %2RRES (résolution entrante et native), %2SNUM (numéro de série), %2SVER (firmware), %2FILT (heures filtre), %2RLMP / %2RFIL.", "Support for %2FREZ (freeze), %2INNM ?<code> (input names: HDMI 1, HDBaseT, SDI), %2IRES / %2RRES (input and native resolution), %2SNUM (serial number), %2SVER (firmware), %2FILT (filter hours), %2RLMP / %2RFIL.")),
                (L("Authentification MD5 & Reconnexion automatique", "MD5 Authentication & Auto-Reconnect"), L("Gestion native du défi MD5 (PJLINK 1 <salt>) et reconnexion TCP transparente pour les projecteurs qui ferment la socket après chaque commande.", "Native MD5 challenge-response (PJLINK 1 <salt>) and transparent TCP reconnection for projectors that close the socket after each command."))
            ])
        }
    }

    private var projectorManagerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: L("Migration & Compatibilité ProjectorManager", "ProjectorManager Migration & Compatibility"),
                subtitle: L("Compatibilité directe avec les configurations et scripts de ProjectorManager (SIGMASIX).", "Direct compatibility with workflows and scripts from ProjectorManager (SIGMASIX).")
            )
            bulletList([
                (L("Import en 1 clic des projecteurs enregistrés (⇧⌘I)", "1-click import of saved projectors (⇧⌘I)"), L("SimplePJ lit automatiquement les préférences de ProjectorManager (ch.sigmasix.ProjectorManager) et importe toutes les adresses IP et mots de passe d'un seul clic.", "SimplePJ automatically reads ProjectorManager preferences (ch.sigmasix.ProjectorManager) and imports all IP addresses and passwords in a single click.")),
                (L("Contrôles directs en ligne en vue Liste (⌘2)", "Inline direct controls in List View (⌘2)"), L("La vue Liste affiche les commutateurs [ON | OFF], [OUV | NOIR], Mute Audio, le menu déroulant d'entrée vidéo et le popover Lampe / ERST directement sur chaque ligne.", "Enjoy fast list-view operation with inline [ON | OFF], [OPEN | BLK], Audio Mute switches, video input dropdown, and Lamp / ERST popover directly on every row.")),
                (L("Dictionnaire AppleScript 100 % compatible", "100% compatible AppleScript dictionary"), L("Les commandes AppleScript PowerOn, PowerOff, AvMute, AvUnMute et Inpt {code, index} fonctionnent à l'identique dans QLab ou éditeur de scripts en ciblant \"SimplePJ\".", "AppleScript commands PowerOn, PowerOff, AvMute, AvUnMute, and Inpt {code, index} work identically in QLab or Script Editor when targeting \"SimplePJ\"."))
            ])
        }
    }

    private var oscAndMCPSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: L("OSC, API HTTP & Serveur MCP", "OSC, HTTP API & MCP Server"),
                subtitle: L("Interfaçage temps réel avec OSCScore, Montage, eMotion, QLab et agents IA.", "Real-time integration with OSCScore, Montage, eMotion, QLab, and AI agents.")
            )
            bulletList([
                (L("Serveur OSC UDP (:9130 par défaut)", "OSC UDP Server (:9130 by default)"), "/simplepj/all/shutter <0|1>, /simplepj/all/power <0|1>, /simplepj/all/freeze <0|1>, /simplepj/all/input <code|name>, /simplepj/group/<tag>/shutter <0|1>, /simplepj/pj/<index|ip|name>/shutter <0|1>, /simplepj/refresh."),
                (L("API HTTP JSON locale (127.0.0.1:17930/v1)", "Local JSON HTTP API (127.0.0.1:17930/v1)"), L("Expose GET /v1/state, GET /v1/projectors, GET /v1/help, GET /v1/snapshot.png, POST /v1/shutter, POST /v1/power, POST /v1/input, POST /v1/freeze, POST /v1/discover, POST /v1/projectors, POST /v1/command.", "Exposes GET /v1/state, GET /v1/projectors, GET /v1/help, GET /v1/snapshot.png, POST /v1/shutter, POST /v1/power, POST /v1/input, POST /v1/freeze, POST /v1/discover, POST /v1/projectors, POST /v1/command.")),
                (L("Serveur MCP embarqué (simplepj-mcp)", "Embedded MCP Server (simplepj-mcp)"), L("Le binaire compagnon /Applications/SimplePJ.app/Contents/MacOS/simplepj-mcp expose 11 outils MCP (simplepj_state, simplepj_projectors, simplepj_shutter, simplepj_power, simplepj_input, simplepj_freeze, simplepj_discover, simplepj_add_projector, simplepj_command, simplepj_snapshot) sur stdio.", "The companion binary /Applications/SimplePJ.app/Contents/MacOS/simplepj-mcp exposes 11 MCP tools (simplepj_state, simplepj_projectors, simplepj_shutter, simplepj_power, simplepj_input, simplepj_freeze, simplepj_discover, simplepj_add_projector, simplepj_command, simplepj_snapshot) over stdio."))
            ])
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim.swiftUI)
            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1).padding(.top, 6)
        }
    }

    private func numberedStep(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.accent.swiftUI)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.accent.swiftUI.opacity(0.14)))
                .overlay(Circle().strokeBorder(Theme.accent.swiftUI.opacity(0.35), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Text(body)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private func bulletList(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.0) { title, detail in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Theme.accent.swiftUI).frame(width: 5, height: 5).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        Text(detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textDim.swiftUI)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(1.5)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.lane.swiftUI))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func calloutBox(icon: String, tint: NSColor, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint.swiftUI)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.swiftUI.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.swiftUI.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Preferences View

struct PreferencesView: View {
    @Bindable var model: AppModel
    @State private var oscPortText: String = ""
    @State private var httpPortText: String = ""

    var body: some View {
        @Bindable var fleet = model.fleet
        @Bindable var updater = model.updater
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(L("Langue & Surveillance PJLink", "Language & PJLink Polling"))
            FieldRow(L("Langue", "Language"), width: 170) {
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            FieldRow(L("Cadence de rafraîchissement", "Refresh Cadence"), width: 170) {
                Picker("", selection: $fleet.pollInterval) {
                    ForEach(PollInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            HStack(spacing: 10) {
                Toggle(L("Vérifier les mises à jour au lancement", "Check for updates on launch"), isOn: $updater.autoCheckOnLaunch)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                TextButton(title: L("Vérifier maintenant…", "Check Now…"), symbol: "arrow.down.circle", compact: true) {
                    model.showUpdater = true
                    model.updater.checkForUpdates(silent: false)
                }
            }
            Divider().overlay(Theme.separator.swiftUI)
            SectionHeader(L("Ports OSC, API HTTP & MCP", "OSC, HTTP API & MCP Ports"))
            FieldRow(L("Port OSC entrant (UDP)", "Incoming OSC Port (UDP)"), width: 170) {
                HStack(spacing: 6) {
                    TextField("9130", text: $oscPortText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text.swiftUI)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 80)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                        .onSubmit { applyPorts() }
                    TextButton(title: L("Appliquer", "Apply"), compact: true) { applyPorts() }
                }
            }
            FieldRow("Port HTTP / MCP (127.0.0.1)", width: 170) {
                HStack(spacing: 6) {
                    TextField("17930", text: $httpPortText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text.swiftUI)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 80)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                        .onSubmit { applyPorts() }
                    Text(verbatim: "/v1")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
            }
            Divider().overlay(Theme.separator.swiftUI)
            SectionHeader(L("Affichage", "Display"))
            Toggle(L("Barre latérale des groupes", "Groups Sidebar"), isOn: $model.showSidebar)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Toggle(L("Inspecteur détaillé", "Detailed Inspector"), isOn: $model.showInspector)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Toggle(L("Console protocole PJLink", "PJLink Protocol Console"), isOn: $model.showConsoleDrawer)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Divider().overlay(Theme.separator.swiftUI)
            SectionHeader(L("Réseau & Confidentialité", "Network & Privacy"))
            Text(L("SimplePJ communique uniquement en local avec les vidéoprojecteurs (TCP/UDP 4352), les logiciels de régie (OSC :9130, HTTP 127.0.0.1:17930) et le serveur MCP local (simplepj-mcp). Aucune télémétrie, aucune connexion externe.", "SimplePJ communicates strictly locally with projectors (TCP/UDP 4352), show-control software (OSC :9130, HTTP 127.0.0.1:17930), and the local MCP server (simplepj-mcp). Zero telemetry, zero external connections."))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim.swiftUI)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 460)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
        .onAppear {
            oscPortText = "\(model.fleet.oscServer?.port ?? kSimplePJDefaultOSCInPort)"
            httpPortText = "\(model.fleet.httpPort)"
        }
    }

    private func applyPorts() {
        if let oscP = UInt16(oscPortText.trimmingCharacters(in: .whitespaces)), oscP > 0 {
            model.fleet.startOSCServer(port: oscP)
        }
        if let httpP = UInt16(httpPortText.trimmingCharacters(in: .whitespaces)), httpP > 0 {
            model.fleet.startHTTPServer(port: httpP)
        }
        model.flash(L("Ports OSC (:\(oscPortText)) et HTTP/MCP (:\(httpPortText)) mis à jour", "OSC (:\(oscPortText)) and HTTP/MCP (:\(httpPortText)) ports updated"))
    }
}

// MARK: - Rename Range Sheet

struct RenameRangeSheet: View {
    let range: SavedRange
    let onCommit: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Nommer la plage favorite", "Name Favorite Range"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)
            Text(range.range)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.textDim.swiftUI)
            TextField(L("Plateau, Régie, Tournée…", "Stage, Control Room, Tour…"), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text.swiftUI)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                .onSubmit { onCommit(name); dismiss() }
            HStack {
                Spacer()
                Button(L("Annuler", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Enregistrer", "Save")) { onCommit(name); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
        .onAppear { name = range.name ?? "" }
    }
}

// MARK: - Update Sheet (SimpleUpdater)

struct UpdateSheet: View {
    @Bindable var model: AppModel
    let close: () -> Void

    var body: some View {
        let updater = model.updater
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProjectorHeroGraphic(active: updater.state == .checking, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Mises à jour — SimplePJ", "Software Update — SimplePJ"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text(L("Version installée : v\(updater.currentVersion) (build \(updater.currentBuild))", "Installed version: v\(updater.currentVersion) (build \(updater.currentBuild))"))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                Spacer()
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            switch updater.state {
            case .idle, .checking:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L("Recherche de mises à jour en cours…", "Checking for updates…"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .padding(.vertical, 14)

            case .upToDate(let v):
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.alive.swiftUI)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("SimplePJ v\(v) est à jour.", "SimplePJ v\(v) is up to date."))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        Text(L("Cette version est la dernière disponible.", "This is the latest available version."))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                }
                .padding(.vertical, 10)

            case .updateAvailable(let rel):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Chip(text: L("NOUVELLE VERSION v\(rel.version)", "NEW VERSION v\(rel.version)"), tint: Theme.accent.swiftUI, filled: true)
                        Spacer()
                    }
                    ScrollView {
                        Text(rel.localizedNotes)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.text.swiftUI)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 70, maxHeight: 140)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }

            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Téléchargement de la mise à jour…", "Downloading update…"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text.swiftUI)
                    ProgressView(value: progress)
                        .tint(Theme.accent.swiftUI)
                }
                .padding(.vertical, 10)

            case .installing:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L("Vérification de la signature et installation…", "Verifying code signature and installing…"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text.swiftUI)
                }
                .padding(.vertical, 10)

            case .failed(let message):
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.warning.swiftUI)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Impossible de vérifier ou d'installer la mise à jour", "Could not check or install update"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim.swiftUI)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            }

            HStack {
                TextButton(title: L("Rechercher à nouveau", "Check Again"), symbol: "arrow.clockwise", compact: true) {
                    updater.checkForUpdates(silent: false)
                }
                Spacer()
                if case .updateAvailable(let rel) = updater.state {
                    Button(L("Plus tard", "Later"), action: close)
                    TextButton(title: L("Mettre à jour et relancer", "Update & Relaunch"), symbol: "arrow.down.circle.fill", prominent: true) {
                        updater.downloadAndInstall(rel)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(L("Fermer", "Close"), action: close)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
    }
}
