import SimplePJCore
import SwiftUI

/// Dedicated stage control bar for triggering synchronized Shutter (Blackout / Open),
/// Power (On / Standby), Freeze, Test Patterns (Grids), and Input changes across ALL projectors in the fleet.
struct StageMasterBar: View {
    @Bindable var model: AppModel

    var body: some View {
        let targets = model.fleet.projectors
        let hasTargets = !targets.isEmpty
        let allClosed = hasTargets && targets.allSatisfy(\.isShutterClosed)
        let anyProjecting = targets.contains(where: \.isProjectingLight)
        let anyFrozen = targets.contains(where: \.freeze)
        let anyGrid = targets.contains { $0.activeTestPattern != .off }

        HStack(spacing: 10) {
            // Target scope badge — always all projectors in the fleet
            HStack(spacing: 6) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent.swiftUI)
                Text(L("TOUS LES VP (\(targets.count))", "ALL PROJECTORS (\(targets.count))"))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text.swiftUI)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
            .help(L("La barre maîtresse pilote toujours l'ensemble des vidéoprojecteurs du parc (\(targets.count) VP)", "The master bar always controls all projectors in the fleet (\(targets.count) PJ)"))

            Divider().frame(height: 16)

            // Master Shutter / Blackout controls (the most critical stage buttons)
            HStack(spacing: 6) {
                TextButton(
                    title: L("NOIR · Fermer volets", "BLACKOUT · Close Shutters"),
                    symbol: "eye.slash.fill",
                    prominent: allClosed,
                    tint: Theme.accent.swiftUI,
                    compact: true,
                    disabled: !hasTargets
                ) {
                    model.fleet.setShutter(closed: true, on: targets)
                }
                .help(L("Fermer le volet optique / AV Mute (31) sur tous les projecteurs", "Close optical shutter / AV Mute (31) on all projectors"))

                TextButton(
                    title: L("Ouvrir volets", "Open Shutters"),
                    symbol: "sun.max.fill",
                    prominent: anyProjecting && !allClosed,
                    tint: Theme.alive.swiftUI,
                    compact: true,
                    disabled: !hasTargets
                ) {
                    model.fleet.setShutter(closed: false, on: targets)
                }
                .help(L("Ouvrir le volet optique / AV Mute (30) sur tous les projecteurs", "Open optical shutter / AV Mute (30) on all projectors"))
            }

            Divider().frame(height: 16)

            // Master Power controls
            HStack(spacing: 6) {
                TextButton(
                    title: L("Allumer", "Power On"),
                    symbol: "power",
                    tint: Theme.alive.swiftUI,
                    compact: true,
                    disabled: !hasTargets
                ) {
                    model.requestPower(on: true, targets: targets)
                }
                .help(L("Allumer la lampe / le laser (POWR 1) sur tous les projecteurs", "Power on lamp / laser (POWR 1) on all projectors"))

                TextButton(
                    title: L("Veille", "Standby"),
                    symbol: "moon.zzz.fill",
                    tint: Theme.standby.swiftUI,
                    compact: true,
                    disabled: !hasTargets
                ) {
                    model.requestPower(on: false, targets: targets)
                }
                .help(L("Mettre tous les projecteurs en veille (POWR 0) avec confirmation de sécurité (⌥-clic pour forcer)", "Put all projectors into standby (POWR 0) with safety confirmation (⌥-click to bypass)"))
            }

            Divider().frame(height: 16)

            // Freeze toggle (Class 2), Global Test Pattern (Grid), & Global Input Menu
            TextButton(
                title: anyFrozen ? L("Dégeler", "Unfreeze") : L("Gel", "Freeze"),
                symbol: "snowflake",
                prominent: anyFrozen,
                tint: Theme.tcp.swiftUI,
                compact: true,
                disabled: !hasTargets
            ) {
                model.fleet.setFreeze(!anyFrozen, on: targets)
            }
            .help(L("Geler ou dégeler l'image sur tous les projecteurs (PJLink Classe 2 %2FREZ)", "Freeze or unfreeze image on all projectors (PJLink Class 2 %2FREZ)"))

            Menu {
                ForEach(OptomaTestPattern.allCases) { pat in
                    Button {
                        model.fleet.setTestPattern(pat, on: targets)
                    } label: {
                        Label(pat.label, systemImage: pat.symbol)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "squareshape.split.3x3")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(anyGrid ? Theme.background.swiftUI : Theme.accent.swiftUI)
                    Text(L("Grille…", "Grid…"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(anyGrid ? Theme.background.swiftUI : Theme.text.swiftUI)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(anyGrid ? Theme.background.swiftUI.opacity(0.8) : Theme.textDim.swiftUI)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(anyGrid ? Theme.accent.swiftUI : Color.white.opacity(0.06)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!hasTargets)
            .help(L("Afficher ou masquer les grilles de calage sur tous les projecteurs (Panasonic, Epson, Optoma)", "Show or hide alignment grids on all projectors (Panasonic, Epson, Optoma)"))

            Menu {
                ForEach(model.fleet.commonInputsForAllProjectors) { input in
                    Button {
                        model.fleet.setInput(input.code, on: targets)
                    } label: {
                        Label(input.fullLabel, systemImage: input.category.symbol)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    Text(L("Entrée…", "Input…"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text.swiftUI)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!hasTargets)
            .help(L("Basculer l'entrée vidéo sur tous les projecteurs du parc", "Switch video input on all projectors in the fleet"))

            Spacer(minLength: 8)

            // Live Stage Telemetry Pills
            HStack(spacing: 8) {
                stageStatPill(
                    count: model.fleet.projectingCount,
                    label: L("en projection", "projecting"),
                    tint: Theme.alive.swiftUI,
                    active: model.fleet.projectingCount > 0
                )
                stageStatPill(
                    count: model.fleet.shutterClosedCount,
                    label: L("volet fermé", "shutter closed"),
                    tint: Theme.accent.swiftUI,
                    active: model.fleet.shutterClosedCount > 0
                )
                stageStatPill(
                    count: model.fleet.standbyCount,
                    label: L("en veille", "standby"),
                    tint: Theme.standby.swiftUI,
                    active: model.fleet.standbyCount > 0
                )
                if model.fleet.alertCount > 0 {
                    stageStatPill(
                        count: model.fleet.alertCount,
                        label: model.fleet.alertCount > 1 ? L("alertes", "alerts") : L("alerte", "alert"),
                        tint: Theme.danger.swiftUI,
                        active: true
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Theme.header.swiftUI)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator.swiftUI).frame(height: 1) }
    }

    private func stageStatPill(count: Int, label: String, tint: Color, active: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? tint : Theme.textFaint.swiftUI.opacity(0.5))
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? tint : Theme.textFaint.swiftUI)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(active ? Theme.textDim.swiftUI : Theme.textFaint.swiftUI)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(RoundedRectangle(cornerRadius: 4).fill(active ? tint.opacity(0.10) : Color.white.opacity(0.02)))
    }
}
