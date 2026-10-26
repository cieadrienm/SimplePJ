import AppKit
import SimplePJCore
import SwiftUI

// MARK: - Stage Cards Grid View

struct CardsGridView: View {
    @Bindable var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 325, maximum: 460), spacing: 12)
    ]

    var body: some View {
        let items = model.fleet.visibleProjectors
        ScrollView {
            if items.isEmpty {
                emptyFilterState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { pj in
                        ProjectorCard(
                            projector: pj,
                            selected: model.fleet.selection.contains(pj.id),
                            model: model
                        )
                    }
                }
                .padding(14)
            }
        }
        .background(Theme.background.swiftUI)
    }

    private var emptyFilterState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textFaint.swiftUI)
            Text(L("Aucun vidéoprojecteur ne correspond au filtre actif", "No projector matches the active filter"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textDim.swiftUI)
            TextButton(title: L("Réinitialiser les filtres", "Reset Filters"), symbol: "arrow.counterclockwise", compact: true) {
                model.fleet.sidebarFilter = .all
                model.fleet.searchQuery = ""
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}

struct ProjectorCard: View {
    let projector: Projector
    let selected: Bool
    @Bindable var model: AppModel
    @State private var hovering = false
    @State private var showTelemetryPopover = false

    var body: some View {
        let online = projector.connectionState == .online
        let statusTint = Theme.statusColor(projector).swiftUI

        VStack(alignment: .leading, spacing: 11) {
            // Card Header: Optic badge + Title + Tags + IP/Model
            HStack(alignment: .top, spacing: 10) {
                ProjectorOpticBadge(projector: projector, size: 42)

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(projector.displayTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                            .lineLimit(1)
                        ForEach(projector.tags.prefix(3), id: \.self) { tag in
                            Chip(text: tag, tint: Theme.osc.swiftUI)
                        }
                        Spacer(minLength: 0)
                        statusPill
                    }

                    HStack(spacing: 6) {
                        Text(projector.endpointLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textDim.swiftUI)
                        if !projector.hardwareTitle.isEmpty {
                            Text("·").foregroundStyle(Theme.textFaint.swiftUI)
                            Text(projector.hardwareTitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textDim.swiftUI)
                                .lineLimit(1)
                        }
                        Text("· Cl.\(projector.pjlinkClass)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textFaint.swiftUI)
                    }
                }
            }

            // Primary Stage Controls: Big Shutter Toggle + Power + Freeze
            HStack(spacing: 7) {
                // Big Shutter / Blackout Button
                Button {
                    model.fleet.setShutter(closed: !projector.isShutterClosed, on: [projector])
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: projector.isShutterClosed ? "eye.slash.fill" : "sun.max.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(projector.isShutterClosed ? L("VOLET FERMÉ · NOIR", "SHUTTER CLOSED · BLACKOUT") : L("VOLET OUVERT", "SHUTTER OPEN"))
                            .font(.system(size: 11.5, weight: .bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(
                        !online ? Theme.textFaint.swiftUI
                            : (projector.isShutterClosed ? Theme.background.swiftUI : Theme.alive.swiftUI)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                !online ? Color.white.opacity(0.03)
                                    : (projector.isShutterClosed ? Theme.accent.swiftUI : Theme.alive.swiftUI.opacity(0.16))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        !online ? Color.white.opacity(0.06)
                                            : (projector.isShutterClosed ? Theme.accent.swiftUI : Theme.alive.swiftUI.opacity(0.45)),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!online)
                .help(projector.isShutterClosed ? L("Ouvrir le volet (AVMT 30)", "Open shutter (AVMT 30)") : L("Fermer le volet / Noir (AVMT 31)", "Close shutter / Blackout (AVMT 31)"))

                // Power toggle button
                Button {
                    model.requestPower(on: !projector.power.isLit, targets: [projector])
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: projector.power.isLit ? "power" : "moon.zzz.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(projector.power.shortLabel)
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundStyle(Theme.powerColor(projector.power, online: online).swiftUI)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.powerColor(projector.power, online: online).swiftUI.opacity(0.13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Theme.powerColor(projector.power, online: online).swiftUI.opacity(0.32), lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!online && projector.connectionState != .authRequired)
                .help(projector.power.isLit ? L("Mettre en veille (POWR 0)", "Standby (POWR 0)") : L("Allumer le vidéoprojecteur (POWR 1)", "Power on projector (POWR 1)"))

                // Freeze button (Class 2)
                if projector.pjlinkClass >= 2 {
                    Button {
                        model.fleet.setFreeze(!projector.freeze, on: [projector])
                    } label: {
                        Image(systemName: "snowflake")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(projector.freeze ? Theme.background.swiftUI : Theme.textDim.swiftUI)
                            .frame(width: 30, height: 29)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(projector.freeze ? Theme.tcp.swiftUI : Color.white.opacity(0.05))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!online)
                    .help(projector.freeze ? L("Dégeler l'image (%2FREZ 0)", "Unfreeze image (%2FREZ 0)") : L("Geler l'image (%2FREZ 1)", "Freeze image (%2FREZ 1)"))
                }

                // Optoma ProScene (ZU920ST) & Epson Pro L (EB-L1755U) Grid button
                if projector.supportsExtendedOptics || projector.activeTestPattern != .off {
                    let hasGrid = projector.activeTestPattern != .off
                    Button {
                        let next: OptomaTestPattern = hasGrid ? .off : .whiteGrid
                        model.fleet.setTestPattern(next, on: [projector])
                    } label: {
                        Image(systemName: "squareshape.split.3x3")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(hasGrid ? Theme.background.swiftUI : Theme.accent.swiftUI)
                            .frame(width: 30, height: 29)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(hasGrid ? Theme.accent.swiftUI : Theme.accent.swiftUI.opacity(0.12))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!online)
                    .help(
                        hasGrid
                            ? L("Masquer la grille de calage", "Hide Alignment Grid")
                            : L("Afficher la grille de calage (Optoma TCP:23 / Epson ESC/VP.net:3629)", "Show Alignment Grid (Optoma TCP:23 / Epson ESC/VP.net:3629)")
                    )
                }
            }

            // Quick Input Strip
            HStack(spacing: 5) {
                ForEach(projector.availableInputs.prefix(4)) { inp in
                    let isCurrent = projector.currentInput == inp.code
                    ActionChip(
                        text: inp.displayName,
                        tint: isCurrent ? Theme.tcp.swiftUI : Theme.textDim.swiftUI,
                        active: isCurrent,
                        help: L("Basculer sur l'entrée \(inp.fullLabel) (%1INPT \(inp.code))", "Switch to input \(inp.fullLabel) (%1INPT \(inp.code))")
                    ) {
                        model.fleet.setInput(inp.code, on: [projector])
                    }
                }
                Spacer(minLength: 0)
                if let res = projector.inputResolution, !res.isEmpty {
                    let displayRes = (res == "Aucun signal" || res == "No signal") ? L("Aucun signal", "No signal") : res
                    Text(displayRes)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle((res == "Aucun signal" || res == "No signal") ? Theme.textFaint.swiftUI : Theme.textDim.swiftUI)
                }
            }

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Footer Telemetry: Lamp hours, Filter hours, Health (ERST), Latency
            HStack(spacing: 10) {
                Button {
                    showTelemetryPopover.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Label(projector.lampSummary, systemImage: "lightbulb.fill")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Theme.textDim.swiftUI)

                        if let filt = projector.filterHours {
                            Label("\(filt) h", systemImage: "aqi.medium")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(projector.errors.filter != .ok ? Theme.warning.swiftUI : Theme.textFaint.swiftUI)
                        }

                        if !projector.errors.isHealthy {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9.5))
                                Text(projector.errors.summaryLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Theme.errorColor(projector.errors.highestSeverity).swiftUI)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Afficher le détail des lampes, du filtre et des 6 capteurs ERST", "Show lamp, filter, and 6-sensor ERST diagnostics"))
                .popover(isPresented: $showTelemetryPopover, arrowEdge: .bottom) {
                    ProjectorTelemetryPopover(projector: projector)
                }

                if projector.connectionState == .authRequired {
                    Button {
                        model.fleet.autoUnlockPassword(for: projector)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill").font(.system(size: 9.5))
                            Text(L("Tester mots de passe", "Test Passwords"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.accent.swiftUI)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                Text(Format.latency(projector.latencyMs))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(selected ? Theme.laneSelected.swiftUI : Theme.lane.swiftUI)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(
                            selected ? Theme.accent.swiftUI.opacity(0.85)
                                : (hovering ? statusTint.opacity(0.45) : Color.white.opacity(0.07)),
                            lineWidth: selected ? 1.5 : 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture {
            handleSelectionTap(projector.id)
        }
        .onHover { hovering = $0 }
        .contextMenu { projectorContextMenu(for: projector) }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch projector.connectionState {
        case .online:
            if projector.isProjectingLight {
                Chip(text: L("EN PROJECTION", "PROJECTING"), tint: Theme.alive.swiftUI, filled: false)
            } else if projector.isShutterClosed {
                Chip(text: L("NOIR", "BLACKOUT"), tint: Theme.accent.swiftUI, filled: true)
            } else {
                Chip(text: projector.power.shortLabel, tint: Theme.powerColor(projector.power).swiftUI)
            }
        case .polling:
            Chip(text: "SYNC…", tint: Theme.accent.swiftUI)
        case .authRequired:
            Chip(text: L("MOT DE PASSE", "PASSWORD"), tint: Theme.danger.swiftUI, filled: true)
        case .offline:
            Chip(text: L("HORS LIGNE", "OFFLINE"), tint: Theme.textFaint.swiftUI)
        case .unknown:
            Chip(text: L("EN ATTENTE", "PENDING"), tint: Theme.textFaint.swiftUI)
        }
    }

    private func handleSelectionTap(_ id: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if model.fleet.selection.contains(id) {
                model.fleet.selection.remove(id)
            } else {
                model.fleet.selection.insert(id)
            }
        } else {
            model.fleet.selection = [id]
        }
    }

    @ViewBuilder
    private func projectorContextMenu(for pj: Projector) -> some View {
        Button(pj.isShutterClosed ? L("Ouvrir le volet (AVMT 30)", "Open Shutter (AVMT 30)") : L("Fermer le volet / Noir (AVMT 31)", "Close Shutter / Blackout (AVMT 31)")) {
            model.fleet.setShutter(closed: !pj.isShutterClosed, on: [pj])
        }
        Button(pj.power.isLit ? L("Mettre en veille (POWR 0)…", "Standby (POWR 0)…") : L("Allumer (POWR 1)", "Power On (POWR 1)")) {
            model.requestPower(on: !pj.power.isLit, targets: [pj])
        }
        if pj.pjlinkClass >= 2 {
            Button(pj.freeze ? L("Dégeler l'image (FREZ 0)", "Unfreeze Image (FREZ 0)") : L("Geler l'image (FREZ 1)", "Freeze Image (FREZ 1)")) {
                model.fleet.setFreeze(!pj.freeze, on: [pj])
            }
        }
        Divider()
        Menu(L("Entrée vidéo", "Video Input")) {
            ForEach(pj.availableInputs) { inp in
                Button((pj.currentInput == inp.code ? "✓ " : "") + inp.fullLabel) {
                    model.fleet.setInput(inp.code, on: [pj])
                }
            }
        }
        Menu(L("Mire & Optique (Optoma ZU / Epson EB-L)", "Test Pattern & Lens (Optoma ZU / Epson EB-L)")) {
            ForEach(OptomaTestPattern.allCases) { pat in
                Button((pj.activeTestPattern == pat ? "✓ " : "") + pat.label) {
                    model.fleet.setTestPattern(pat, on: [pj])
                }
            }
            Divider()
            ForEach(OptomaLensAction.allCases) { act in
                Button(act.label) {
                    model.fleet.triggerLens(act, steps: 1, on: [pj])
                }
            }
        }
        Divider()
        Button(L("Nommer / #grouper dans l'inspecteur…", "Rename / #tag in Inspector…")) {
            model.fleet.selection = [pj.id]
            model.revealInspector()
            model.labelFocusRequest += 1
        }
        Button(L("Actualiser l'état PJLink", "Refresh PJLink Status")) {
            model.fleet.refresh([pj], includeIdentity: true)
        }
        if pj.connectionState == .authRequired {
            Button(L("Tester les mots de passe d'usine…", "Test Factory Passwords…")) {
                model.fleet.autoUnlockPassword(for: pj)
            }
        }
        Button(L("Ouvrir l'interface Web (http://\(pj.ip))", "Open Web Interface (http://\(pj.ip))")) {
            model.openWebInterface(pj)
        }
        if pj.mac != nil {
            Button("Wake-on-LAN") {
                model.wakeProjectors([pj])
            }
        }
        Button(L("Copier l'adresse IP", "Copy IP Address")) {
            AppModel.copyToPasteboard(pj.endpointLabel)
            model.flash(L("Adresse copiée", "Address copied"))
        }
        Divider()
        Button(L("Retirer du parc", "Remove from Fleet"), role: .destructive) {
            model.fleet.removeProjectors(ids: [pj.id])
        }
    }
}

// MARK: - High-Density Sortable Table View (with direct ProjectorManager-style inline controls)

struct ProjectorTableView: View {
    @Bindable var model: AppModel
    @State private var popoverProjectorID: UUID? = nil

    var body: some View {
        let items = model.fleet.visibleProjectors
        VStack(spacing: 0) {
            headerRow
            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, pj in
                        tableRow(pj, index: index)
                    }
                }
            }
        }
        .background(Theme.background.swiftUI)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            sortHeader(L("État", "State"), col: .status, width: 52)
            sortHeader(L("Projecteur", "Projector"), col: .name, width: nil)
            sortHeader(L("Adresse IP", "IP Address"), col: .ip, width: 72)
            sortHeader(L("Modèle", "Model"), col: .model, width: 92)
            sortHeader(L("Alim.", "Power"), col: .power, width: 68)
            sortHeader(L("Volet / Mute", "Shutter / Mute"), col: .shutter, width: 112)
            sortHeader(L("Entrée", "Input"), col: .input, width: 102)
            sortHeader(L("Lampe", "Lamp"), col: .lamp, width: 62)
            sortHeader(L("Latence", "Latency"), col: .latency, width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Theme.header.swiftUI)
    }

    private func sortHeader(_ title: String, col: ProjectorSortColumn, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        let active = model.fleet.sortColumn == col
        return Button {
            if active {
                model.fleet.sortAscending.toggle()
            } else {
                model.fleet.sortColumn = col
                model.fleet.sortAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .font(.system(size: 10.5, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                    .lineLimit(1)
                if active {
                    Image(systemName: model.fleet.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.accent.swiftUI)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tableRow(_ pj: Projector, index: Int) -> some View {
        let selected = model.fleet.selection.contains(pj.id)
        let online = pj.connectionState == .online
        let rowBg = selected ? Theme.laneSelected.swiftUI : (index.isMultiple(of: 2) ? Theme.lane.swiftUI : Theme.laneAlt.swiftUI)

        return HStack(spacing: 6) {
            // Status
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.statusColor(pj).swiftUI)
                    .frame(width: 7, height: 7)
                Text(online ? (pj.isProjectingLight ? L("Actif", "Live") : (pj.isShutterClosed ? L("Noir", "Black") : pj.power.label)) : pj.connectionState.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(online ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                    .lineLimit(1)
            }
            .frame(width: 52, alignment: .leading)

            // Name + Tag
            HStack(spacing: 5) {
                Text(pj.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let firstTag = pj.tags.first {
                    Chip(text: firstTag, tint: Theme.osc.swiftUI)
                        .fixedSize()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // IP
            Text(pj.endpointLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text.swiftUI)
                .lineLimit(1)
                .frame(width: 72, alignment: .leading)

            // Model
            Text(pj.hardwareTitle.isEmpty ? "—" : pj.hardwareTitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim.swiftUI)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)

            // Direct segmented Power switch: [ ON | OFF ]
            HStack(spacing: 0) {
                inlineSegmentButton(
                    title: "ON",
                    active: online && pj.power.isLit,
                    tint: Theme.alive.swiftUI,
                    disabled: !online
                ) {
                    model.requestPower(on: true, targets: [pj])
                }
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 18)
                inlineSegmentButton(
                    title: "OFF",
                    active: online && !pj.power.isLit,
                    tint: Theme.standby.swiftUI,
                    disabled: !online
                ) {
                    model.requestPower(on: false, targets: [pj])
                }
            }
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .frame(width: 68, alignment: .leading)

            // Direct segmented Shutter + Audio Mute: [ OUV | NOIR ] + speaker
            HStack(spacing: 3) {
                HStack(spacing: 0) {
                    inlineSegmentButton(
                        title: L("OUV", "OPEN"),
                        active: online && !pj.isShutterClosed,
                        tint: Theme.alive.swiftUI,
                        disabled: !online
                    ) {
                        model.fleet.setShutter(closed: false, on: [pj])
                    }
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 18)
                    inlineSegmentButton(
                        title: L("NOIR", "BLK"),
                        active: online && pj.isShutterClosed,
                        tint: Theme.accent.swiftUI,
                        filledWhenActive: true,
                        disabled: !online
                    ) {
                        model.fleet.setShutter(closed: true, on: [pj])
                    }
                }
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                Button {
                    model.fleet.setAudioMute(!pj.shutter.isAudioMuted, on: pj)
                } label: {
                    Image(systemName: pj.shutter.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(
                            !online ? Theme.textFaint.swiftUI
                                : (pj.shutter.isAudioMuted ? Theme.accent.swiftUI : Theme.textDim.swiftUI)
                        )
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(pj.shutter.isAudioMuted && online ? Theme.accent.swiftUI.opacity(0.18) : Color.white.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!online)
                .help(pj.shutter.isAudioMuted ? L("Rétablir le son (AVMT 20)", "Unmute audio (AVMT 20)") : L("Couper le son (AVMT 21)", "Mute audio (AVMT 21)"))
            }
            .frame(width: 112, alignment: .leading)

            // Direct 1-click Input Dropdown Menu + Signal resolution
            Menu {
                ForEach(pj.availableInputs) { inp in
                    Button {
                        model.fleet.setInput(inp.code, on: [pj])
                    } label: {
                        Text((pj.currentInput == inp.code ? "✓ " : "") + inp.fullLabel)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(pj.currentInputDisplayName)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(online ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                            .lineLimit(1)
                        if let res = pj.inputResolution {
                            Text(res)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.textFaint.swiftUI)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(!online)
            .frame(width: 102, alignment: .leading)
            .help(L("Changer l'entrée vidéo (%1INPT)", "Switch video input (%1INPT)"))

            // Clickable Lamp & ERST Health Popover
            Button {
                popoverProjectorID = (popoverProjectorID == pj.id) ? nil : pj.id
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: pj.maxLampHours.map { "\($0) h" } ?? "—")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        .lineLimit(1)
                    if !pj.errors.isHealthy {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.errorColor(pj.errors.highestSeverity).swiftUI)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 62, alignment: .leading)
            .help(L("Détail des lampes, du filtre et des 6 capteurs ERST", "Lamp, filter, and 6-sensor ERST diagnostics"))
            .popover(
                isPresented: Binding(
                    get: { popoverProjectorID == pj.id },
                    set: { if !$0 && popoverProjectorID == pj.id { popoverProjectorID = nil } }
                ),
                arrowEdge: .bottom
            ) {
                ProjectorTelemetryPopover(projector: pj)
            }

            // Latency
            Text(Format.latency(pj.latencyMs))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textFaint.swiftUI)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(rowBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.03)).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                if model.fleet.selection.contains(pj.id) {
                    model.fleet.selection.remove(pj.id)
                } else {
                    model.fleet.selection.insert(pj.id)
                }
            } else {
                model.fleet.selection = [pj.id]
            }
        }
    }

    private func inlineSegmentButton(
        title: String,
        active: Bool,
        tint: Color,
        filledWhenActive: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    disabled ? Theme.textFaint.swiftUI
                        : (active ? (filledWhenActive ? Theme.background.swiftUI : tint) : Theme.textDim.swiftUI)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .background(
                    active && !disabled
                        ? (filledWhenActive ? tint : tint.opacity(0.18))
                        : Color.clear
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Lamp & 6-Sensor ERST Popover (inspired by ProjectorManager's Lamp & Error popovers)

struct ProjectorTelemetryPopover: View {
    let projector: Projector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(projector.displayTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                Text(projector.endpointLabel)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textDim.swiftUI)
            }

            Divider()

            Text(L("LAMPES / SOURCES LASER (%1LAMP)", "LAMPS / LASER SOURCES (%1LAMP)"))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textDim.swiftUI)

            if projector.lamps.isEmpty {
                Text(L("Aucune donnée lampe reçue", "No lamp data received"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            } else {
                ForEach(Array(projector.lamps.enumerated()), id: \.offset) { idx, lamp in
                    HStack {
                        Circle()
                            .fill(lamp.isOn ? Theme.alive.swiftUI : Theme.standby.swiftUI)
                            .frame(width: 7, height: 7)
                        Text(L("Lampe \(idx + 1)", "Lamp \(idx + 1)"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text.swiftUI)
                        Spacer()
                        Text(verbatim: "\(lamp.hours) h · \(lamp.isOn ? L("Allumée", "On") : L("Éteinte", "Off"))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                }
            }

            if let filter = projector.filterHours {
                HStack {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    Text(L("Filtre optique (%2FILT)", "Optical filter (%2FILT)"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text.swiftUI)
                    Spacer()
                    Text(verbatim: "\(filter) h")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
            }

            Divider()

            Text(L("DIAGNOSTIC 6 CAPTEURS (%1ERST : \(projector.errors.rawCode))", "6-SENSOR DIAGNOSTICS (%1ERST: \(projector.errors.rawCode))"))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textDim.swiftUI)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(projector.errors.components, id: \.name) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.errorColor(item.level).swiftUI)
                            .frame(width: 7, height: 7)
                        Text(item.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text.swiftUI)
                        Spacer(minLength: 0)
                        Text(item.level.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.errorColor(item.level).swiftUI)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.04)))
                }
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(Theme.panel.swiftUI)
    }
}

// MARK: - Empty / Welcome View

struct WelcomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        let pmCount = model.fleet.projectorManagerEntryCount
        VStack(spacing: 18) {
            ProjectorHeroGraphic(active: model.fleet.isScanning, size: 118)

            VStack(spacing: 6) {
                Text(model.fleet.isScanning ? L("Recherche des vidéoprojecteurs PJLink…", "Scanning for PJLink Projectors…") : L("Contrôle PJLink de plateau", "Stage PJLink Control"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)

                Text(L("Découverte automatique des vidéoprojecteurs PJLink (Classe 1 & 2, port 4352) sur le sous-réseau,\nou lancement d'un plateau simulé de 4 projecteurs pour préparer les conduites et commandes OSC.", "Automatic discovery of PJLink projectors (Class 1 & 2, port 4352) on the subnet,\nor 4-projector simulated stage rig for offline cue and OSC preparation."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
            }

            HStack(spacing: 10) {
                TextButton(
                    title: L("Découvrir \(model.fleet.rangeInput)", "Discover \(model.fleet.rangeInput)"),
                    symbol: "dot.radiowaves.left.and.right",
                    prominent: true,
                    disabled: !model.fleet.canStartScan
                ) {
                    model.fleet.startDiscovery()
                }

                TextButton(
                    title: L("Ajouter une IP…", "Add IP…"),
                    symbol: "plus"
                ) {
                    model.showAddProjector = true
                }

                TextButton(
                    title: L("Simuler un plateau (4 VP)", "Simulate Stage Rig (4 PJ)"),
                    symbol: "play.tv",
                    tint: Theme.alive.swiftUI
                ) {
                    model.fleet.toggleSimulatedStageRig()
                }

                if pmCount > 0 {
                    TextButton(
                        title: L("Importer ProjectorManager (\(pmCount) VP)", "Import ProjectorManager (\(pmCount) PJ)"),
                        symbol: "square.and.arrow.down",
                        tint: Theme.osc.swiftUI
                    ) {
                        model.importFromProjectorManager()
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.swiftUI)
    }
}
