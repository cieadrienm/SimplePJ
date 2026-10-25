import SimplePJCore
import SwiftUI

struct TopBar: View {
    @Bindable var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 9) {
            IconButton(
                symbol: "sidebar.left",
                helpText: L("Afficher ou masquer la barre latérale (⌥⌘S)", "Show or hide sidebar (⌥⌘S)"),
                active: model.showSidebar
            ) {
                model.showSidebar.toggle()
            }

            Divider().frame(height: 16).padding(.horizontal, 1)

            networkMenu
            rangeField
            IconButton(
                symbol: model.fleet.isCurrentRangeSaved ? "star.fill" : "star",
                helpText: model.fleet.isCurrentRangeSaved ? L("Retirer cette plage des favoris", "Remove this range from favorites") : L("Garder cette plage en favori", "Save this range as a favorite"),
                tint: Theme.accent.swiftUI,
                disabled: model.fleet.rangeInput.isEmpty
            ) {
                model.fleet.toggleSaveCurrentRange()
            }

            discoverButton

            IconButton(
                symbol: "plus",
                helpText: L("Ajouter un vidéoprojecteur par adresse IP (⌘N)", "Add projector by IP address (⌘N)")
            ) {
                model.showAddProjector = true
            }

            IconButton(
                symbol: "arrow.clockwise",
                helpText: L("Actualiser l'état PJLink de tous les projecteurs (⌘R)", "Refresh PJLink status of all projectors (⌘R)"),
                disabled: model.fleet.projectors.isEmpty || model.fleet.isScanning
            ) {
                model.fleet.refreshAll(includeIdentity: true)
            }

            Divider().frame(height: 16).padding(.horizontal, 1)

            viewModePicker
            toolsMenu

            Spacer(minLength: 6)

            searchField

            IconButton(
                symbol: "terminal",
                helpText: L("Afficher ou masquer la console protocole PJLink (⌥⌘L)", "Show or hide PJLink protocol console (⌥⌘L)"),
                active: model.showConsoleDrawer
            ) {
                model.showConsoleDrawer.toggle()
            }

            IconButton(
                symbol: "sidebar.right",
                helpText: L("Afficher ou masquer l'inspecteur du projecteur (⌥⌘I)", "Show or hide projector inspector (⌥⌘I)"),
                active: model.showInspector
            ) {
                model.toggleInspector()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Theme.panel.swiftUI)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator.swiftUI).frame(height: 1) }
        .onChange(of: model.searchFocusRequest) { _, _ in searchFocused = true }
    }

    private var networkMenu: some View {
        Menu {
            ForEach(NetworkInterface.scannableInterfaces(), id: \.self) { iface in
                Button {
                    model.useInterface(iface)
                } label: {
                    Label("\(iface.name) · \(iface.cidr)  (\(iface.ipv4))", systemImage: iface.isVPN ? "lock.shield" : "network")
                }
            }
            if NetworkInterface.scannableInterfaces().isEmpty {
                Text(L("Aucune interface réseau active", "No active network interface"))
            }
            if !model.fleet.savedRanges.isEmpty {
                Divider()
                ForEach(model.fleet.savedRanges) { saved in
                    Button {
                        model.fleet.rangeInput = saved.range
                    } label: {
                        Label(saved.displayTitle, systemImage: "star.fill")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "network")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent.swiftUI)
                Text(model.currentInterface?.name ?? L("Réseau", "Network"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.text.swiftUI)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textDim.swiftUI)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.fleet.isScanning)
        .help(L("Choisir une interface réseau ou une plage favorite", "Choose a network interface or favorite range"))
    }

    private var rangeField: some View {
        CommitField(
            value: model.fleet.rangeInput,
            placeholder: "192.168.1.0/24, 2.0.0.10-30",
            monospaced: true,
            onCommit: { model.fleet.rangeInput = $0 },
            onSubmit: { _ in
                if model.fleet.canStartScan { model.fleet.startDiscovery() }
            }
        )
        .frame(width: 196)
        .disabled(model.fleet.isScanning)
        .help(L("Sous-réseau CIDR, plage IP ou liste d'adresses (:4352). Entrée lance la découverte PJLink.", "CIDR subnet, IP range, or address list (:4352). Press Return to start PJLink discovery."))
    }

    private var discoverButton: some View {
        Group {
            if model.fleet.isScanning {
                TextButton(title: L("Arrêter", "Stop"), symbol: "stop.fill", destructive: true) {
                    model.fleet.stopDiscovery()
                }
                .keyboardShortcut(".", modifiers: [.command])
            } else {
                TextButton(
                    title: L("Découvrir", "Discover"),
                    symbol: "dot.radiowaves.left.and.right",
                    prominent: true,
                    disabled: !model.fleet.canStartScan
                ) {
                    model.fleet.startDiscovery()
                }
            }
        }
        .help(model.fleet.isScanning ? L("Arrêter la découverte (⌘.)", "Stop discovery (⌘.)") : L("Rechercher les vidéoprojecteurs PJLink sur le réseau (⇧⌘D)", "Discover PJLink projectors on the network (⇧⌘D)"))
    }

    private var viewModePicker: some View {
        HStack(spacing: 2) {
            ForEach(MainViewMode.allCases) { mode in
                let active = model.viewMode == mode
                Button {
                    model.viewMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.label)
                            .font(.system(size: 10.5, weight: active ? .semibold : .medium))
                    }
                    .foregroundStyle(active ? Theme.background.swiftUI : Theme.textDim.swiftUI)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(active ? Theme.accent.swiftUI : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Affichage \(mode.label)", "\(mode.label) view"))
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 5.5).fill(Color.white.opacity(0.05)))
    }

    private var toolsMenu: some View {
        @Bindable var fleet = model.fleet
        return Menu {
            Button(fleet.isDemoRigActive ? L("Arrêter le plateau simulé (4 VP)", "Stop Simulated Stage Rig (4 PJ)") : L("Lancer un plateau simulé (4 VP)", "Start Simulated Stage Rig (4 PJ)")) {
                fleet.toggleSimulatedStageRig()
            }
            Divider()
            Button(L("Ouvrir un parc (.simplepj)…", "Open Fleet (.simplepj)…")) { model.openFleetPanel() }
            Button(L("Enregistrer le parc (.simplepj)…", "Save Fleet (.simplepj)…")) { model.saveFleetPanel() }
                .disabled(fleet.projectors.isEmpty)
            Button(L("Exporter la fiche technique…", "Export Technical Sheet…")) { model.showExport = true }
                .disabled(fleet.projectors.isEmpty)
            Divider()
            Button(L("Wake-on-LAN sur la sélection", "Wake-on-LAN Selected")) { model.wakeProjectors() }
                .disabled(!fleet.activeTargets.contains { $0.mac != nil })
            Button(L("Commandes OSC & API HTTP…", "OSC Commands & HTTP API…")) { model.showOSCGuide = true }
            Divider()
            Picker(L("Surveillance auto", "Auto Polling"), selection: $fleet.pollInterval) {
                ForEach(PollInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
        } label: {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text.swiftUI)
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L("Outils : simulateur plateau, fichiers .simplepj, export, Wake-on-LAN, OSC et cadence de surveillance", "Tools: stage simulator, .simplepj files, export, Wake-on-LAN, OSC, and polling cadence"))
    }

    private var searchField: some View {
        @Bindable var fleet = model.fleet
        return HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(searchFocused ? Theme.accent.swiftUI : Theme.textDim.swiftUI)
            TextField(L("Filtrer (nom, IP, #tag, modèle)", "Filter (name, IP, #tag, model)"), text: $fleet.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text.swiftUI)
                .focused($searchFocused)
                .onExitCommand { fleet.searchQuery = ""; searchFocused = false }
            if !fleet.searchQuery.isEmpty {
                Button { fleet.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(width: 196)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(searchFocused ? Theme.accent.swiftUI.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .help(L("Filtrer le parc par nom de plateau, #groupe, IP, modèle ou numéro de série (⌘F)", "Filter fleet by stage name, #group, IP, model, or serial number (⌘F)"))
    }
}
