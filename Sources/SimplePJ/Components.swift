import SimplePJCore
import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    init(_ title: String) {
        self.title = title
        self.trailing = nil
    }

    init<V: View>(_ title: String, @ViewBuilder trailing: () -> V) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.textDim.swiftUI)
                .tracking(0.6)
                .textCase(.uppercase)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.bottom, 2)
    }
}

struct FieldRow<Content: View>: View {
    let label: String
    var width: CGFloat = 96
    let content: Content

    init(_ label: String, width: CGFloat = 96, @ViewBuilder content: () -> Content) {
        self.label = label
        self.width = width
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textDim.swiftUI)
                .frame(width: width, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}

struct CommitField: View {
    let value: String
    var placeholder: String = ""
    var monospaced: Bool = false
    var onCommit: (String) -> Void
    var onSubmit: ((String) -> Void)? = nil

    @State private var text: String
    @FocusState private var focused: Bool

    init(
        value: String,
        placeholder: String = "",
        monospaced: Bool = false,
        onCommit: @escaping (String) -> Void,
        onSubmit: ((String) -> Void)? = nil
    ) {
        self.value = value
        self.placeholder = placeholder
        self.monospaced = monospaced
        self.onCommit = onCommit
        self.onSubmit = onSubmit
        self._text = State(initialValue: value)
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11.5, design: monospaced ? .monospaced : .default))
            .foregroundStyle(Theme.text.swiftUI)
            .focused($focused)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(focused ? Theme.accent.swiftUI.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .animation(.easeOut(duration: 0.15), value: focused)
            .onAppear { text = value }
            .onChange(of: value) { _, newValue in if !focused { text = newValue } }
            .onSubmit { onCommit(text); onSubmit?(text) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused && text != value { onCommit(text) }
            }
    }
}

struct IconButton: View {
    let symbol: String
    var helpText: String = ""
    var active: Bool = false
    var tint: Color = Theme.accent.swiftUI
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(disabled ? Theme.textFaint.swiftUI : (active ? Theme.background.swiftUI : Theme.text.swiftUI))
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(active ? tint : Color.white.opacity(disabled ? 0.02 : (hovering ? 0.1 : 0.06)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct TextButton: View {
    let title: String
    var symbol: String? = nil
    var prominent: Bool = false
    var destructive: Bool = false
    var tint: Color? = nil
    var compact: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let activeColor = tint ?? (destructive ? Theme.danger.swiftUI : Theme.accent.swiftUI)
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 10.5 : 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: compact ? 11 : 11.5, weight: prominent || destructive ? .semibold : .medium))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(
                disabled ? Theme.textFaint.swiftUI
                    : (prominent || destructive ? Theme.background.swiftUI : (tint ?? Theme.text.swiftUI))
            )
            .padding(.horizontal, compact ? 8 : 11)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        prominent || destructive ? activeColor.opacity(disabled ? 0.35 : (hovering ? 0.9 : 1))
                            : (tint != nil ? activeColor.opacity(hovering ? 0.22 : 0.14) : Color.white.opacity(disabled ? 0.02 : (hovering ? 0.11 : 0.07)))
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct Chip: View {
    let text: String
    var tint: Color = Theme.textDim.swiftUI
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(filled ? Theme.background.swiftUI : tint)
            .padding(.horizontal, 5.5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(filled ? tint : tint.opacity(0.14))
            )
            .lineLimit(1)
    }
}

struct ActionChip: View {
    let text: String
    var tint: Color = Theme.textDim.swiftUI
    var active: Bool = false
    var help: String = ""
    var action: (() -> Void)? = nil

    @State private var hovering = false

    var body: some View {
        if let action {
            Button(action: action) {
                Chip(text: text, tint: tint, filled: active || hovering)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(help)
            .onHover { inside in
                hovering = inside
            }
            .animation(.easeOut(duration: 0.12), value: hovering)
        } else {
            Chip(text: text, tint: tint, filled: active).help(help)
        }
    }
}

struct ScanProgressBar: View {
    let fraction: Double
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(active ? 0.05 : 0))
                Rectangle()
                    .fill(Theme.accent.swiftUI)
                    .frame(width: max(0, width * (active ? fraction : 0)))
                    .animation(.linear(duration: 0.2), value: fraction)
            }
        }
        .frame(height: 2)
        .opacity(active ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: active)
    }
}

/// Visual lens & light beam badge for a single projector card or row.
struct ProjectorOpticBadge: View {
    let projector: Projector
    var size: CGFloat = 42

