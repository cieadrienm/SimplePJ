import AppKit
import SimplePJCore
import SwiftUI

@main
struct SimplePJApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("SimplePJ") {
            ContentView(model: appDelegate.model)
                .frame(minWidth: 980, minHeight: 580)
                .onAppear { appDelegate.didAppear() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1380, height: 820)
        .commands { appCommands(model: appDelegate.model) }

        Settings {
            PreferencesView(model: appDelegate.model)
        }
    }

    @CommandsBuilder
    private func appCommands(model: AppModel) -> some Commands {
        let _ = model.language
        CommandGroup(replacing: .appInfo) {
            Button(L("À propos de SimplePJ", "About SimplePJ")) { model.showAbout = true }
            Button(L("Rechercher des mises à jour…", "Check for Updates…")) {
                model.showUpdater = true
                model.updater.checkForUpdates(silent: false)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(L("Ajouter un vidéoprojecteur…", "Add Projector…")) { model.showAddProjector = true }
                .keyboardShortcut("n", modifiers: [.command])
            Button(model.fleet.isScanning ? L("Découverte en cours…", "Scanning Network…") : L("Découvrir le réseau (:4352)", "Discover Network (:4352)")) {
                model.fleet.startDiscovery()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(!model.fleet.canStartScan)
            Button(L("Arrêter la découverte", "Stop Discovery")) { model.fleet.stopDiscovery() }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.fleet.isScanning)
            Divider()
            Button(model.fleet.isDemoRigActive ? L("Arrêter le plateau simulé (4 VP)", "Stop Simulated Stage Rig (4 PJ)") : L("Lancer un plateau simulé (4 VP)", "Start Simulated Stage Rig (4 PJ)")) {
                model.fleet.toggleSimulatedStageRig()
            }
            Divider()
            Button(L("Ouvrir un parc (.simplepj)…", "Open Fleet (.simplepj)…")) { model.openFleetPanel() }
                .keyboardShortcut("o", modifiers: [.command])
            Button(L("Importer depuis ProjectorManager", "Import from ProjectorManager")) { model.importFromProjectorManager() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button(L("Enregistrer le parc (.simplepj)…", "Save Fleet (.simplepj)…")) { model.saveFleetPanel() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(model.fleet.projectors.isEmpty)
            Button(L("Exporter la fiche technique…", "Export Technical Sheet…")) { model.showExport = true }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(model.fleet.projectors.isEmpty)
        }

        CommandGroup(replacing: .pasteboard) {
            Button(L("Copier l'adresse IP", "Copy IP Address")) { model.copySelectedIPs() }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(model.fleet.selection.isEmpty)
            Button(L("Tout sélectionner", "Select All")) { model.selectAll() }
                .keyboardShortcut("a", modifiers: [.command])
            Divider()
            Button(L("Filtrer le parc", "Filter Fleet")) { model.searchFocusRequest += 1 }
                .keyboardShortcut("f", modifiers: [.command])
        }

        CommandMenu(L("Plateau", "Stage")) {
            Button(L("NOIR PLATEAU — Fermer les volets (AVMT 31)", "STAGE BLACKOUT — Close Shutters (AVMT 31)")) {
                model.fleet.setShutter(closed: true)
            }
            .keyboardShortcut("b", modifiers: [.command])
            .disabled(model.fleet.activeTargets.isEmpty)

            Button(L("Ouvrir les volets (AVMT 30)", "Open Shutters (AVMT 30)")) {
                model.fleet.setShutter(closed: false)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button(L("Allumer la cible (POWR 1)", "Power On Target (POWR 1)")) {
                model.requestPower(on: true)
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Button(L("Mettre la cible en veille (POWR 0)…", "Standby Target (POWR 0)…")) {
                model.requestPower(on: false)
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button(L("Geler / Dégeler l'image (FREZ)", "Toggle Freeze (FREZ)")) {
                let anyFrozen = model.fleet.activeTargets.contains(where: \.freeze)
                model.fleet.setFreeze(!anyFrozen)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
            .disabled(model.fleet.activeTargets.isEmpty)

            Menu(L("Basculer l'entrée vidéo", "Switch Video Input")) {
                ForEach(model.fleet.commonInputsForActiveTargets) { inp in
                    Button(inp.fullLabel) {
                        model.fleet.setInput(inp.code)
                    }
                }
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button(L("Actualiser tout le parc", "Refresh Entire Fleet")) {
                model.fleet.refreshAll(includeIdentity: true)
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(model.fleet.projectors.isEmpty)

            Button(L("Nommer / #grouper le projecteur…", "Rename / #tag Projector…")) {
                model.revealInspector()
                model.labelFocusRequest += 1
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(model.inspectedProjector == nil)

            Button("Wake-on-LAN") {
                model.wakeProjectors()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(!model.fleet.activeTargets.contains { $0.mac != nil })

            Divider()

            Button(L("Retirer la sélection du parc", "Remove Selected from Fleet")) {
                model.deleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(model.fleet.selection.isEmpty)
        }

        CommandGroup(after: .toolbar) {
            Button(L("Vue Plateau (Cartes)", "Stage View (Cards)")) { model.viewMode = .cards }
                .keyboardShortcut("1", modifiers: [.command])
            Button(L("Vue Liste (Tableau)", "List View (Table)")) { model.viewMode = .table }
                .keyboardShortcut("2", modifiers: [.command])
            Divider()
            Button(model.showSidebar ? L("Masquer la barre latérale", "Hide Sidebar") : L("Afficher la barre latérale", "Show Sidebar")) {
                model.showSidebar.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            Button(model.showInspector ? L("Masquer l'inspecteur", "Hide Inspector") : L("Afficher l'inspecteur", "Show Inspector")) {
                model.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Button(model.showConsoleDrawer ? L("Masquer la console PJLink", "Hide PJLink Console") : L("Afficher la console PJLink", "Show PJLink Console")) {
                model.showConsoleDrawer.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            Divider()
            Button(L("Commandes OSC & API HTTP…", "OSC Commands & HTTP API…")) {
                model.showOSCGuide = true
            }
        }

        CommandGroup(replacing: .help) {
            Button(L("Aide SimplePJ", "SimplePJ Help")) { model.showHelp = true }
                .keyboardShortcut("?", modifiers: [.command])
            Divider()
            Button(L("Raccourcis clavier", "Keyboard Shortcuts")) { model.showShortcuts = true }
                .keyboardShortcut("/", modifiers: [.command])
            Button(L("Guide OSC & HTTP", "OSC & HTTP Guide")) { model.showOSCGuide = true }
            Divider()
            Button(L("Site web Simple Apps (adrien-m.net/software)", "Simple Apps Website (adrien-m.net/software)")) {
                if let url = URL(string: "https://adrien-m.net/software") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var model = AppModel(startServices: !headless, persistEnabled: !headless)
    private var headless = false
    private var didStart = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppVersion.runIfRequested()
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--self-test") {
            headless = true
            SelfTest.runAndExit()
        }
        if let index = args.firstIndex(of: "--discover") {
            headless = true
            HeadlessCLI.runDiscoverAndExit(arguments: Array(args[(index + 1)...]))
        }
        if let index = args.firstIndex(of: "--cmd") {
            headless = true
            HeadlessCLI.runCommandAndExit(arguments: Array(args[(index + 1)...]))
        }
        if let index = args.firstIndex(of: "--snapshot") {
            headless = true
            let path = index + 1 < args.count && !args[index + 1].hasPrefix("-") ? args[index + 1] : "/tmp/simplepj.png"
            let view = args.firstIndex(of: "--view").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "cards"
            Snapshot.runCLISnapshot(outputPath: path, view: view)
        }
    }

    func didAppear() {
        guard !didStart else { return }
        didStart = true
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let files = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        if let first = files.first {
            let url = URL(fileURLWithPath: (first as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: url.path) {
                model.open(url)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let first = urls.first {
            model.open(first)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        model.fleet.stopAllServices()
    }
}
