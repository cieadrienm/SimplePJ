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
        CommandGroup(replacing: .appInfo) {
            Button("À propos de SimplePJ") { model.showAbout = true }
        }

        CommandGroup(replacing: .newItem) {
            Button("Ajouter un vidéoprojecteur…") { model.showAddProjector = true }
                .keyboardShortcut("n", modifiers: [.command])
            Button(model.fleet.isScanning ? "Découverte en cours…" : "Découvrir le réseau (:4352)") {
                model.fleet.startDiscovery()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(!model.fleet.canStartScan)
            Button("Arrêter la découverte") { model.fleet.stopDiscovery() }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.fleet.isScanning)
            Divider()
            Button(model.fleet.isDemoRigActive ? "Arrêter le plateau simulé (4 VP)" : "Lancer un plateau simulé (4 VP)") {
                model.fleet.toggleSimulatedStageRig()
            }
            Divider()
            Button("Ouvrir un parc (.simplepj)…") { model.openFleetPanel() }
                .keyboardShortcut("o", modifiers: [.command])
            Button("Importer depuis ProjectorManager") { model.importFromProjectorManager() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Enregistrer le parc (.simplepj)…") { model.saveFleetPanel() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(model.fleet.projectors.isEmpty)
            Button("Exporter la fiche technique…") { model.showExport = true }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(model.fleet.projectors.isEmpty)
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Copier l'adresse IP") { model.copySelectedIPs() }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(model.fleet.selection.isEmpty)
            Button("Tout sélectionner") { model.selectAll() }
                .keyboardShortcut("a", modifiers: [.command])
            Divider()
            Button("Filtrer le parc") { model.searchFocusRequest += 1 }
                .keyboardShortcut("f", modifiers: [.command])
        }

        CommandMenu("Plateau") {
            Button("NOIR PLATEAU — Fermer les volets (AVMT 31)") {
                model.fleet.setShutter(closed: true)
            }
            .keyboardShortcut("b", modifiers: [.command])
            .disabled(model.fleet.activeTargets.isEmpty)

            Button("Ouvrir les volets (AVMT 30)") {
                model.fleet.setShutter(closed: false)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button("Allumer la cible (POWR 1)") {
                model.requestPower(on: true)
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Button("Mettre la cible en veille (POWR 0)…") {
                model.requestPower(on: false)
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button("Geler / Dégeler l'image (FREZ)") {
                let anyFrozen = model.fleet.activeTargets.contains(where: \.freeze)
                model.fleet.setFreeze(!anyFrozen)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
            .disabled(model.fleet.activeTargets.isEmpty)

            Menu("Basculer l'entrée vidéo") {
                ForEach(model.fleet.commonInputsForActiveTargets) { inp in
                    Button(inp.fullLabel) {
                        model.fleet.setInput(inp.code)
                    }
                }
            }
            .disabled(model.fleet.activeTargets.isEmpty)

            Divider()

            Button("Actualiser tout le parc") {
                model.fleet.refreshAll(includeIdentity: true)
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(model.fleet.projectors.isEmpty)

            Button("Nommer / #grouper le projecteur…") {
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

            Button("Retirer la sélection du parc") {
                model.deleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(model.fleet.selection.isEmpty)
        }

        CommandGroup(after: .toolbar) {
            Button("Vue Plateau (Cartes)") { model.viewMode = .cards }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Vue Liste (Tableau)") { model.viewMode = .table }
                .keyboardShortcut("2", modifiers: [.command])
            Divider()
            Button(model.showSidebar ? "Masquer la barre latérale" : "Afficher la barre latérale") {
                model.showSidebar.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            Button(model.showInspector ? "Masquer l'inspecteur" : "Afficher l'inspecteur") {
                model.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Button(model.showConsoleDrawer ? "Masquer la console PJLink" : "Afficher la console PJLink") {
                model.showConsoleDrawer.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            Divider()
            Button("Commandes OSC & API HTTP…") {
                model.showOSCGuide = true
            }
        }

        CommandGroup(replacing: .help) {
            Button("Aide SimplePJ") { model.showHelp = true }
                .keyboardShortcut("?", modifiers: [.command])
            Divider()
            Button("Raccourcis clavier") { model.showShortcuts = true }
                .keyboardShortcut("/", modifiers: [.command])
            Button("Guide OSC & HTTP") { model.showOSCGuide = true }
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
