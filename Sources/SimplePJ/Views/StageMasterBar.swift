import SimplePJCore
import SwiftUI

/// Dedicated stage control bar for triggering synchronized Shutter (Blackout / Open),
/// Power (On / Standby), Freeze, and Input changes on the active scope (selection, group, or all).
struct StageMasterBar: View {
    @Bindable var model: AppModel

    var body: some View {
        let targets = model.fleet.activeTargets
        let hasTargets = !targets.isEmpty
        let allClosed = hasTargets && targets.allSatisfy(\.isShutterClosed)
        let anyProjecting = targets.contains(where: \.isProjectingLight)
        let anyFrozen = targets.contains(where: \.freeze)

        HStack(spacing: 10) {
            // Target scope badge
            HStack(spacing: 6) {
                Image(systemName: model.fleet.selection.isEmpty ? "sparkles.tv" : "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent.swiftUI)
                Text("\(L("CIBLE", "TARGET")) : \(model.fleet.activeTargetsScopeLabel.uppercased())")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text.swiftUI)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))

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
                .help(L("Fermer le volet optique / AV Mute (31) sur la cible (⌘B)", "Close optical shutter / AV Mute (31) on target (⌘B)"))

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
                .help(L("Ouvrir le volet optique / AV Mute (30) sur la cible (⇧⌘B)", "Open optical shutter / AV Mute (30) on target (⇧⌘B)"))
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
                .help(L("Allumer la lampe / le laser (POWR 1) sur la cible", "Power on lamp / laser (POWR 1) on target"))

                TextButton(
                    title: L("Veille", "Standby"),
                    symbol: "moon.zzz.fill",
                    tint: Theme.standby.swiftUI,
                    compact: true,
                    disabled: !hasTargets
                ) {
                    model.requestPower(on: false, targets: targets)
                }
                .help(L("Mettre en veille (POWR 0) avec confirmation de sécurité (⌥-clic pour forcer sans confirmation)", "Standby (POWR 0) with safety confirmation (⌥-click to bypass confirmation)"))
            }

            Divider().frame(height: 16)

            // Freeze toggle (Class 2) & Synchronized Input Menu
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
            .help(L("Geler ou dégeler l'image (PJLink Classe 2 %2FREZ)", "Freeze or unfreeze image (PJLink Class 2 %2FREZ)"))

            Menu {
                ForEach(model.fleet.commonInputsForActiveTargets) { input in
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
            .help(L("Basculer l'entrée vidéo sur tous les projecteurs ciblés", "Switch video input on all targeted projectors"))

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
