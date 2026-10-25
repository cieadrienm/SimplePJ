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
            Text("Ajouter un vidéoprojecteur PJLink")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)

            FieldRow("Adresse IPv4", width: 105) {
                TextField("192.168.1.21", text: $ip)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            FieldRow("Port TCP", width: 105) {
                TextField("4352", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 90)
            }
            FieldRow("Nom & #groupes", width: 105) {
                TextField("Face Cour #face #cour", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            FieldRow("Mot de passe", width: 105) {
                TextField("Optionnel (ex. panasonic, admin)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            FieldRow("Notes régie", width: 105) {
                TextField("Optique, circuit, serveur vidéo…", text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger.swiftUI)
            }

            HStack {
                Button("Annuler") { model.showAddProjector = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: "Ajouter & Interroger", symbol: "plus", prominent: true) {
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
            error = "Adresse IPv4 invalide (ex. 192.168.1.21)."
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
                    Text("Mettre en veille \(Format.count(request.targets.count, "vidéoprojecteur")) ?")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text("Pour un noir plateau immédiat sans couper la lampe/laser, utilisez plutôt « Fermer le volet (Noir) » (⌘B).")
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

            Text("Astuce : maintenez la touche ⌥ (Option) en cliquant sur « Veille » pour ignorer cette confirmation.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint.swiftUI)

            HStack {
                Button("Annuler", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: "Fermer le volet (Noir) plutôt", symbol: "eye.slash.fill", tint: Theme.accent.swiftUI) {
                    onCancel()
                }
                TextButton(title: "Éteindre (POWR 0)", symbol: "power", destructive: true) {
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
            Text("Exporter la fiche du parc")
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

            SectionHeader("Périmètre")
            HStack(spacing: 6) {
                scopeButton("Tous les projecteurs (\(model.fleet.projectors.count))", selected: !model.exportVisibleOnly) {
                    model.exportVisibleOnly = false
                }
                scopeButton("Vue filtrée (\(model.fleet.visibleProjectors.count))", selected: model.exportVisibleOnly) {
                    model.exportVisibleOnly = true
                }
            }

            HStack {
                Button("Annuler") { model.showExport = false }.keyboardShortcut(.cancelAction)
                Spacer()
                TextButton(title: "Copier", symbol: "doc.on.doc") { model.copyExport() }
                TextButton(title: "Enregistrer…", symbol: "square.and.arrow.down", prominent: true) { model.saveExport() }
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

    private static let oscExamples: [(String, String, String)] = [
        ("/simplepj/all/shutter", "1 ou 0", "Fermer (1 = Noir plateau) ou ouvrir (0) tous les volets"),
        ("/simplepj/all/power", "1 ou 0", "Allumer (1) ou mettre en veille (0) tout le parc"),
        ("/simplepj/all/freeze", "1 ou 0", "Geler (1) ou dégeler (0) l'image sur tout le parc (Classe 2)"),
        ("/simplepj/all/input", "\"31\" ou \"HDMI 1\"", "Basculer l'entrée de tous les projecteurs"),
        ("/simplepj/group/face/shutter", "1 ou 0", "Fermer ou ouvrir les volets du groupe #face"),
        ("/simplepj/group/cyclo/shutter", "1 ou 0", "Fermer ou ouvrir les volets du groupe #cyclo"),
        ("/simplepj/pj/1/shutter", "1 ou 0", "Piloter le projecteur n°1 (ou par nom / IP)"),
        ("/simplepj/pj/face-cour/input", "\"52\"", "Basculer l'entrée du projecteur nommé « Face Cour »"),
        ("/simplepj/pj/1/raw", "\"%1LAMP ?\"", "Envoyer une commande PJLink brute"),
        ("/simplepj/refresh", "(aucun)", "Relancer une interrogation immédiate du parc"),
    ]

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
                    Text("Pilotage OSC, API HTTP & Serveur MCP — SimplePJ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text("Pilotez vos vidéoprojecteurs depuis OSCScore, Montage, eMotion, QLab, Chataigne ou un agent MCP.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                Spacer()
                Chip(text: "OSC UDP :\(oscPort)", tint: Theme.osc.swiftUI, filled: true)
                Chip(text: "HTTP/MCP :\(model.fleet.httpPort)", tint: Theme.tcp.swiftUI)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            SectionHeader("Adresses OSC entrantes (cliquer pour copier)")
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(Self.oscExamples, id: \.0) { addr, arg, desc in
                        Button {
                            AppModel.copyToPasteboard(addr)
                            model.flash("Copié : \(addr)")
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

            SectionHeader("Serveur MCP (simplepj-mcp), AppleScript, CLI & API HTTP")
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
                TextButton(title: "Copier config MCP JSON", symbol: "doc.on.doc", compact: true) {
                    AppModel.copyToPasteboard(Self.mcpConfigJSON)
                    model.flash("Configuration MCP copiée")
                }
                Spacer()
                Button("Fermer", action: close).keyboardShortcut(.defaultAction)
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

    private static let features: [Feature] = [
        Feature(
            icon: "sun.max.fill",
            tint: Theme.accent,
            title: "PJLink Classe 1 & Classe 2 complet",
            detail: "Volet optique (AVMT), alimentation, entrées nommées (INNM), gel d'image (FREZ), résolution du signal (IRES), heures lampe/filtre et diagnostic 6 capteurs (ERST)."
        ),
        Feature(
            icon: "dot.radiowaves.left.and.right",
            tint: Theme.alive,
            title: "Découverte éclair (:4352) & Déverrouillage",
            detail: "Scan TCP :4352 parallèle d'un /24 en ~1,5 s + broadcast UDP %2SRCH + table ARP MAC + test automatique des mots de passe PJLink d'usine."
        ),
        Feature(
            icon: "antenna.radiowaves.left.and.right",
            tint: Theme.osc,
            title: "Groupes #tags, OSC, HTTP & MCP",
            detail: "Groupez vos projecteurs (#face, #cyclo, #sol) et pilotez-les au clavier, en OSC (:9130), HTTP (/v1 :17930), AppleScript ou via le serveur MCP (simplepj-mcp)."
        ),
        Feature(
            icon: "play.tv",
            tint: Theme.tcp,
            title: "Simulateur de plateau & Import",
            detail: "4 serveurs TCP PJLink Classe 2 embarqués sur 127.0.0.1 pour préparer vos conduites hors plateau, et import en 1 clic depuis ProjectorManager."
        ),
    ]

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
                            Text(copiedVersion ? "copié" : AppVersion.current.shortLabel)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.background.swiftUI)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent.swiftUI))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Contrôleur de vidéoprojecteurs PJLink natif ultra-léger — volets, entrées, groupes #tags, simulateur & OSC/MCP")
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
                Text("POINTS FORTS")
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
                    Text("Adrien Mondot · cie Adrien M")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.text.swiftUI)
                    Text("Licence publique générale GNU (GPL v3+). Zéro dépendance externe, aucune télémétrie.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint.swiftUI)
                }
                Spacer()
                Button { close(); openHelp() } label: {
                    Label("Guide (⌘?)", systemImage: "book.closed").font(.system(size: 11.5))
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

    static let groups: [(String, [(String, String)])] = [
        ("Plateau & Volets", [
            ("⌘B", "NOIR PLATEAU : Fermer les volets de la cible (AVMT 31)"),
            ("⇧⌘B", "Ouvrir les volets de la cible (AVMT 30)"),
            ("⌃⌘F", "Geler / Dégeler l'image sur la cible (FREZ)"),
            ("⌥ + Clic Veille", "Mettre en veille sans fenêtre de confirmation"),
        ]),
        ("Découverte & Parc", [
            ("⇧⌘D", "Découvrir les projecteurs PJLink (:4352) sur le réseau"),
            ("⌘.", "Arrêter la découverte en cours"),
            ("⌘N", "Ajouter un vidéoprojecteur par IP"),
            ("⇧⌘I", "Importer depuis ProjectorManager"),
            ("⌘R", "Actualiser l'état PJLink de tout le parc"),
            ("⌘O / ⌘S", "Ouvrir / Enregistrer un fichier de parc (.simplepj)"),
            ("⌘E", "Exporter la fiche technique (TXT, CSV, JSON)"),
        ]),
        ("Navigation & Affichage", [
            ("⌘1 / ⌘2", "Basculer entre la vue Plateau (cartes) et la vue Liste"),
            ("⌘A", "Tout sélectionner"),
            ("⌘F", "Filtrer par nom, #tag, IP ou modèle"),
            ("⏎", "Renommer / #grouper le projecteur sélectionné"),
            ("⌥⌘S / ⌥⌘I", "Afficher ou masquer la barre latérale / l'inspecteur"),
            ("⌥⌘L", "Afficher ou masquer la console protocole PJLink"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Raccourcis clavier — SimplePJ")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                Button("Fermer", action: close).keyboardShortcut(.defaultAction)
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
        case quickStart = "Démarrage rapide"
        case stageAndGroups = "Plateau & Groupes"
        case pjlinkProtocol = "PJLink Classe 1 & 2"
        case projectorManager = "ProjectorManager"
        case oscAndMCP = "OSC, API HTTP & MCP"

        var id: String { rawValue }

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
                Text("Guide d’utilisation — SimplePJ")
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
                    Label("Raccourcis clavier (⌘/)", systemImage: "command")
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
                        Text(section.rawValue)
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
                title: "Démarrage rapide",
                subtitle: "Découvrir, nommer et piloter un parc de vidéoprojecteurs PJLink en quatre étapes."
            )
            numberedStep(
                number: "1",
                title: "Découvrir le réseau (:4352) ou lancer le plateau simulé",
                body: "Choisissez l'interface réseau en haut à gauche puis cliquez sur « Découvrir » (⇧⌘D) : SimplePJ sonde un sous-réseau /24 complet en ~1,5 s. Hors plateau, cliquez sur « Simuler un plateau (4 VP) » pour lancer 4 serveurs PJLink Classe 2 réels sur 127.0.0.1."
            )
            numberedStep(
                number: "2",
                title: "Déverrouiller les mots de passe d'usine en un clic",
                body: "Si un projecteur répond PJLINK 1 (mot de passe requis), cliquez sur « Tester mots de passe » : SimplePJ teste automatiquement les mots de passe d'usine courants (panasonic, admin, pjlink, JBMIA, 0000…)."
            )
            numberedStep(
                number: "3",
                title: "Basculer entre la vue Plateau (⌘1) et la vue Liste (⌘2)",
                body: "La vue Plateau affiche de grandes cartes de régie ; la vue Liste embarque des commutateurs directs [ON | OFF], [OUV | NOIR], Mute Audio, un menu déroulant d'entrée vidéo et un popover de diagnostic Lampe / ERST sur chaque ligne."
            )
            numberedStep(
                number: "4",
                title: "Enregistrer (.simplepj) ou exporter la fiche technique (⌘E)",
                body: "Sauvegardez votre parc en .simplepj (⌘S) ou exportez une fiche technique complète (TXT, CSV, JSON, IP:port) incluant modèles, numéros de série, entrées et heures de lampe."
            )
            calloutBox(
                icon: "eye.slash.fill",
                tint: Theme.accent,
                title: "Volet optique (Noir plateau) vs Extinction",
                text: "En spectacle, utilisez toujours « VOLET FERMÉ · NOIR » (AVMT 31, raccourci ⌘B) pour couper le faisceau instantanément. L'extinction (« Veille », POWR 0) demande une confirmation de sécurité (maintenez ⌥ pour contourner)."
            )
        }
    }

    private var stageAndGroupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Conduite de plateau & Groupes #tags",
                subtitle: "Piloter un projecteur, une sélection multiple ou un groupe de plateau d'un seul geste."
            )
            bulletList([
                ("Groupes automatiques par #tags", "Ajoutez des #tags directement dans le nom d'un projecteur (ex. « Face Cour #face #cour », « Cyclo #cyclo »). Vos groupes apparaissent automatiquement dans la barre latérale gauche : un clic filtre la vue, et un clic droit permet d'ouvrir/fermer les volets de tout le groupe."),
                ("Barre maîtresse de plateau", "Les boutons « NOIR · Fermer volets » (⌘B), « Ouvrir volets » (⇧⌘B), « Allumer », « Veille », « Gel » et « Entrée… » agissent sur la sélection active, le groupe filtré ou tout le parc."),
                ("Wake-on-LAN & Interface Web", "SimplePJ relève automatiquement l'adresse MAC de chaque projecteur dans la table ARP macOS pour permettre le réveil réseau (Wake-on-LAN, ⇧⌘W) et l'ouverture directe de l'interface HTTP du projecteur.")
            ])
        }
    }

    private var pjlinkProtocolSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Protocole PJLink Classe 1 & Classe 2",
                subtitle: "Commandes normalisées JBMIA sur TCP/UDP 4352 et console temps réel (⌥⌘L)."
            )
            bulletList([
                ("Classe 1 (%1) — Alimentation, Volet, Entrées, Lampes, ERST", "Support complet de POWR (0/1/2/3), AVMT (10/11 vidéo, 20/21 audio, 30/31 volet complet), INPT, INST, LAMP (multi-lampes/laser), ERST (6 capteurs : Ventilateur, Lampe, Température, Capot, Filtre, Autre), NAME, INF1, INF2, INFO, CLSS."),
                ("Classe 2 (%2) — Gel, Noms d'entrées, Résolutions, Série", "Support de %2FREZ (gel d'image), %2INNM ?<code> (vrais noms des entrées : HDMI 1, HDBaseT, SDI), %2IRES / %2RRES (résolution entrante et native), %2SNUM (numéro de série), %2SVER (firmware), %2FILT (heures filtre), %2RLMP / %2RFIL."),
                ("Authentification MD5 & Reconnexion automatique", "Gestion native du défi MD5 (PJLINK 1 <salt>) et reconnexion TCP transparente pour les projecteurs qui ferment la socket après chaque commande.")
            ])
        }
    }

    private var projectorManagerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Migration & Compatibilité ProjectorManager",
                subtitle: "Retrouvez vos habitudes et vos scripts de ProjectorManager (SIGMASIX)."
            )
            bulletList([
                ("Import en 1 clic de vos projecteurs enregistrés (⇧⌘I)", "SimplePJ lit automatiquement les préférences de ProjectorManager (ch.sigmasix.ProjectorManager) et importe toutes vos adresses IP et mots de passe d'un seul clic."),
                ("Contrôles directs en ligne en vue Liste (⌘2)", "Retrouvez l'efficacité de la vue liste avec les commutateurs [ON | OFF], [OUV | NOIR], Mute Audio, le menu déroulant d'entrée vidéo et le popover Lampe / ERST directement sur chaque ligne."),
                ("Dictionnaire AppleScript 100 % compatible", "Les commandes AppleScript PowerOn, PowerOff, AvMute, AvUnMute et Inpt {code, index} fonctionnent à l'identique dans QLab ou éditeur de scripts en ciblant \"SimplePJ\".")
            ])
        }
    }

    private var oscAndMCPSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "OSC, API HTTP & Serveur MCP",
                subtitle: "Interfaçage temps réel avec OSCScore, Montage, eMotion, QLab et agents IA."
            )
            bulletList([
                ("Serveur OSC UDP (:9130 par défaut)", "/simplepj/all/shutter <0|1>, /simplepj/all/power <0|1>, /simplepj/all/freeze <0|1>, /simplepj/all/input <code|nom>, /simplepj/group/<tag>/shutter <0|1>, /simplepj/pj/<index|ip|nom>/shutter <0|1>, /simplepj/refresh."),
                ("API HTTP JSON locale (127.0.0.1:17930/v1)", "Expose GET /v1/state, GET /v1/projectors, GET /v1/help, GET /v1/snapshot.png, POST /v1/shutter, POST /v1/power, POST /v1/input, POST /v1/freeze, POST /v1/discover, POST /v1/projectors, POST /v1/command."),
                ("Serveur MCP embarqué (simplepj-mcp)", "Le binaire compagnon /Applications/SimplePJ.app/Contents/MacOS/simplepj-mcp expose 11 outils MCP (simplepj_state, simplepj_projectors, simplepj_shutter, simplepj_power, simplepj_input, simplepj_freeze, simplepj_discover, simplepj_add_projector, simplepj_command, simplepj_snapshot) sur stdio.")
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
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Surveillance PJLink")
            FieldRow("Cadence de rafraîchissement", width: 170) {
                Picker("", selection: $fleet.pollInterval) {
                    ForEach(PollInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            Divider().overlay(Theme.separator.swiftUI)
            SectionHeader("Ports OSC, API HTTP & MCP")
            FieldRow("Port OSC entrant (UDP)", width: 170) {
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
                    TextButton(title: "Appliquer", compact: true) { applyPorts() }
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
            SectionHeader("Affichage")
            Toggle("Barre latérale des groupes", isOn: $model.showSidebar)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Toggle("Inspecteur détaillé", isOn: $model.showInspector)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Toggle("Console protocole PJLink", isOn: $model.showConsoleDrawer)
                .font(.system(size: 11.5)).foregroundStyle(Theme.text.swiftUI)
            Divider().overlay(Theme.separator.swiftUI)
            SectionHeader("Réseau & Confidentialité")
            Text("SimplePJ communique uniquement en local avec vos vidéoprojecteurs (TCP/UDP 4352), vos logiciels de régie (OSC :9130, HTTP 127.0.0.1:17930) et le serveur MCP local (simplepj-mcp). Aucune télémétrie, aucune connexion externe.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim.swiftUI)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 390)
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
        model.flash("Ports OSC (:\(oscPortText)) et HTTP/MCP (:\(httpPortText)) mis à jour")
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
            Text("Nommer la plage favorite")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)
            Text(range.range)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.textDim.swiftUI)
            TextField("Plateau, Régie, Tournée…", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text.swiftUI)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                .onSubmit { onCommit(name); dismiss() }
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { onCommit(name); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Theme.panel.swiftUI)
        .preferredColorScheme(.dark)
        .onAppear { name = range.name ?? "" }
    }
}
