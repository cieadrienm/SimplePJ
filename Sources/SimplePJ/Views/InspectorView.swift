import SimplePJCore
import SwiftUI

struct InspectorView: View {
    @Bindable var model: AppModel
    @FocusState private var labelFocused: Bool
    @State private var rawCommandInput: String = "%1POWR ?"
    @State private var forceShowOptomaPanel: Bool = false

    var body: some View {
        Group {
            if let pj = model.inspectedProjector {
                projectorDetails(pj)
            } else if model.fleet.selection.count > 1 {
                multiSelectionDetails
            } else {
                emptySelectionPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.panel.swiftUI)
        .onChange(of: model.labelFocusRequest) { _, _ in labelFocused = true }
    }

    // MARK: - Single Projector Inspector

    private func projectorDetails(_ pj: Projector) -> some View {
        let online = pj.connectionState == .online
        return ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                headerSection(pj)
                identityEditSection(pj)
                separator
                shutterAndPowerSection(pj, online: online)
                separator
                optomaOpticsAndGridSection(pj, online: online)
                separator
                inputsSection(pj, online: online)
                separator
                healthAndLampsSection(pj)
                separator
                hardwareInfoSection(pj)
                separator
                directCommandSection(pj)
                separator
                actionsFooterSection(pj)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(pj.id)
    }

    private var separator: some View {
        Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)
    }

