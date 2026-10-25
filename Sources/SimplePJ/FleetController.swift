import Darwin
import Foundation
import Observation
import SimplePJCore

/// Automatic background polling cadence.
enum PollInterval: Int, CaseIterable, Identifiable, Codable, Sendable {
    case off = 0
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: return "Manuel"
        case .twoSeconds: return "Toutes les 2 s"
        case .fiveSeconds: return "Toutes les 5 s"
        case .tenSeconds: return "Toutes les 10 s"
        case .thirtySeconds: return "Toutes les 30 s"
        }
    }

    var shortLabel: String {
        switch self {
        case .off: return "Manuel"
        case .twoSeconds: return "2 s"
        case .fiveSeconds: return "5 s"
        case .tenSeconds: return "10 s"
        case .thirtySeconds: return "30 s"
        }
    }
}

/// Sidebar filter categories.
enum SidebarFilter: Hashable, Sendable {
    case all
    case projecting
    case shutterClosed
    case standby
    case alerts
    case offline
    case tag(String)

    var title: String {
        switch self {
        case .all: return "Tous les projecteurs"
        case .projecting: return "En projection (On + Ouvert)"
        case .shutterClosed: return "Volet fermé (Noir)"
        case .standby: return "En veille / Chauffe"
        case .alerts: return "Alertes & Mots de passe"
        case .offline: return "Hors ligne"
        case .tag(let t): return "Groupe \(t)"
        }
    }
}

/// Table sort column.
enum ProjectorSortColumn: String, CaseIterable, Sendable {
    case status
    case name
    case ip
    case model
    case power
    case shutter
    case input
    case lamp
    case latency
}

/// A saved network CIDR / range favorite.
struct SavedRange: Identifiable, Hashable, Codable, Sendable {
    var id: String { range }
    var range: String
    var name: String?

    var displayTitle: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return range
    }
}

/// Central controller for the PJLink projector fleet, network discovery, polling, simulator, OSC & HTTP.
@Observable
@MainActor
final class FleetController {
    var projectors: [Projector] = []
    var selection: Set<UUID> = []
    var sidebarFilter: SidebarFilter = .all
    var searchQuery: String = ""
    var sortColumn: ProjectorSortColumn = .ip
    var sortAscending: Bool = true

    // Discovery state
    var rangeInput: String = ""
    var savedRanges: [SavedRange] = []
    var isScanning: Bool = false
    var scanProgress: Double = 0
    var scannedCount: Int = 0
    var scanTotalCount: Int = 0
    var lastScanDuration: TimeInterval? = nil

    // Polling & Telemetry
    var pollInterval: PollInterval = .fiveSeconds {
        didSet {
            savePreferences()
            reschedulePollTimer()
        }
    }
    var exchanges: [PJLinkExchange] = []
    var statusMessage: String = "Prêt"
    var lastError: String? = nil

    // Simulator & External servers
    let demoRig = PJLinkDemoRig()
    var isDemoRigActive: Bool = false
    private(set) var oscServer: OSCUDPServer?
    private(set) var httpPort: UInt16 = kSimplePJDefaultHTTPPort
    private var httpListenFD: Int32 = -1
    private var pollTimer: Timer?
    private var cancelScanFlag = LockBox(false)
    private let defaultsPrefix = "net.cieadrienm.simplepj."
    private let persistEnabled: Bool

    init(startServices: Bool = true, persistEnabled: Bool = true) {
        self.persistEnabled = persistEnabled
        if let iface = NetworkInterface.scannableInterfaces().first {
            self.rangeInput = iface.cidr
        } else {
            self.rangeInput = "192.168.1.0/24"
        }

        if persistEnabled {
            loadPersistedState()
        }

        if startServices {
            startOSCServer()
            startHTTPServer()
            reschedulePollTimer()
            if !projectors.isEmpty {
                refreshAll()
            }
        }
    }

    // MARK: - Computed Views of the Fleet

