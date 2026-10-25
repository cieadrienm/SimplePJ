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
            Text("Aucun vidéoprojecteur ne correspond au filtre actif")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textDim.swiftUI)
            TextButton(title: "Réinitialiser les filtres", symbol: "arrow.counterclockwise", compact: true) {
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
                        Text(projector.isShutterClosed ? "VOLET FERMÉ · NOIR" : "VOLET OUVERT")
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
                .help(projector.isShutterClosed ? "Ouvrir le volet (AVMT 30)" : "Fermer le volet / Noir (AVMT 31)")

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
                .help(projector.power.isLit ? "Mettre en veille (POWR 0)" : "Allumer le vidéoprojecteur (POWR 1)")

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
                    .help(projector.freeze ? "Dégeler l'image (%2FREZ 0)" : "Geler l'image (%2FREZ 1)")
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
                        help: "Basculer sur l'entrée \(inp.fullLabel) (%1INPT \(inp.code))"
                    ) {
                        model.fleet.setInput(inp.code, on: [projector])
                    }
                }
                Spacer(minLength: 0)
                if let res = projector.inputResolution, !res.isEmpty {
                    Text(res)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(res == "Aucun signal" ? Theme.textFaint.swiftUI : Theme.textDim.swiftUI)
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
                .help("Afficher le détail des lampes, du filtre et des 6 capteurs ERST")
                .popover(isPresented: $showTelemetryPopover, arrowEdge: .bottom) {
                    ProjectorTelemetryPopover(projector: projector)
                }

                if projector.connectionState == .authRequired {
                    Button {
                        model.fleet.autoUnlockPassword(for: projector)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill").font(.system(size: 9.5))
                            Text("Tester mots de passe")
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
                Chip(text: "EN PROJECTION", tint: Theme.alive.swiftUI, filled: false)
            } else if projector.isShutterClosed {
                Chip(text: "NOIR", tint: Theme.accent.swiftUI, filled: true)
            } else {
                Chip(text: projector.power.shortLabel, tint: Theme.powerColor(projector.power).swiftUI)
            }
        case .polling:
            Chip(text: "SYNC…", tint: Theme.accent.swiftUI)
        case .authRequired:
            Chip(text: "MOT DE PASSE", tint: Theme.danger.swiftUI, filled: true)
        case .offline:
            Chip(text: "HORS LIGNE", tint: Theme.textFaint.swiftUI)
        case .unknown:
            Chip(text: "EN ATTENTE", tint: Theme.textFaint.swiftUI)
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
        Button(pj.isShutterClosed ? "Ouvrir le volet (AVMT 30)" : "Fermer le volet / Noir (AVMT 31)") {
            model.fleet.setShutter(closed: !pj.isShutterClosed, on: [pj])
        }
        Button(pj.power.isLit ? "Mettre en veille (POWR 0)…" : "Allumer (POWR 1)") {
            model.requestPower(on: !pj.power.isLit, targets: [pj])
        }
        if pj.pjlinkClass >= 2 {
            Button(pj.freeze ? "Dégeler l'image (FREZ 0)" : "Geler l'image (FREZ 1)") {
                model.fleet.setFreeze(!pj.freeze, on: [pj])
            }
        }
        Divider()
        Menu("Entrée vidéo") {
            ForEach(pj.availableInputs) { inp in
                Button((pj.currentInput == inp.code ? "✓ " : "") + inp.fullLabel) {
                    model.fleet.setInput(inp.code, on: [pj])
                }
            }
        }
        Divider()
        Button("Nommer / #grouper dans l'inspecteur…") {
            model.fleet.selection = [pj.id]
            model.revealInspector()
            model.labelFocusRequest += 1
        }
        Button("Actualiser l'état PJLink") {
            model.fleet.refresh([pj], includeIdentity: true)
        }
        if pj.connectionState == .authRequired {
            Button("Tester les mots de passe d'usine…") {
                model.fleet.autoUnlockPassword(for: pj)
            }
        }
        Button("Ouvrir l'interface Web (http://\(pj.ip))") {
            model.openWebInterface(pj)
        }
        if pj.mac != nil {
            Button("Wake-on-LAN") {
                model.wakeProjectors([pj])
            }
        }
        Button("Copier l'adresse IP") {
            AppModel.copyToPasteboard(pj.endpointLabel)
            model.flash("Adresse copiée")
        }
        Divider()
        Button("Retirer du parc", role: .destructive) {
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
            sortHeader("État", col: .status, width: 52)
            sortHeader("Projecteur", col: .name, width: nil)
            sortHeader("Adresse IP", col: .ip, width: 72)
            sortHeader("Modèle", col: .model, width: 92)
            sortHeader("Alim.", col: .power, width: 68)
            sortHeader("Volet / Mute", col: .shutter, width: 112)
            sortHeader("Entrée", col: .input, width: 102)
            sortHeader("Lampe", col: .lamp, width: 62)
            sortHeader("Latence", col: .latency, width: 54, alignment: .trailing)
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
                Text(online ? (pj.isProjectingLight ? "Actif" : (pj.isShutterClosed ? "Noir" : pj.power.label)) : pj.connectionState.label)
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
                        title: "OUV",
                        active: online && !pj.isShutterClosed,
                        tint: Theme.alive.swiftUI,
                        disabled: !online
                    ) {
                        model.fleet.setShutter(closed: false, on: [pj])
                    }
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 18)
                    inlineSegmentButton(
                        title: "NOIR",
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
                .help(pj.shutter.isAudioMuted ? "Rétablir le son (AVMT 20)" : "Couper le son (AVMT 21)")
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
            .help("Changer l'entrée vidéo (%1INPT)")

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
            .help("Détail des lampes, du filtre et des 6 capteurs ERST")
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

            Text("LAMPES / SOURCES LASER (%1LAMP)")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textDim.swiftUI)

            if projector.lamps.isEmpty {
                Text("Aucune donnée lampe reçue")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            } else {
                ForEach(Array(projector.lamps.enumerated()), id: \.offset) { idx, lamp in
                    HStack {
                        Circle()
                            .fill(lamp.isOn ? Theme.alive.swiftUI : Theme.standby.swiftUI)
                            .frame(width: 7, height: 7)
                        Text("Lampe \(idx + 1)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text.swiftUI)
                        Spacer()
                        Text(verbatim: "\(lamp.hours) h · \(lamp.isOn ? "Allumée" : "Éteinte")")
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
                    Text("Filtre optique (%2FILT)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text.swiftUI)
                    Spacer()
                    Text(verbatim: "\(filter) h")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
            }

            Divider()

            Text("DIAGNOSTIC 6 CAPTEURS (%1ERST : \(projector.errors.rawCode))")
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
                Text(model.fleet.isScanning ? "Recherche des vidéoprojecteurs PJLink…" : "Contrôle PJLink de plateau")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)

                Text("Découvrez automatiquement tous les vidéoprojecteurs PJLink (Classe 1 & 2, port 4352) sur votre sous-réseau,\nou lancez un plateau simulé de 4 projecteurs pour préparer vos conduites et commandes OSC.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
            }

            HStack(spacing: 10) {
                TextButton(
                    title: "Découvrir \(model.fleet.rangeInput)",
                    symbol: "dot.radiowaves.left.and.right",
                    prominent: true,
                    disabled: !model.fleet.canStartScan
                ) {
                    model.fleet.startDiscovery()
                }

                TextButton(
                    title: "Ajouter une IP…",
                    symbol: "plus"
                ) {
                    model.showAddProjector = true
                }

                TextButton(
                    title: "Simuler un plateau (4 VP)",
                    symbol: "play.tv",
                    tint: Theme.alive.swiftUI
                ) {
                    model.fleet.toggleSimulatedStageRig()
                }

                if pmCount > 0 {
                    TextButton(
                        title: "Importer ProjectorManager (\(pmCount) VP)",
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