    var body: some View {
        let online = projector.connectionState == .online
        let isProjecting = online && projector.power == .on && !projector.isShutterClosed
        let isMuted = online && projector.power == .on && projector.isShutterClosed
        let isTransitioning = online && projector.power.isTransitioning
        let tint = Theme.statusColor(projector).swiftUI

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(tint.opacity(isProjecting ? 0.18 : 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24)
                        .strokeBorder(tint.opacity(isProjecting ? 0.55 : 0.25), lineWidth: 1)
                )

            Canvas { ctx, canvasSize in
                let cx = canvasSize.width * 0.36
                let cy = canvasSize.height * 0.50

                // Light beam cone to the right when projecting
                if isProjecting {
                    var beam = Path()
                    beam.move(to: CGPoint(x: cx + 4, y: cy - 3))
                    beam.addLine(to: CGPoint(x: canvasSize.width - 4, y: cy - canvasSize.height * 0.30))
                    beam.addLine(to: CGPoint(x: canvasSize.width - 4, y: cy + canvasSize.height * 0.30))
                    beam.addLine(to: CGPoint(x: cx + 4, y: cy + 3))
                    beam.closeSubpath()
                    ctx.fill(
                        beam,
                        with: .linearGradient(
                            Gradient(colors: [Theme.alive.swiftUI.opacity(0.55), Theme.alive.swiftUI.opacity(0.04)]),
                            startPoint: CGPoint(x: cx, y: cy),
                            endPoint: CGPoint(x: canvasSize.width, y: cy)
                        )
                    )
                } else if isMuted {
                    // Closed shutter bar right in front of the lens
                    let barRect = CGRect(x: cx + 9, y: cy - 9, width: 3.0, height: 18)
                    ctx.fill(Path(roundedRect: barRect, cornerRadius: 1.5), with: .color(Theme.accent.swiftUI))
                }

                // Projector chassis + lens
                let bodyRect = CGRect(x: 6, y: cy - 7, width: cx - 2, height: 14)
                ctx.fill(Path(roundedRect: bodyRect, cornerRadius: 3), with: .color(tint.opacity(0.85)))
                let lensRect = CGRect(x: cx + 1, y: cy - 5, width: 5, height: 10)
                ctx.fill(Path(roundedRect: lensRect, cornerRadius: 1.5), with: .color(tint))
            }

            if isTransitioning {
                Image(systemName: projector.power == .warming ? "flame.fill" : "wind")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.warning.swiftUI)
                    .offset(x: size * 0.24, y: -size * 0.24)
            } else if projector.connectionState == .authRequired {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.danger.swiftUI)
                    .offset(x: size * 0.24, y: -size * 0.24)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Hero illustration for the empty welcome state and About sheet: projector casting a wide stage beam.
struct ProjectorHeroGraphic: View {
    var active: Bool = false
    var size: CGFloat = 120

    var body: some View {
        Canvas { ctx, s in
            let w = s.width
            let h = s.height
            let cy = h * 0.52

            // Outer ring
            let ringRect = CGRect(x: 6, y: 6, width: w - 12, height: h - 12)
            ctx.stroke(Path(ellipseIn: ringRect), with: .color(Theme.accent.swiftUI.opacity(0.18)), lineWidth: 1.2)

            // Wide projection cone
            var cone = Path()
            cone.move(to: CGPoint(x: w * 0.38, y: cy - h * 0.06))
            cone.addLine(to: CGPoint(x: w * 0.88, y: cy - h * 0.30))
            cone.addLine(to: CGPoint(x: w * 0.88, y: cy + h * 0.30))
            cone.addLine(to: CGPoint(x: w * 0.38, y: cy + h * 0.06))
            cone.closeSubpath()

            ctx.fill(
                cone,
                with: .linearGradient(
                    Gradient(colors: [Theme.accent.swiftUI.opacity(0.55), Theme.accent.swiftUI.opacity(0.03)]),
                    startPoint: CGPoint(x: w * 0.38, y: cy),
                    endPoint: CGPoint(x: w * 0.88, y: cy)
                )
            )

            // Projection screen line on the right
            var screen = Path()
            screen.move(to: CGPoint(x: w * 0.88, y: cy - h * 0.28))
            screen.addLine(to: CGPoint(x: w * 0.88, y: cy + h * 0.28))
            ctx.stroke(screen, with: .color(Theme.alive.swiftUI.opacity(0.75)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Projector body
            let chassis = CGRect(x: w * 0.14, y: cy - h * 0.11, width: w * 0.22, height: h * 0.22)
            ctx.fill(Path(roundedRect: chassis, cornerRadius: 5), with: .color(Theme.text.swiftUI.opacity(0.9)))
            let lens = CGRect(x: w * 0.35, y: cy - h * 0.07, width: w * 0.05, height: h * 0.14)
            ctx.fill(Path(roundedRect: lens, cornerRadius: 2), with: .color(Theme.accent.swiftUI))
        }
        .frame(width: size, height: size)
    }
}