    var visibleProjectors: [Projector] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = projectors.filter { pj in
            switch sidebarFilter {
            case .all:
                break
            case .projecting:
                guard pj.isProjectingLight else { return false }
            case .shutterClosed:
                guard pj.isShutterClosed else { return false }
            case .standby:
                guard pj.power == .standby || pj.power.isTransitioning else { return false }
            case .alerts:
                guard !pj.errors.isHealthy || pj.connectionState == .authRequired || pj.lastError != nil else { return false }
            case .offline:
                guard pj.connectionState == .offline else { return false }
            case .tag(let tag):
                guard pj.tags.contains(tag.lowercased()) else { return false }
            }

            guard !q.isEmpty else { return true }
            let haystack = [
                pj.displayTitle,
                pj.ip,
                pj.endpointLabel,
                pj.mac ?? "",
                pj.manufacturer ?? "",
                pj.modelName ?? "",
                pj.pjlinkName ?? "",
                pj.serialNumber ?? "",
                pj.currentInputDisplayName,
                pj.notes ?? "",
                pj.tags.joined(separator: " "),
            ].joined(separator: " ").lowercased()
            return haystack.contains(q)
        }

        return filtered.sorted { a, b in
            let asc = sortAscending
            switch sortColumn {
            case .status:
                let sa = statusRank(a), sb = statusRank(b)
                if sa != sb { return asc ? sa < sb : sa > sb }
            case .name:
                let cmp = a.displayTitle.localizedStandardCompare(b.displayTitle)
                if cmp != .orderedSame { return asc ? cmp == .orderedAscending : cmp == .orderedDescending }
            case .ip:
                let ia = IPv4Range.uint32(from: a.ip) ?? 0
                let ib = IPv4Range.uint32(from: b.ip) ?? 0
                if ia != ib { return asc ? ia < ib : ia > ib }
                if a.port != b.port { return asc ? a.port < b.port : a.port > b.port }
            case .model:
                let cmp = a.hardwareTitle.localizedStandardCompare(b.hardwareTitle)
                if cmp != .orderedSame { return asc ? cmp == .orderedAscending : cmp == .orderedDescending }
            case .power:
                if a.power.rawValue != b.power.rawValue { return asc ? a.power.rawValue < b.power.rawValue : a.power.rawValue > b.power.rawValue }
            case .shutter:
                if a.isShutterClosed != b.isShutterClosed { return asc ? !a.isShutterClosed : a.isShutterClosed }
            case .input:
                if a.currentInput != b.currentInput { return asc ? a.currentInput < b.currentInput : a.currentInput > b.currentInput }
            case .lamp:
                let la = a.maxLampHours ?? -1, lb = b.maxLampHours ?? -1
                if la != lb { return asc ? la < lb : la > lb }
            case .latency:
                let la = a.latencyMs ?? 99999, lb = b.latencyMs ?? 99999
                if la != lb { return asc ? la < lb : la > lb }
            }
            return (IPv4Range.uint32(from: a.ip) ?? 0, a.port) < (IPv4Range.uint32(from: b.ip) ?? 0, b.port)
        }
    }

    var selectedProjectors: [Projector] {
        projectors.filter { selection.contains($0.id) }
    }

    /// Targets for master bar actions: selected projectors if any, otherwise all visible projectors.
    var activeTargets: [Projector] {
        if !selection.isEmpty {
            return selectedProjectors
        }
        return visibleProjectors
    }

    var activeTargetsScopeLabel: String {
        if !selection.isEmpty {
            return Format.count(selection.count, "sélectionné")
        }
        if case .tag(let t) = sidebarFilter {
            return "Groupe \(t) (\(visibleProjectors.count))"
        }
        if sidebarFilter != .all || !searchQuery.isEmpty {
            return "Vue filtrée (\(visibleProjectors.count))"
        }
        return "Tout le parc (\(projectors.count))"
    }

    var allTags: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for pj in projectors {
            for tag in pj.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.tag < $1.tag }
    }

    /// Common inputs across `activeTargets` for quick group switching.
    var commonInputsForActiveTargets: [PJLinkInput] {
        let targets = activeTargets
        guard let first = targets.first else { return PJLinkInput.standardDefaults }
        if targets.count == 1 { return first.availableInputs }
        var seen: Set<String> = []
        var list: [PJLinkInput] = []
        for pj in targets {
            for inp in pj.availableInputs where seen.insert(inp.code).inserted {
                list.append(inp)
            }
        }
        return list.isEmpty ? PJLinkInput.standardDefaults : list
    }

    var onlineCount: Int { projectors.filter { $0.connectionState == .online }.count }
    var projectingCount: Int { projectors.filter(\.isProjectingLight).count }
    var shutterClosedCount: Int { projectors.filter { $0.connectionState == .online && $0.isShutterClosed }.count }
    var standbyCount: Int { projectors.filter { $0.power == .standby || $0.power.isTransitioning }.count }
    var alertCount: Int { projectors.filter { !$0.errors.isHealthy || $0.connectionState == .authRequired }.count }

    private func statusRank(_ pj: Projector) -> Int {
        switch pj.connectionState {
        case .online:
            if pj.isProjectingLight { return 0 }
            if pj.isShutterClosed { return 1 }
            return 2
        case .polling: return 3
        case .authRequired: return 4
        case .unknown: return 5
        case .offline: return 6
        }
    }

    // MARK: - PJLink Commands & Batch Actions

    func setShutter(closed: Bool, on targets: [Projector]? = nil) {
        let list = targets ?? activeTargets
        guard !list.isEmpty else { return }
        let cmd: PJLinkCommand = closed ? .shutterClose : .shutterOpen
        let verb = closed ? "Volet fermé (Noir)" : "Volet ouvert"
        statusMessage = "\(verb) → \(Format.count(list.count, "projecteur"))…"
        executeOnTargets(list, commands: [cmd, .shutterQuery])
    }

    func setVideoMute(_ muted: Bool, on projector: Projector) {
        executeOnTargets([projector], commands: [.shutterVideoMute(muted), .shutterQuery])
    }

    func setAudioMute(_ muted: Bool, on projector: Projector) {
        executeOnTargets([projector], commands: [.shutterAudioMute(muted), .shutterQuery])
    }

    func setPower(on: Bool, on targets: [Projector]? = nil) {
        let list = targets ?? activeTargets
        guard !list.isEmpty else { return }
        let cmd: PJLinkCommand = on ? .powerOn : .powerOff
        let verb = on ? "Allumage" : "Mise en veille"
        statusMessage = "\(verb) → \(Format.count(list.count, "projecteur"))…"
        executeOnTargets(list, commands: [cmd, .powerQuery])
        // Schedule a follow-up poll 1.2s later to catch warm-up -> on or cooling -> standby transitions
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            self?.refresh(list, includeIdentity: false)
        }
    }

    func setFreeze(_ freeze: Bool, on targets: [Projector]? = nil) {
        let list = targets ?? activeTargets
        guard !list.isEmpty else { return }
        let cmd: PJLinkCommand = .freeze(freeze)
        statusMessage = (freeze ? "Gel d'image activé" : "Gel d'image désactivé") + " → \(Format.count(list.count, "projecteur"))"
        executeOnTargets(list, commands: [cmd, .freezeQuery])
    }

    func setInput(_ code: String, on targets: [Projector]? = nil) {
        let list = targets ?? activeTargets
        guard !list.isEmpty else { return }
        statusMessage = "Entrée \(code) → \(Format.count(list.count, "projecteur"))…"
        executeOnTargets(list, commands: [.inputSelect(code), .inputQuery])
    }

    func sendRawCommand(_ raw: String, to projector: Projector) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        executeOnTargets([projector], commands: [.raw(trimmed)])
    }

    func executeOnTargets(_ targets: [Projector], commands: [PJLinkCommand]) {
        guard !targets.isEmpty else { return }
        for target in targets {
            Task.detached(priority: .userInitiated) {
                let res = try? PJLinkClient.executeBatch(commands, on: target, timeout: 1.5)
                let polled = res ?? PJLinkClient.poll(target, includeIdentity: false, includeClass2: false, timeout: 1.2)
                await MainActor.run { [weak self] in
                    self?.integrateSessionResult(polled)
                }
            }
        }
    }

    func refreshAll(includeIdentity: Bool = false) {
        refresh(projectors, includeIdentity: includeIdentity)
    }

    func refresh(_ targets: [Projector], includeIdentity: Bool = true) {
        guard !targets.isEmpty else { return }
        for target in targets {
            if let idx = projectors.firstIndex(where: { $0.id == target.id }), projectors[idx].connectionState == .unknown {
                projectors[idx].connectionState = .polling
            }
            Task.detached(priority: .utility) {
                let session = PJLinkClient.poll(target, includeIdentity: includeIdentity, includeClass2: true, timeout: 1.4)
                await MainActor.run { [weak self] in
                    self?.integrateSessionResult(session)
                }
            }
        }
    }

    func autoUnlockPassword(for projector: Projector) {
        statusMessage = "Test des mots de passe PJLink courants sur \(projector.displayTitle)…"
        let ip = projector.ip
        let port = projector.port
        let id = projector.id
        Task.detached(priority: .userInitiated) {
            let found = PJLinkClient.probeCommonPasswords(ip: ip, port: port)
            await MainActor.run { [weak self] in
                guard let self, let idx = self.projectors.firstIndex(where: { $0.id == id }) else { return }
                if let pwd = found {
                    self.projectors[idx].password = pwd
                    self.statusMessage = pwd.isEmpty
                        ? "\(self.projectors[idx].displayTitle) ne requiert pas de mot de passe"
                        : "Mot de passe trouvé pour \(self.projectors[idx].displayTitle) : « \(pwd) »"
                    self.saveFleet()
                    self.refresh([self.projectors[idx]], includeIdentity: true)
                } else {
                    self.statusMessage = "Aucun mot de passe d'usine reconnu pour \(self.projectors[idx].displayTitle)"
                }
            }
        }
    }

    private func integrateSessionResult(_ result: PJLinkSessionResult) {
        let updated = result.updatedProjector
        if let idx = projectors.firstIndex(where: { $0.id == updated.id }) {
            // Preserve user-editable fields if edited while network request was in flight
            var merged = updated
            merged.label = projectors[idx].label
            merged.notes = projectors[idx].notes
            if !projectors[idx].password.isEmpty && merged.password.isEmpty {
                merged.password = projectors[idx].password
            }
            projectors[idx] = merged
        } else if let idx = projectors.firstIndex(where: { $0.ip == updated.ip && $0.port == updated.port }) {
            var merged = updated
            merged.id = projectors[idx].id
            merged.label = projectors[idx].label ?? merged.label
            merged.notes = projectors[idx].notes ?? merged.notes
            projectors[idx] = merged
        } else {
            projectors.append(updated)
        }

        if !result.exchanges.isEmpty {
            exchanges.append(contentsOf: result.exchanges)
            if exchanges.count > 400 {
                exchanges.removeFirst(exchanges.count - 400)
            }
        }
        saveFleet()
    }

    // MARK: - Network Discovery

    var canStartScan: Bool {
        !isScanning && !IPv4Range.parseEndpoints(rangeInput).isEmpty
    }

    func startDiscovery() {
        let endpoints = IPv4Range.parseEndpoints(rangeInput)
        guard !endpoints.isEmpty, !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scannedCount = 0
        scanTotalCount = endpoints.count
        lastError = nil
        statusMessage = "Recherche PJLink (:4352) sur \(Format.count(endpoints.count, "adresse"))…"
        cancelScanFlag.set(false)

        var passwordMap: [String: String] = [:]
        for pj in projectors where !pj.password.isEmpty {
            passwordMap[pj.ip] = pj.password
            passwordMap["\(pj.ip):\(pj.port)"] = pj.password
        }

        let flag = cancelScanFlag
        Task.detached(priority: .userInitiated) {
            let _ = PJLinkDiscovery.scan(
                endpoints: endpoints,
                existingPasswords: passwordMap,
                shouldCancel: { flag.get() },
                onEvent: { event in
                    Task { @MainActor [weak self] in
                        self?.handleDiscoveryEvent(event)
                    }
                }
            )
        }
    }

    func stopDiscovery() {
        cancelScanFlag.set(true)
        isScanning = false
        statusMessage = "Recherche interrompue"
    }

    private func handleDiscoveryEvent(_ event: PJLinkDiscoveryEvent) {
        switch event {
        case .started(let total):
            scanTotalCount = total
            scannedCount = 0
            scanProgress = 0
        case .progress(let scanned, let total):
            scannedCount = scanned
            scanTotalCount = total
            scanProgress = total > 0 ? Double(scanned) / Double(total) : 0
        case .found(let discovered):
            mergeDiscoveredProjector(discovered)
        case .finished(let foundCount, let duration):
            isScanning = false
            scanProgress = 1
            lastScanDuration = duration
            let sec = String(format: "%.1f s", duration).replacingOccurrences(of: ".", with: ",")
            if foundCount == 0 {
                statusMessage = "Aucun projecteur PJLink trouvé sur \(rangeInput) (\(sec))"
            } else {
                statusMessage = "\(Format.count(foundCount, "projecteur")) découvert\(foundCount > 1 ? "s" : "") en \(sec)"
            }
            saveFleet()
        }
    }

    func mergeDiscoveredProjector(_ discovered: Projector) {
        if let idx = projectors.firstIndex(where: {
            ($0.ip == discovered.ip && $0.port == discovered.port) ||
            (discovered.mac != nil && $0.mac == discovered.mac)
        }) {
            var existing = projectors[idx]
            existing.ip = discovered.ip
            existing.port = discovered.port
            existing.mac = discovered.mac ?? existing.mac
            existing.pjlinkName = discovered.pjlinkName ?? existing.pjlinkName
            existing.manufacturer = discovered.manufacturer ?? existing.manufacturer
            existing.modelName = discovered.modelName ?? existing.modelName
            existing.extraInfo = discovered.extraInfo ?? existing.extraInfo
            existing.pjlinkClass = max(existing.pjlinkClass, discovered.pjlinkClass)
            existing.serialNumber = discovered.serialNumber ?? existing.serialNumber
            existing.firmwareVersion = discovered.firmwareVersion ?? existing.firmwareVersion
            existing.nativeResolution = discovered.nativeResolution ?? existing.nativeResolution
            existing.replacementLamp = discovered.replacementLamp ?? existing.replacementLamp
            existing.replacementFilter = discovered.replacementFilter ?? existing.replacementFilter
            existing.connectionState = discovered.connectionState
            existing.requiresAuth = discovered.requiresAuth
            existing.power = discovered.power
            existing.shutter = discovered.shutter
            existing.freeze = discovered.freeze
            existing.currentInput = discovered.currentInput
            existing.availableInputs = discovered.availableInputs
            existing.inputResolution = discovered.inputResolution
            existing.lamps = discovered.lamps
            existing.filterHours = discovered.filterHours
            existing.errors = discovered.errors
            existing.latencyMs = discovered.latencyMs
            existing.lastSeen = discovered.lastSeen
            projectors[idx] = existing
        } else {
            projectors.append(discovered)
            if selection.isEmpty {
                selection = [discovered.id]
            }
        }
    }

    // MARK: - Fleet CRUD & Simulated Stage Rig

    @discardableResult
    func addProjector(ip: String, port: UInt16 = kPJLinkDefaultPort, label: String? = nil, password: String = "", notes: String? = nil) -> Projector {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = projectors.firstIndex(where: { $0.ip == cleanIP && $0.port == port }) {
            if let label, !label.isEmpty { projectors[idx].label = label }
            if !password.isEmpty { projectors[idx].password = password }
            if let notes, !notes.isEmpty { projectors[idx].notes = notes }
            let pj = projectors[idx]
            selection = [pj.id]
            saveFleet()
            refresh([pj], includeIdentity: true)
            return pj
        }
        let pj = Projector(
            ip: cleanIP,
            port: port,
            label: label?.isEmpty == true ? nil : label,
            password: password,
            notes: notes?.isEmpty == true ? nil : notes
        )
        projectors.append(pj)
        selection = [pj.id]
        saveFleet()
        refresh([pj], includeIdentity: true)
        return pj
    }

    func removeProjectors(ids: Set<UUID>) {
        projectors.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        if !projectors.contains(where: \.isSimulated) && isDemoRigActive {
            demoRig.stopAll()
            isDemoRigActive = false
        }
        saveFleet()
    }

    func toggleSimulatedStageRig() {
        if isDemoRigActive {
            demoRig.stopAll()
            isDemoRigActive = false
            projectors.removeAll(where: \.isSimulated)
            selection = Set(selection.filter { id in projectors.contains(where: { $0.id == id }) })
            statusMessage = "Simulateur de plateau arrêté"
            saveFleet()
        } else {
            do {
                let simulated = try demoRig.startStageRig(transitionDuration: 0.8)
                projectors.removeAll(where: \.isSimulated)
                projectors.append(contentsOf: simulated)
                isDemoRigActive = true
                if let first = simulated.first {
                    selection = [first.id]
                }
                statusMessage = "Plateau simulé actif : 4 vidéoprojecteurs PJLink Classe 2 sur 127.0.0.1"
            } catch {
                lastError = error.localizedDescription
                statusMessage = "Impossible de démarrer le simulateur : \(error.localizedDescription)"
            }
        }
    }

    func updateProjector(_ id: UUID, mutate: (inout Projector) -> Void) {
        guard let idx = projectors.firstIndex(where: { $0.id == id }) else { return }
        mutate(&projectors[idx])
        saveFleet()
    }

    /// Number of projectors found in SIGMASIX ProjectorManager preferences (`ch.sigmasix.ProjectorManager`).
    var projectorManagerEntryCount: Int {
        ProjectorManagerImporter.readPreferencesEntries().count
    }

    /// Imports projectors from `ch.sigmasix.ProjectorManager` preferences and polls them.
    @discardableResult
    func importFromProjectorManager() -> Int {
        let entries = ProjectorManagerImporter.readPreferencesEntries()
        return importEntries(entries, sourceLabel: "ProjectorManager")
    }

    @discardableResult
    func importEntries(_ entries: [ProjectorManagerImporter.Entry], sourceLabel: String) -> Int {
        guard !entries.isEmpty else {
            statusMessage = "Aucun vidéoprojecteur trouvé dans \(sourceLabel)"
            return 0
        }
        var addedOrUpdated: [Projector] = []
        for entry in entries {
            if let idx = projectors.firstIndex(where: { $0.ip == entry.ip && $0.port == entry.port }) {
                if !entry.password.isEmpty && projectors[idx].password.isEmpty {
                    projectors[idx].password = entry.password
                }
                addedOrUpdated.append(projectors[idx])
            } else {
                let pj = Projector(ip: entry.ip, port: entry.port, password: entry.password)
                projectors.append(pj)
                addedOrUpdated.append(pj)
            }
        }
        if selection.isEmpty, let first = addedOrUpdated.first {
            selection = [first.id]
        }
        saveFleet()
        refresh(addedOrUpdated, includeIdentity: true)
        statusMessage = "\(Format.count(addedOrUpdated.count, "projecteur")) importé\(addedOrUpdated.count > 1 ? "s" : "") depuis \(sourceLabel)"
        return addedOrUpdated.count
    }

    // MARK: - Saved Ranges

    var isCurrentRangeSaved: Bool {
        savedRanges.contains { $0.range == rangeInput }
    }

    func toggleSaveCurrentRange() {
        let r = rangeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        if let idx = savedRanges.firstIndex(where: { $0.range == r }) {
            savedRanges.remove(at: idx)
        } else {
            savedRanges.append(SavedRange(range: r, name: nil))
        }
        savePreferences()
    }

    func renameSavedRange(_ range: String, to name: String?) {
        guard let idx = savedRanges.firstIndex(where: { $0.range == range }) else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        savedRanges[idx].name = (trimmed?.isEmpty == false) ? trimmed : nil
        savePreferences()
    }

    func removeSavedRange(_ range: String) {
        savedRanges.removeAll { $0.range == range }
        savePreferences()
    }

    // MARK: - Persistence

    func saveFleet() {
        guard persistEnabled else { return }
        let persisted = projectors.filter { !$0.isSimulated }
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: defaultsPrefix + "projectors")
        }
    }

    private func savePreferences() {
        guard persistEnabled else { return }
        UserDefaults.standard.set(pollInterval.rawValue, forKey: defaultsPrefix + "pollInterval")
        if let data = try? JSONEncoder().encode(savedRanges) {
            UserDefaults.standard.set(data, forKey: defaultsPrefix + "savedRanges")
        }
    }

    private func loadPersistedState() {
        let ud = UserDefaults.standard
        if let rawPoll = ud.object(forKey: defaultsPrefix + "pollInterval") as? Int,
           let interval = PollInterval(rawValue: rawPoll) {
            self.pollInterval = interval
        }
        if let data = ud.data(forKey: defaultsPrefix + "savedRanges"),
           let decoded = try? JSONDecoder().decode([SavedRange].self, from: data) {
            self.savedRanges = decoded
        }
        if let data = ud.data(forKey: defaultsPrefix + "projectors"),
           let decoded = try? JSONDecoder().decode([Projector].self, from: data) {
            self.projectors = decoded
            if let first = decoded.first {
                self.selection = [first.id]
            }
        }
    }

    // MARK: - Polling Timer

    private func reschedulePollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
        guard pollInterval != .off else { return }
        let seconds = TimeInterval(pollInterval.rawValue)
        pollTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isScanning, !self.projectors.isEmpty else { return }
                self.refresh(self.projectors, includeIdentity: false)
            }
        }
    }

    // MARK: - OSC Control Server (`:9130`)

    func startOSCServer(port: UInt16? = nil) {
        oscServer?.stop()
        let envPort = ProcessInfo.processInfo.environment["SIMPLEPJ_OSC_IN_PORT"].flatMap(UInt16.init)
        let targetPort = port ?? envPort ?? kSimplePJDefaultOSCInPort
        let server = OSCUDPServer(port: targetPort) { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleOSCMessage(message)
            }
        }
        _ = server.start()
        self.oscServer = server
    }

    func handleOSCMessage(_ msg: OSCCodec.Message) {
        let parts = msg.address.split(separator: "/").map(String.init)
        guard parts.first == "simplepj", parts.count >= 2 else { return }

        let firstArgBool = msg.arguments.first?.boolValue
        let firstArgStr = msg.arguments.first?.stringValue

        if parts[1] == "refresh" {
            refreshAll(includeIdentity: false)
            return
        }

        let targets: [Projector]
        let action: String
        if parts[1] == "all", parts.count >= 3 {
            targets = projectors
            action = parts[2].lowercased()
        } else if parts[1] == "group", parts.count >= 4 {
            let tag = "#" + parts[2].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            targets = projectors.filter { $0.tags.contains(tag) }
            action = parts[3].lowercased()
        } else if parts[1] == "pj", parts.count >= 4 {
            let key = parts[2].lowercased()
            targets = matchProjectors(byKey: key)
            action = parts[3].lowercased()
        } else {
            return
        }

        guard !targets.isEmpty else { return }
        switch action {
        case "shutter", "blackout", "avmt":
            let close = firstArgBool ?? true
            setShutter(closed: close, on: targets)
        case "power", "powr":
            if let on = firstArgBool {
                setPower(on: on, on: targets)
            }
        case "freeze", "frez":
            let frz = firstArgBool ?? true
            setFreeze(frz, on: targets)
        case "input", "inpt":
            if let code = firstArgStr {
                setInput(resolveInputCode(code, for: targets.first), on: targets)
            }
        case "raw":
            if let raw = firstArgStr, let first = targets.first {
                sendRawCommand(raw, to: first)
            }
        default:
            break
        }
    }

    private func matchProjectors(byKey key: String) -> [Projector] {
        if let idx = Int(key), idx >= 1, idx <= projectors.count {
            return [projectors[idx - 1]]
        }
        return projectors.filter { pj in
            pj.ip.lowercased() == key
                || pj.endpointLabel.lowercased() == key
                || pj.displayTitle.lowercased().replacingOccurrences(of: " ", with: "-") == key
                || pj.displayTitle.lowercased() == key
                || (pj.pjlinkName?.lowercased() == key)
        }
    }

    private func resolveInputCode(_ input: String, for projector: Projector?) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pj = projector,
           let byName = pj.availableInputs.first(where: { $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return byName.code
        }
        return trimmed
    }

    // MARK: - Local HTTP JSON Server (`127.0.0.1:17930/v1`)

    func startHTTPServer(port: UInt16? = nil) {
        stopHTTPServer()
        let envPort = ProcessInfo.processInfo.environment["SIMPLEPJ_API_PORT"].flatMap(UInt16.init)
        let targetPort = port ?? envPort ?? kSimplePJDefaultHTTPPort

        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = targetPort.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0, Darwin.listen(fd, 16) == 0 else {
            Darwin.close(fd)
            return
        }

        var bound = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &bound) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(fd, $0, &len)
            }
        }
        self.httpListenFD = fd
        self.httpPort = UInt16(bigEndian: bound.sin_port)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                var caddr = sockaddr_in()
                var clen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let cfd = withUnsafeMutablePointer(to: &caddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.accept(fd, $0, &clen)
                    }
                }
                if cfd < 0 { break }
                var one: Int32 = 1
                setsockopt(cfd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
                self?.handleHTTPConnection(cfd)
            }
        }
    }

    func stopHTTPServer() {
        if httpListenFD >= 0 {
            Darwin.close(httpListenFD)
            httpListenFD = -1
        }
    }

    nonisolated private func handleHTTPConnection(_ fd: Int32) {
        defer { Darwin.close(fd) }
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = Darwin.recv(fd, &buf, buf.count, 0)
        guard n > 0 else { return }
        let requestText = String(decoding: buf[0..<n], as: UTF8.self)
        let firstLine = requestText.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let tokens = firstLine.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return }
        let method = tokens[0].uppercased()
        let path = tokens[1]

        let sem = DispatchSemaphore(value: 0)
        let box = LockBox<Data>(Data("{\"ok\":true}".utf8))
        let statusBox = LockBox<Int>(200)

        Task { @MainActor [weak self] in
            defer { sem.signal() }
            guard let self else { return }
            if method == "GET" && (path == "/v1/projectors" || path == "/v1/status") {
                let doc = FleetDocument(projectors: self.projectors)
                if let json = try? doc.encodeJSON() {
                    box.set(json)
                }
            } else if method == "POST" && path == "/v1/all/shutter/close" {
                self.setShutter(closed: true, on: self.projectors)
            } else if method == "POST" && path == "/v1/all/shutter/open" {
                self.setShutter(closed: false, on: self.projectors)
            } else if method == "POST" && path == "/v1/all/power/on" {
                self.setPower(on: true, on: self.projectors)
            } else if method == "POST" && path == "/v1/all/power/off" {
                self.setPower(on: false, on: self.projectors)
            } else if method == "POST" && path == "/v1/refresh" {
                self.refreshAll()
            } else {
                statusBox.set(404)
                box.set(Data("{\"error\":\"not found\"}".utf8))
            }
        }
        _ = sem.wait(timeout: .now() + 2.0)

        let body = box.get()
        let code = statusBox.get()
        let header = "HTTP/1.1 \(code) \(code == 200 ? "OK" : "Not Found")\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        _ = response.withUnsafeBytes { ptr in
            Darwin.send(fd, ptr.baseAddress!, response.count, 0)
        }
    }

    func stopAllServices() {
        pollTimer?.invalidate()
        pollTimer = nil
        oscServer?.stop()
        stopHTTPServer()
        demoRig.stopAll()
    }
}

/// Thread-safe value box for cross-isolation flags.
final class LockBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: T) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}
