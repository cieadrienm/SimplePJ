import SimplePJCore
import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fleetFiltersSection
                Divider().overlay(Theme.separator.swiftUI)
                stageGroupsSection
                Divider().overlay(Theme.separator.swiftUI)
                networksSection
                if !model.fleet.savedRanges.isEmpty {
                    Divider().overlay(Theme.separator.swiftUI)
                    favouritesSection
                }
                Divider().overlay(Theme.separator.swiftUI)
                automationSection
            }
            .padding(12)
        }
        .background(Theme.panel.swiftUI)
    }

    private var fleetFiltersSection: some View {
        let fleet = model.fleet
        return VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Parc & États")
            filterRow(
                filter: .all,
                symbol: "videoprojector",
                title: "Tous les projecteurs",
                count: fleet.projectors.count,
                tint: Theme.accent.swiftUI
            )
            filterRow(
                filter: .projecting,
                symbol: "sun.max.fill",
                title: "En projection",
                count: fleet.projectingCount,
                tint: Theme.alive.swiftUI
            )
            filterRow(
                filter: .shutterClosed,
                symbol: "eye.slash.fill",
                title: "Volet fermé (Noir)",
                count: fleet.shutterClosedCount,
                tint: Theme.accent.swiftUI
            )
            filterRow(
                filter: .standby,
                symbol: "moon.zzz.fill",
                title: "En veille / Chauffe",
                count: fleet.standbyCount,
                tint: Theme.standby.swiftUI
            )
            filterRow(
                filter: .alerts,
                symbol: "exclamationmark.triangle.fill",
                title: "Alertes & Mots de passe",
                count: fleet.alertCount,
                tint: Theme.danger.swiftUI
            )
        }
    }

    private var stageGroupsSection: some View {
        let tags = model.fleet.allTags
        return VStack(alignment: .leading, spacing: 5) {
            SectionHeader("Groupes de plateau") {
                if case .tag = model.fleet.sidebarFilter {
                    Button {
                        model.fleet.sidebarFilter = .all
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                    .buttonStyle(.plain)
                    .help("Afficher tous les groupes")
                }
            }
            if tags.isEmpty {
                Text("Ajoutez des #tags au nom d'un projecteur (ex. #face, #cyclo, #sol) pour créer des groupes de plateau.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint.swiftUI)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(tags, id: \.tag) { entry in
                    let groupProjectors = model.fleet.projectors.filter { $0.tags.contains(entry.tag) }
                    filterRow(
                        filter: .tag(entry.tag),
                        symbol: "number",
                        title: entry.tag,
                        count: entry.count,
                        tint: Theme.osc.swiftUI,
                        monospaced: true
                    )
                    .contextMenu {
                        Button("Fermer les volets de \(entry.tag) (Noir)") {
                            model.fleet.setShutter(closed: true, on: groupProjectors)
                        }
                        Button("Ouvrir les volets de \(entry.tag)") {
                            model.fleet.setShutter(closed: false, on: groupProjectors)
                        }
                        Divider()
                        Button("Allumer le groupe \(entry.tag)") {
                            model.requestPower(on: true, targets: groupProjectors)
                        }
                        Button("Mettre le groupe \(entry.tag) en veille…") {
                            model.requestPower(on: false, targets: groupProjectors)
                        }
                        Divider()
                        Button("Copier l'adresse OSC du groupe") {
                            let clean = entry.tag.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                            AppModel.copyToPasteboard("/simplepj/group/\(clean)/shutter")
                            model.flash("Adresse OSC copiée")
                        }
                    }
                }
            }
        }
    }

    private var networksSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader("Réseaux de ce Mac")
            let interfaces = NetworkInterface.scannableInterfaces()
            if interfaces.isEmpty {
                Text("Aucune interface active")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
            ForEach(interfaces, id: \.self) { iface in
                let active = model.fleet.rangeInput == iface.cidr
                Button {
                    model.useInterface(iface)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: iface.isVPN ? "lock.shield" : "wifi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(active ? Theme.accent.swiftUI : Theme.textDim.swiftUI)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(iface.cidr)
                                .font(.system(size: 11.5, weight: active ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(active ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                                .lineLimit(1)
                            Text("\(iface.name) · \(iface.ipv4)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.textFaint.swiftUI)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(active ? Theme.laneSelected.swiftUI : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var favouritesSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader("Plages favorites")
            ForEach(model.fleet.savedRanges) { saved in
                let active = model.fleet.rangeInput == saved.range
                Button {
                    model.fleet.rangeInput = saved.range
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.accent.swiftUI)
                            .frame(width: 14)
                        Text(saved.displayTitle)
                            .font(.system(size: 11.5, design: saved.name == nil ? .monospaced : .default))
                            .foregroundStyle(active ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(active ? Theme.laneSelected.swiftUI : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Renommer…") { model.renamingRange = saved }
                    Button("Découvrir maintenant") {
                        model.fleet.rangeInput = saved.range
                        model.fleet.startDiscovery()
                    }
                    Divider()
                    Button("Retirer des favoris", role: .destructive) {
                        model.fleet.removeSavedRange(saved.range)
                    }
                }
            }
        }
    }

    private var automationSection: some View {
        let oscPort = model.fleet.oscServer?.port ?? kSimplePJDefaultOSCInPort
        let oscActive = model.fleet.oscServer?.isRunning == true
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Régie & Simulation")
            Button {
                model.showOSCGuide = true
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(oscActive ? Theme.osc.swiftUI : Theme.textFaint.swiftUI)
                        .frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "OSC UDP :\(oscPort)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text.swiftUI)
                        Text(verbatim: "HTTP /v1 :\(model.fleet.httpPort)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Afficher les adresses OSC et HTTP pour OSCScore, Montage, eMotion ou QLab")

            Button {
                model.fleet.toggleSimulatedStageRig()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: model.fleet.isDemoRigActive ? "stop.circle.fill" : "play.tv")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(model.fleet.isDemoRigActive ? Theme.alive.swiftUI : Theme.accent.swiftUI)
                    Text(model.fleet.isDemoRigActive ? "Plateau simulé actif (4 VP)" : "Simuler un plateau (4 VP)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text.swiftUI)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(model.fleet.isDemoRigActive ? Theme.alive.swiftUI.opacity(0.14) : Color.white.opacity(0.05))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Démarre ou arrête 4 serveurs TCP PJLink Classe 2 réels sur 127.0.0.1 pour préparer une conduite hors plateau")

            if model.fleet.projectorManagerEntryCount > 0 {
                Button {
                    model.importFromProjectorManager()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.osc.swiftUI)
                        Text("Importer ProjectorManager (\(model.fleet.projectorManagerEntryCount))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text.swiftUI)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Importer la liste des vidéoprojecteurs enregistrés dans ProjectorManager (⇧⌘I)")
            }
        }
    }

    private func filterRow(
        filter: SidebarFilter,
        symbol: String,
        title: String,
        count: Int,
        tint: Color,
        monospaced: Bool = false
    ) -> some View {
        let active = model.fleet.sidebarFilter == filter
        return Button {
            model.fleet.sidebarFilter = filter
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? tint : Theme.textDim.swiftUI)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11.5, weight: active ? .semibold : .regular, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(active ? Theme.text.swiftUI : Theme.textDim.swiftUI)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? tint : Theme.textFaint.swiftUI)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(active ? tint.opacity(0.14) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