    private func headerSection(_ pj: Projector) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ProjectorOpticBadge(projector: pj, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(pj.displayTitle)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(pj.endpointLabel)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        .textSelection(.enabled)
                    Chip(text: L("CLASSE \(pj.pjlinkClass)", "CLASS \(pj.pjlinkClass)"), tint: pj.pjlinkClass >= 2 ? Theme.tcp.swiftUI : Theme.textDim.swiftUI)
                    if pj.isSimulated {
                        Chip(text: L("SIMULÉ", "SIMULATED"), tint: Theme.osc.swiftUI)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(Theme.statusColor(pj).swiftUI).frame(width: 6, height: 6)
                    Text(pj.connectionState.label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    if let lat = pj.latencyMs {
                        Text("· \(Format.latency(lat))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Theme.textFaint.swiftUI)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func identityEditSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader(L("Plateau & Accès", "Stage & Access"))
            FieldRow(L("Nom & #tags", "Name & #tags"), width: 84) {
                CommitField(
                    value: pj.label ?? "",
                    placeholder: L("Face Cour #face #cour", "Stage Left #front #left"),
                    onCommit: { text in
                        model.fleet.updateProjector(pj.id) { $0.label = text.isEmpty ? nil : text }
                    }
                )
                .focused($labelFocused)
            }
            FieldRow(L("Mot de passe", "Password"), width: 84) {
                HStack(spacing: 5) {
                    CommitField(
                        value: pj.password,
                        placeholder: pj.requiresAuth ? L("Requis (PJLINK 1)", "Required (PJLINK 1)") : L("Aucun (PJLINK 0)", "None (PJLINK 0)"),
                        monospaced: true,
                        onCommit: { pwd in
                            model.fleet.updateProjector(pj.id) { $0.password = pwd }
                            if let updated = model.fleet.projectors.first(where: { $0.id == pj.id }) {
                                model.fleet.refresh([updated], includeIdentity: true)
                            }
                        }
                    )
                    if pj.connectionState == .authRequired || pj.requiresAuth {
                        IconButton(
                            symbol: "key.fill",
                            helpText: L("Tester automatiquement les mots de passe PJLink d'usine (panasonic, admin, JBMIA, 0000…)", "Automatically test factory PJLink passwords (panasonic, admin, JBMIA, 0000…)"),
                            tint: Theme.accent.swiftUI
                        ) {
                            model.fleet.autoUnlockPassword(for: pj)
                        }
                    }
                }
            }
            FieldRow(L("Notes régie", "Stage notes"), width: 84) {
                CommitField(
                    value: pj.notes ?? "",
                    placeholder: L("Optique 0.8:1 · Pont face · Patch HDMI 1", "Lens 0.8:1 · Front truss · HDMI 1 patch"),
                    onCommit: { notes in
                        model.fleet.updateProjector(pj.id) { $0.notes = notes.isEmpty ? nil : notes }
                    }
                )
            }
        }
    }

    private func shutterAndPowerSection(_ pj: Projector, online: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(L("Volet (Obturateur) & Alimentation", "Shutter & Power")) {
                Text(pj.shutter.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(pj.isShutterClosed ? Theme.accent.swiftUI : Theme.alive.swiftUI)
            }

            // Big Shutter Open / Close pair
            HStack(spacing: 6) {
                TextButton(
                    title: L("NOIR · Fermer (31)", "BLACKOUT · Close (31)"),
                    symbol: "eye.slash.fill",
                    prominent: pj.isShutterClosed,
                    tint: Theme.accent.swiftUI,
                    disabled: !online
                ) {
                    model.fleet.setShutter(closed: true, on: [pj])
                }
                TextButton(
                    title: L("Ouvrir volet (30)", "Open Shutter (30)"),
                    symbol: "sun.max.fill",
                    prominent: online && !pj.isShutterClosed,
                    tint: Theme.alive.swiftUI,
                    disabled: !online
                ) {
                    model.fleet.setShutter(closed: false, on: [pj])
                }
            }

            // Granular Video / Audio / Freeze controls
            HStack(spacing: 6) {
                TextButton(
                    title: pj.shutter.isVideoMuted ? L("Vidéo coupée", "Video Muted") : L("Vidéo seule", "Video Mute"),
                    symbol: "video.slash.fill",
                    compact: true,
                    disabled: !online
                ) {
                    model.fleet.setVideoMute(!pj.shutter.isVideoMuted, on: pj)
                }
                TextButton(
                    title: pj.shutter.isAudioMuted ? L("Audio coupé", "Audio Muted") : L("Audio seul", "Audio Mute"),
                    symbol: "speaker.slash.fill",
                    compact: true,
                    disabled: !online
                ) {
                    model.fleet.setAudioMute(!pj.shutter.isAudioMuted, on: pj)
                }
                if pj.pjlinkClass >= 2 {
                    TextButton(
                        title: pj.freeze ? L("Gel actif", "Frozen") : L("Gel (Freeze)", "Freeze"),
                        symbol: "snowflake",
                        prominent: pj.freeze,
                        tint: Theme.tcp.swiftUI,
                        compact: true,
                        disabled: !online
                    ) {
                        model.fleet.setFreeze(!pj.freeze, on: [pj])
                    }
                }
            }

            // Power On / Standby
            HStack(spacing: 6) {
                TextButton(
                    title: L("Allumer (POWR 1)", "Power On (POWR 1)"),
                    symbol: "power",
                    prominent: pj.power == .on,
                    tint: Theme.alive.swiftUI,
                    compact: true,
                    disabled: !online
                ) {
                    model.requestPower(on: true, targets: [pj])
                }
                TextButton(
                    title: L("Mettre en veille (POWR 0)", "Standby (POWR 0)"),
                    symbol: "moon.zzz.fill",
                    prominent: pj.power == .standby,
                    tint: Theme.standby.swiftUI,
                    compact: true,
                    disabled: !online
                ) {
                    model.requestPower(on: false, targets: [pj])
                }
            }
        }
    }

    // MARK: - Optoma ProScene (ZU920ST) & Epson Pro L (EB-L1755U + ELPLU03/03S) Test Pattern & Motorized Optics

    private func optomaOpticsAndGridSection(_ pj: Projector, online: Bool) -> some View {
        let isExpanded = pj.supportsExtendedOptics || forceShowOptomaPanel || pj.activeTestPattern != .off
        let headerTitle: String = {
            if pj.isPanasonic {
                return L("Optique & Mire (Panasonic PT-RZ / PT-RQ)", "Optics & Test Pattern (Panasonic PT-RZ / PT-RQ)")
            } else if pj.isEpson {
                return L("Optique & Mire (Epson EB-L / ELPLU03)", "Optics & Test Pattern (Epson EB-L / ELPLU03)")
            } else {
                return L("Optique & Mire (Optoma ProScene)", "Optics & Test Pattern (Optoma)")
            }
        }()
        return VStack(alignment: .leading, spacing: 9) {
            SectionHeader(headerTitle) {
                HStack(spacing: 5) {
                    if pj.isPanasonic {
                        Chip(text: "NTCONTROL :1024", tint: Theme.alive.swiftUI)
                    } else if pj.isEpson {
                        Chip(text: "ESC/VP.net · ELPLU03", tint: Theme.tcp.swiftUI)
                    } else if pj.isOptoma {
                        Chip(text: "ZU PROSCENE", tint: Theme.accent.swiftUI)
                    }
                    Button {
                        forceShowOptomaPanel.toggle()
                    } label: {
                        Text(isExpanded ? L("Masquer", "Hide") : L("Afficher ▾", "Show ▾"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded {
                // 1. Test Pattern / Grid (Panasonic 00OTS:07 / Epson POPPAT / Optoma ~00195)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(
                            pj.isPanasonic
                                ? L("Mire interne / Grille (00OTS:07 / proj_ctl.cgi)", "Internal Test Pattern / Grid (00OTS:07 / proj_ctl.cgi)")
                                : (pj.isEpson
                                    ? L("Mire interne / Grille (POPPAT / KEY 90)", "Internal Test Pattern / Grid (POPPAT / KEY 90)")
                                    : L("Mire interne / Grille (~00195)", "Internal Test Pattern / Grid (~00195)"))
                        )
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        Spacer()
                        if pj.activeTestPattern != .off {
                            Text(pj.activeTestPattern.label)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.accent.swiftUI)
                        }
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 5),
                        GridItem(.flexible(), spacing: 5),
                        GridItem(.flexible(), spacing: 5),
                    ], spacing: 5) {
                        ForEach([
                            OptomaTestPattern.off,
                            .whiteGrid,
                            .greenGrid,
                            .magentaGrid,
                            .white,
                            .colorBars,
                        ]) { pat in
                            let active = pj.activeTestPattern == pat
                            let tint: Color = {
                                switch pat {
                                case .off: return Theme.textDim.swiftUI
                                case .whiteGrid, .white: return Theme.text.swiftUI
                                case .greenGrid: return Theme.alive.swiftUI
                                case .magentaGrid: return Theme.osc.swiftUI
                                case .black: return Theme.textDim.swiftUI
                                case .colorBars: return Theme.accent.swiftUI
                                }
                            }()
                            Button {
                                model.fleet.setTestPattern(pat, on: [pj])
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: pat.symbol)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(pat.shortLabel)
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .foregroundStyle(active ? Theme.background.swiftUI : tint)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(active ? tint : Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .strokeBorder(active ? tint : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(
                                pj.isPanasonic
                                    ? "\(pat.label) · NTCONTROL:1024 \(pat.panasonicNTCommand) / HTTP /cgi-bin/proj_ctl.cgi"
                                    : (pj.isEpson
                                        ? "\(pat.label) · ESC/VP.net:3629 \(pat.epsonESCVPCommands.first ?? "") / HTTP /cgi-bin/directsend"
                                        : "\(pat.label) · TCP:23 \(pat.rs232Command) / HTTP /tgi/control.tgi")
                            )
                        }
                    }
                }

                // 2. Motorized Lens Shift + Focus + Zoom (+ Distortion for Epson ELPLU03/03S)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(
                            pj.isPanasonic
                                ? L("Optique motorisée (VXX:LNSI2..5 / Home LNSI1)", "Motorized Lens (VXX:LNSI2..5 / Home LNSI1)")
                                : (pj.isEpson
                                    ? L("Optique motorisée ELPLU03 / 03S (LENS / HLENS / FOCUS / ZOOM)", "Motorized Lens ELPLU03 / 03S (LENS / HLENS / FOCUS / ZOOM)")
                                    : L("Bloc optique motorisé (Shift / Focus / Zoom)", "Motorized Lens (Shift / Focus / Zoom)"))
                        )
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach([1, 3, 6], id: \.self) { step in
                                let sel = model.lensStepMultiplier == step
                                Button {
                                    model.lensStepMultiplier = step
                                } label: {
                                    Text("×\(step)")
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .foregroundStyle(sel ? Theme.background.swiftUI : Theme.textDim.swiftUI)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(sel ? Theme.accent.swiftUI : Color.white.opacity(0.05))
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(L("Nombre d'impulsions moteur par clic ou flèche clavier (×\(step))", "Motor step impulses per click or arrow key (×\(step))"))
                            }
                        }
                    }

                    HStack(alignment: .center, spacing: 10) {
                        // Directional D-Pad for Lens Shift H/V
                        VStack(spacing: 3) {
                            VStack(spacing: 4) {
                                lensPadButton(symbol: "chevron.up", action: .shiftUp, pj: pj)
                                HStack(spacing: 4) {
                                    lensPadButton(symbol: "chevron.left", action: .shiftLeft, pj: pj)
                                    lensPadButton(symbol: "scope", action: .lensCenter, pj: pj, tint: Theme.tcp.swiftUI)
                                    lensPadButton(symbol: "chevron.right", action: .shiftRight, pj: pj)
                                }
                                lensPadButton(symbol: "chevron.down", action: .shiftDown, pj: pj)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.22)))

                            Text(L("↑↓←→ Clavier (⇧×3)", "↑↓←→ Keys (⇧×3)"))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.textFaint.swiftUI)
                        }

                        // Focus / Zoom / Distortion / Lens Lock column
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 5) {
                                Text("Focus")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .frame(width: 44, alignment: .leading)
                                TextButton(title: "−", symbol: "minus.magnifyingglass", compact: true) {
                                    model.fleet.triggerLens(.focusMinus, steps: model.lensStepMultiplier, on: [pj])
                                }
                                TextButton(title: "+", symbol: "plus.magnifyingglass", compact: true) {
                                    model.fleet.triggerLens(.focusPlus, steps: model.lensStepMultiplier, on: [pj])
                                }
                            }
                            HStack(spacing: 5) {
                                Text("Zoom")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .frame(width: 44, alignment: .leading)
                                TextButton(title: "−", symbol: "arrow.down.right.and.arrow.up.left", compact: true) {
                                    model.fleet.triggerLens(.zoomMinus, steps: model.lensStepMultiplier, on: [pj])
                                }
                                TextButton(title: "+", symbol: "arrow.up.left.and.arrow.down.right", compact: true) {
                                    model.fleet.triggerLens(.zoomPlus, steps: model.lensStepMultiplier, on: [pj])
                                }
                            }
                            if pj.isEpson {
                                HStack(spacing: 5) {
                                    Text(L("Distors.", "Distort."))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Theme.textDim.swiftUI)
                                        .frame(width: 44, alignment: .leading)
                                    TextButton(title: "−", symbol: "trapezoid.and.line.horizontal", compact: true) {
                                        model.fleet.triggerLens(.distortionMinus, steps: model.lensStepMultiplier, on: [pj])
                                    }
                                    TextButton(title: "+", symbol: "trapezoid.and.line.vertical", compact: true) {
                                        model.fleet.triggerLens(.distortionPlus, steps: model.lensStepMultiplier, on: [pj])
                                    }
                                }
                            }
                            HStack(spacing: 5) {
                                TextButton(
                                    title: L("Déverr. optique", "Unlock Lens"),
                                    symbol: "lock.open.fill",
                                    compact: true
                                ) {
                                    model.fleet.triggerLens(.lensUnlock, steps: 1, on: [pj])
                                }
                                TextButton(
                                    title: L("Verr.", "Lock"),
                                    symbol: "lock.fill",
                                    compact: true
                                ) {
                                    model.fleet.triggerLens(.lensLock, steps: 1, on: [pj])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func lensPadButton(
        symbol: String,
        action: OptomaLensAction,
        pj: Projector,
        tint: Color = Theme.text.swiftUI
    ) -> some View {
        let isActive = model.activeLensAction == action
        return Button {
            let fast = NSEvent.modifierFlags.contains(.option) || NSEvent.modifierFlags.contains(.shift)
            let steps = fast ? max(3, model.lensStepMultiplier * 3) : model.lensStepMultiplier
            model.fleet.triggerLens(action, steps: steps, on: [pj])
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? Theme.background.swiftUI : tint)
                .frame(width: 28, height: 25)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isActive ? Theme.accent.swiftUI : Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isActive ? Theme.accent.swiftUI : Color.white.opacity(0.11), lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(action.label) (\(pj.isPanasonic ? action.panasonicNTCommand() : (pj.isEpson ? (action.epsonESCVPCommands.first ?? "") : (action.rs232Commands.first ?? "")))) · ↑↓←→ ou ⇧/⌥ = pas rapide")
    }

    private func inputsSection(_ pj: Projector, online: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(L("Entrées Vidéo (INPT / INST)", "Video Inputs (INPT / INST)")) {
                if let res = pj.inputResolution {
                    Text(res)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tcp.swiftUI)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(pj.availableInputs) { inp in
                    let active = pj.currentInput == inp.code
                    Button {
                        model.fleet.setInput(inp.code, on: [pj])
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: inp.category.symbol)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(active ? Theme.background.swiftUI : Theme.tcp.swiftUI)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(inp.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(active ? Theme.background.swiftUI : Theme.text.swiftUI)
                                    .lineLimit(1)
                                Text("Code \(inp.code) · \(inp.category.label)")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(active ? Theme.background.swiftUI.opacity(0.75) : Theme.textFaint.swiftUI)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(active ? Theme.tcp.swiftUI : Color.white.opacity(0.05))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!online)
                }
            }
            if let native = pj.nativeResolution {
                Text(L("Matrice native : \(native)", "Native matrix: \(native)") + (pj.inputResolution.map { L(" · Signal reçu : \($0)", " · Input signal: \($0)") } ?? ""))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
        }
    }

    private func healthAndLampsSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(L("Santé & Source lumineuse (ERST / LAMP)", "Health & Light Source (ERST / LAMP)")) {
                Chip(
                    text: pj.errors.isHealthy ? "OK · 000000" : pj.errors.rawCode,
                    tint: Theme.errorColor(pj.errors.highestSeverity).swiftUI
                )
            }

            // 6-sensor ERST grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 5) {
                ForEach(pj.errors.components, id: \.name) { item in
                    let color = Theme.errorColor(item.level).swiftUI
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(item.name)
                            .font(.system(size: 10.5, weight: item.level == .ok ? .regular : .semibold))
                            .foregroundStyle(item.level == .ok ? Theme.textDim.swiftUI : color)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(item.level.label)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(item.level == .ok ? Theme.textFaint.swiftUI : color)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.035)))
                }
            }

            // Lamps & Filter hours
            ForEach(pj.lamps, id: \.index) { lamp in
                infoRow(L("Source #\(lamp.index)", "Source #\(lamp.index)"), "\(Format.hours(lamp.hours)) · \(lamp.isOn ? L("Allumée", "On") : L("Éteinte", "Off"))")
            }
            if let filter = pj.filterHours {
                infoRow(L("Filtre (FILT)", "Filter (FILT)"), Format.hours(filter))
            }
            if let rlmp = pj.replacementLamp {
                infoRow(L("Réf. source", "Lamp part"), rlmp)
            }
            if let rfil = pj.replacementFilter {
                infoRow(L("Réf. filtre", "Filter part"), rfil)
            }
        }
    }

    private func hardwareInfoSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(L("Identité PJLink", "PJLink Identity"))
            infoRow(L("Nom PJLink", "PJLink Name"), pj.pjlinkName ?? "—")
            infoRow(L("Fabricant", "Manufacturer"), pj.manufacturer ?? "—")
            infoRow(L("Modèle", "Model"), pj.modelName ?? "—")
            if let info = pj.extraInfo, !info.isEmpty {
                infoRow("Infos (INFO)", info)
            }
            if let sn = pj.serialNumber {
                infoRow(L("N° de série", "Serial No."), sn)
            }
            if let fw = pj.firmwareVersion {
                infoRow("Firmware", fw)
            }
            if let mac = pj.mac {
                infoRow(L("Adresse MAC", "MAC Address"), mac)
            }
            let slug = pj.displayTitle.lowercased().replacingOccurrences(of: " ", with: "-")
            infoRow(L("Adresse OSC", "OSC Address"), "/simplepj/pj/\(slug)/shutter")
        }
    }

    private func directCommandSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader(L("Commande PJLink directe", "Direct PJLink Command"))
            HStack(spacing: 6) {
                CommitField(
                    value: rawCommandInput,
                    placeholder: L("%1POWR ? ou %2SNUM ?", "%1POWR ? or %2SNUM ?"),
                    monospaced: true,
                    onCommit: { rawCommandInput = $0 },
                    onSubmit: { cmd in
                        model.fleet.sendRawCommand(cmd, to: pj)
                    }
                )
                TextButton(title: L("Envoyer", "Send"), symbol: "paperplane.fill", prominent: true, compact: true) {
                    model.fleet.sendRawCommand(rawCommandInput, to: pj)
                }
            }
            let recent = model.fleet.exchanges.filter { $0.projectorIP == pj.endpointLabel }.suffix(4)
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(recent)) { ex in
                        HStack(spacing: 6) {
                            Text(ex.tx)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.accent.swiftUI)
                            Text("→")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textFaint.swiftUI)
                            Text(ex.rx)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(ex.isError ? Theme.danger.swiftUI : Theme.alive.swiftUI)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(Format.latency(ex.durationMs))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(Theme.textFaint.swiftUI)
                        }
                    }
                }
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.22)))
            }
        }
    }

    private func actionsFooterSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(L("Actions", "Actions"))
            HStack(spacing: 6) {
                TextButton(title: L("Actualiser", "Refresh"), symbol: "arrow.clockwise", compact: true) {
                    model.fleet.refresh([pj], includeIdentity: true)
                }
                TextButton(title: L("Interface Web", "Web UI"), symbol: "safari", compact: true) {
                    model.openWebInterface(pj)
                }
                if pj.mac != nil {
                    TextButton(title: "Wake-on-LAN", symbol: "bolt.horizontal.fill", compact: true) {
                        model.wakeProjectors([pj])
                    }
                }
            }
            HStack(spacing: 6) {
                TextButton(title: L("Copier IP", "Copy IP"), symbol: "doc.on.doc", compact: true) {
                    AppModel.copyToPasteboard(pj.endpointLabel)
                    model.flash(L("Adresse IP copiée", "IP address copied"))
                }
                TextButton(title: L("Copier OSC", "Copy OSC"), symbol: "waveform.path", compact: true) {
                    let slug = pj.displayTitle.lowercased().replacingOccurrences(of: " ", with: "-")
                    AppModel.copyToPasteboard("/simplepj/pj/\(slug)/shutter")
                    model.flash(L("Adresse OSC copiée", "OSC address copied"))
                }
                Spacer()
                TextButton(title: L("Retirer", "Remove"), symbol: "trash", destructive: true, compact: true) {
                    model.fleet.removeProjectors(ids: [pj.id])
                }
            }
        }
    }

    // MARK: - Multi-Selection Inspector

    private var multiSelectionDetails: some View {
        let selected = model.fleet.selectedProjectors
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(L("Sélection multiple", "Multiple Selection"))
            Text(L(Format.count(selected.count, "vidéoprojecteur") + " sélectionné\(selected.count > 1 ? "s" : "")", "\(selected.count) projector\(selected.count > 1 ? "s" : "") selected"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    TextButton(title: L("NOIR · Fermer volets", "BLACKOUT · Close Shutters"), symbol: "eye.slash.fill", prominent: true, tint: Theme.accent.swiftUI) {
                        model.fleet.setShutter(closed: true, on: selected)
                    }
                    TextButton(title: L("Ouvrir volets", "Open Shutters"), symbol: "sun.max.fill", prominent: true, tint: Theme.alive.swiftUI) {
                        model.fleet.setShutter(closed: false, on: selected)
                    }
                }
                HStack(spacing: 6) {
                    TextButton(title: L("Allumer la sélection", "Power On Selected"), symbol: "power", compact: true) {
                        model.requestPower(on: true, targets: selected)
                    }
                    TextButton(title: L("Veille…", "Standby…"), symbol: "moon.zzz.fill", compact: true) {
                        model.requestPower(on: false, targets: selected)
                    }
                }
            }

            separator

            SectionHeader(L("Projecteurs sélectionnés", "Selected Projectors"))
            ForEach(selected) { pj in
                HStack(spacing: 8) {
                    Circle().fill(Theme.statusColor(pj).swiftUI).frame(width: 6, height: 6)
                    Text(pj.displayTitle).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.text.swiftUI).lineLimit(1)
                    Spacer()
                    Text(pj.endpointLabel).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.textDim.swiftUI)
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private var emptySelectionPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "videoprojector")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textFaint.swiftUI)
            Text(L("Sélectionnez un vidéoprojecteur", "Select a Projector"))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textDim.swiftUI)
            Text(L("Inspectez son état PJLink Classe 1 & 2, ses entrées, ses heures de lampe/filtre, son diagnostic thermique et envoyez des commandes directes.", "Inspect its PJLink Class 1 & 2 status, inputs, lamp/filter hours, thermal diagnostics, and send direct commands."))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint.swiftUI)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim.swiftUI)
                .frame(width: 86, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text.swiftUI)
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}
