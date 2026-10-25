import SimplePJCore
import SwiftUI

struct InspectorView: View {
    @Bindable var model: AppModel
    @FocusState private var labelFocused: Bool
    @State private var rawCommandInput: String = "%1POWR ?"

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
                    Chip(text: "CLASSE \(pj.pjlinkClass)", tint: pj.pjlinkClass >= 2 ? Theme.tcp.swiftUI : Theme.textDim.swiftUI)
                    if pj.isSimulated {
                        Chip(text: "SIMULÉ", tint: Theme.osc.swiftUI)
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
            SectionHeader("Plateau & Accès")
            FieldRow("Nom & #tags", width: 84) {
                CommitField(
                    value: pj.label ?? "",
                    placeholder: "Face Cour #face #cour",
                    onCommit: { text in
                        model.fleet.updateProjector(pj.id) { $0.label = text.isEmpty ? nil : text }
                    }
                )
                .focused($labelFocused)
            }
            FieldRow("Mot de passe", width: 84) {
                HStack(spacing: 5) {
                    CommitField(
                        value: pj.password,
                        placeholder: pj.requiresAuth ? "Requis (PJLINK 1)" : "Aucun (PJLINK 0)",
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
                            helpText: "Tester automatiquement les mots de passe PJLink d'usine (panasonic, admin, JBMIA, 0000…)",
                            tint: Theme.accent.swiftUI
                        ) {
                            model.fleet.autoUnlockPassword(for: pj)
                        }
                    }
                }
            }
            FieldRow("Notes régie", width: 84) {
                CommitField(
                    value: pj.notes ?? "",
                    placeholder: "Optique 0.8:1 · Pont face · Patch HDMI 1",
                    onCommit: { notes in
                        model.fleet.updateProjector(pj.id) { $0.notes = notes.isEmpty ? nil : notes }
                    }
                )
            }
        }
    }

    private func shutterAndPowerSection(_ pj: Projector, online: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Volet (Obturateur) & Alimentation") {
                Text(pj.shutter.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(pj.isShutterClosed ? Theme.accent.swiftUI : Theme.alive.swiftUI)
            }

            // Big Shutter Open / Close pair
            HStack(spacing: 6) {
                TextButton(
                    title: "NOIR · Fermer (31)",
                    symbol: "eye.slash.fill",
                    prominent: pj.isShutterClosed,
                    tint: Theme.accent.swiftUI,
                    disabled: !online
                ) {
                    model.fleet.setShutter(closed: true, on: [pj])
                }
                TextButton(
                    title: "Ouvrir volet (30)",
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
                    title: pj.shutter.isVideoMuted ? "Vidéo coupée" : "Vidéo seule",
                    symbol: "video.slash.fill",
                    compact: true,
                    disabled: !online
                ) {
                    model.fleet.setVideoMute(!pj.shutter.isVideoMuted, on: pj)
                }
                TextButton(
                    title: pj.shutter.isAudioMuted ? "Audio coupé" : "Audio seul",
                    symbol: "speaker.slash.fill",
                    compact: true,
                    disabled: !online
                ) {
                    model.fleet.setAudioMute(!pj.shutter.isAudioMuted, on: pj)
                }
                if pj.pjlinkClass >= 2 {
                    TextButton(
                        title: pj.freeze ? "Gel actif" : "Gel (Freeze)",
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
                    title: "Allumer (POWR 1)",
                    symbol: "power",
                    prominent: pj.power == .on,
                    tint: Theme.alive.swiftUI,
                    compact: true,
                    disabled: !online
                ) {
                    model.requestPower(on: true, targets: [pj])
                }
                TextButton(
                    title: "Mettre en veille (POWR 0)",
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

    private func inputsSection(_ pj: Projector, online: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Entrées Vidéo (INPT / INST)") {
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
                Text("Matrice native : \(native)" + (pj.inputResolution.map { " · Signal reçu : \($0)" } ?? ""))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
        }
    }

    private func healthAndLampsSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Santé & Source lumineuse (ERST / LAMP)") {
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
                infoRow("Source #\(lamp.index)", "\(Format.hours(lamp.hours)) · \(lamp.isOn ? "Allumée" : "Éteinte")")
            }
            if let filter = pj.filterHours {
                infoRow("Filtre (FILT)", Format.hours(filter))
            }
            if let rlmp = pj.replacementLamp {
                infoRow("Réf. source", rlmp)
            }
            if let rfil = pj.replacementFilter {
                infoRow("Réf. filtre", rfil)
            }
        }
    }

    private func hardwareInfoSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader("Identité PJLink")
            infoRow("Nom PJLink", pj.pjlinkName ?? "—")
            infoRow("Fabricant", pj.manufacturer ?? "—")
            infoRow("Modèle", pj.modelName ?? "—")
            if let info = pj.extraInfo, !info.isEmpty {
                infoRow("Infos (INFO)", info)
            }
            if let sn = pj.serialNumber {
                infoRow("N° de série", sn)
            }
            if let fw = pj.firmwareVersion {
                infoRow("Firmware", fw)
            }
            if let mac = pj.mac {
                infoRow("Adresse MAC", mac)
            }
            let slug = pj.displayTitle.lowercased().replacingOccurrences(of: " ", with: "-")
            infoRow("Adresse OSC", "/simplepj/pj/\(slug)/shutter")
        }
    }

    private func directCommandSection(_ pj: Projector) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader("Commande PJLink directe")
            HStack(spacing: 6) {
                CommitField(
                    value: rawCommandInput,
                    placeholder: "%1POWR ? ou %2SNUM ?",
                    monospaced: true,
                    onCommit: { rawCommandInput = $0 },
                    onSubmit: { cmd in
                        model.fleet.sendRawCommand(cmd, to: pj)
                    }
                )
                TextButton(title: "Envoyer", symbol: "paperplane.fill", prominent: true, compact: true) {
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
            SectionHeader("Actions")
            HStack(spacing: 6) {
                TextButton(title: "Actualiser", symbol: "arrow.clockwise", compact: true) {
                    model.fleet.refresh([pj], includeIdentity: true)
                }
                TextButton(title: "Interface Web", symbol: "safari", compact: true) {
                    model.openWebInterface(pj)
                }
                if pj.mac != nil {
                    TextButton(title: "Wake-on-LAN", symbol: "bolt.horizontal.fill", compact: true) {
                        model.wakeProjectors([pj])
                    }
                }
            }
            HStack(spacing: 6) {
                TextButton(title: "Copier IP", symbol: "doc.on.doc", compact: true) {
                    AppModel.copyToPasteboard(pj.endpointLabel)
                    model.flash("Adresse IP copiée")
                }
                TextButton(title: "Copier OSC", symbol: "waveform.path", compact: true) {
                    let slug = pj.displayTitle.lowercased().replacingOccurrences(of: " ", with: "-")
                    AppModel.copyToPasteboard("/simplepj/pj/\(slug)/shutter")
                    model.flash("Adresse OSC copiée")
                }
                Spacer()
                TextButton(title: "Retirer", symbol: "trash", destructive: true, compact: true) {
                    model.fleet.removeProjectors(ids: [pj.id])
                }
            }
        }
    }

    // MARK: - Multi-Selection Inspector

    private var multiSelectionDetails: some View {
        let selected = model.fleet.selectedProjectors
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Sélection multiple")
            Text(Format.count(selected.count, "vidéoprojecteur") + " sélectionné\(selected.count > 1 ? "s" : "")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text.swiftUI)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    TextButton(title: "NOIR · Fermer volets", symbol: "eye.slash.fill", prominent: true, tint: Theme.accent.swiftUI) {
                        model.fleet.setShutter(closed: true, on: selected)
                    }
                    TextButton(title: "Ouvrir volets", symbol: "sun.max.fill", prominent: true, tint: Theme.alive.swiftUI) {
                        model.fleet.setShutter(closed: false, on: selected)
                    }
                }
                HStack(spacing: 6) {
                    TextButton(title: "Allumer la sélection", symbol: "power", compact: true) {
                        model.requestPower(on: true, targets: selected)
                    }
                    TextButton(title: "Veille…", symbol: "moon.zzz.fill", compact: true) {
                        model.requestPower(on: false, targets: selected)
                    }
                }
            }

            separator

            SectionHeader("Projecteurs sélectionnés")
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
            Text("Sélectionnez un vidéoprojecteur")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textDim.swiftUI)
            Text("Inspectez son état PJLink Classe 1 & 2, ses entrées, ses heures de lampe/filtre, son diagnostic thermique et envoyez des commandes directes.")
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
