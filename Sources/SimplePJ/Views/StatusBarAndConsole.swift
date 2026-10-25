import SimplePJCore
import SwiftUI

struct ConsoleDrawer: View {
    @Bindable var model: AppModel

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.accent.swiftUI)
                Text("CONSOLE PROTOCOLE PJLINK (TCP :4352)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textDim.swiftUI)
                Text("\(model.fleet.exchanges.count) échanges")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textFaint.swiftUI)
                Spacer()
                Button("Effacer") {
                    model.fleet.exchanges.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textDim.swiftUI)

                Button {
                    model.showConsoleDrawer = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textDim.swiftUI)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Theme.header.swiftUI)

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.fleet.exchanges.isEmpty {
                        Text("Aucune trame PJLink enregistrée dans cette session.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textFaint.swiftUI)
                            .padding(10)
                    } else {
                        ForEach(model.fleet.exchanges.suffix(80).reversed()) { ex in
                            HStack(spacing: 10) {
                                Text(Self.timeFormatter.string(from: ex.timestamp))
                                    .foregroundStyle(Theme.textFaint.swiftUI)
                                    .frame(width: 78, alignment: .leading)
                                Text(ex.projectorTitle)
                                    .foregroundStyle(Theme.text.swiftUI)
                                    .frame(width: 130, alignment: .leading)
                                    .lineLimit(1)
                                Text(ex.projectorIP)
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .frame(width: 116, alignment: .leading)
                                Text("TX \(ex.tx)")
                                    .foregroundStyle(Theme.accent.swiftUI)
                                    .frame(width: 120, alignment: .leading)
                                Text("RX \(ex.rx)")
                                    .foregroundStyle(ex.isError ? Theme.danger.swiftUI : Theme.alive.swiftUI)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(Format.latency(ex.durationMs))
                                    .foregroundStyle(Theme.textFaint.swiftUI)
                            }
                            .font(.system(size: 10.5, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 132)
            .background(Theme.background.swiftUI)
        }
    }
}

struct StatusBar: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                if model.fleet.isScanning {
                    ProgressView().controlSize(.mini).scaleEffect(0.7).frame(width: 10, height: 10)
                }
                Text(model.flashMessage ?? model.fleet.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(model.fleet.lastError != nil ? Theme.danger.swiftUI : Theme.textDim.swiftUI)
                    .lineLimit(1)
            }

            if model.fleet.pollInterval != .off {
                Text("surveillance : \(model.fleet.pollInterval.shortLabel)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }

            Spacer()

            Text(summaryText)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.textFaint.swiftUI)

            Divider().frame(height: 12)

            HStack(spacing: 12) {
                Button { model.showOSCGuide = true } label: {
                    Text(verbatim: "OSC :\(model.fleet.oscServer?.port ?? kSimplePJDefaultOSCInPort)")
                        .foregroundStyle(Theme.osc.swiftUI)
                }
                .buttonStyle(.plain)
                .help("Guide des commandes OSC et API HTTP")

                Button { model.showHelp = true } label: { Text("? aide") }
                    .buttonStyle(.plain).help("Guide d'utilisation (⌘?)")
                Button { model.showShortcuts = true } label: { Text("⌘/ raccourcis") }
                    .buttonStyle(.plain).help("Raccourcis clavier (⌘/)")
                Button { model.showAbout = true } label: {
                    Text(AppVersion.current.shortLabel).foregroundStyle(Theme.textDim.swiftUI)
                }
                .buttonStyle(.plain).help("À propos de SimplePJ \(AppVersion.current.description)")
            }
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(Theme.textFaint.swiftUI)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Theme.panel.swiftUI)
        .overlay(alignment: .top) { Rectangle().fill(Theme.separator.swiftUI).frame(height: 1) }
    }

    private var summaryText: String {
        var parts: [String] = []
        let total = model.fleet.projectors.count
        let online = model.fleet.onlineCount
        if total > 0 {
            parts.append("\(online)/\(total) en ligne")
        }
        if model.fleet.isScanning {
            parts.append("\(model.fleet.scannedCount)/\(model.fleet.scanTotalCount) adresses")
        }
        if !model.fleet.selection.isEmpty {
            parts.append(Format.count(model.fleet.selection.count, "sélectionné"))
        }
        return parts.joined(separator: " · ")
    }
}
