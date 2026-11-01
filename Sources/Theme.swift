import SwiftUI
import UIKit

/// The palette and building blocks, matching the look we settled on:
/// dark grey cards, system font, blue accent, green reserved for progress.
enum T {
    /// Defined in code rather than an asset catalog so the build has no
    /// loose resources to go wrong, and so both appearances are explicit.
    private static func dyn(light: (CGFloat, CGFloat, CGFloat),
                            dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1)
        })
    }

    static let accent = dyn(light: (37, 99, 235),  dark: (59, 130, 246))
    static let good   = dyn(light: (21, 128, 61),  dark: (34, 197, 94))
    static let warn   = dyn(light: (161, 98, 7),   dark: (245, 158, 11))
    static let bad    = dyn(light: (185, 28, 28),  dark: (239, 68, 68))

    static var bg: Color { Color(.systemGroupedBackground) }
    static var card: Color { Color(.secondarySystemGroupedBackground) }
    static var sunken: Color { Color(.tertiarySystemFill) }
    static var line: Color { Color(.separator) }
    static var mut: Color { Color(.secondaryLabel) }
    static var ink: Color { Color(.label) }
    static var ink2: Color { Color(.secondaryLabel) }
}

struct Card<Content: View>: View {
    var title: String? = nil
    var meta: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || meta != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.7)
                            .foregroundStyle(T.mut)
                    }
                    Spacer()
                    if let meta {
                        Text(meta)
                            .font(.system(size: 12))
                            .foregroundStyle(T.mut)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// One of the small figures in a row across a card.
struct KPI: View {
    var label: String
    var value: String
    var unit: String? = nil
    var sub: String? = nil
    var tint: Color? = nil
    var compact: Bool = false
    var align: HorizontalAlignment = .leading
    /// False lets the column shrink to its text, so the dividers between
    /// columns can be centred in the gaps rather than pinned to a grid.
    var fill: Bool = true

    var body: some View {
        VStack(alignment: align, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(T.mut)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: compact ? 17 : 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(tint ?? T.ink)
                if let unit {
                    Text(unit).font(.system(size: 12)).foregroundStyle(T.mut)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if let sub {
                Text(sub).font(.system(size: 11)).foregroundStyle(T.mut)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: fill ? .infinity : nil,
               alignment: Alignment(horizontal: align, vertical: .top))
    }
}

struct KPIRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 0) { content }
    }
}

/// Target bar for one macro.
struct MacroBar: View {
    var label: String
    var have: Double
    var target: Double
    var unit: String = ""

    private var pct: Double { target > 0 ? min(1, have / target) : 0 }
    private var tint: Color {
        guard target > 0 else { return T.accent }
        if have < target * 0.9 { return T.bad }
        if have > target * 1.12 { return T.warn }
        return T.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(size: 14))
                Spacer()
                Text(Fmt.r0(have)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                Text("/ \(Fmt.r0(target))\(unit)")
                    .font(.system(size: 14)).foregroundStyle(T.mut).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(T.sunken)
                    Capsule().fill(tint).frame(width: max(0, geo.size.width * pct))
                }
            }
            .frame(height: 7)
        }
    }
}

struct Pill: View {
    var text: String
    var tint: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct Hero: View {
    var value: String
    var unit: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
            Text(unit).font(.system(size: 15)).foregroundStyle(T.mut)
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }
}

struct RowLine<Trailing: View>: View {
    var text: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(text).font(.system(size: 14))
            Spacer()
            trailing
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.line).frame(height: 0.5)
        }
    }
}

struct EmptyNote: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(T.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(T.sunken.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A plain number field over local text, for the scratch inputs that are not
/// stored anywhere until you tap the button next to them. Anything bound to
/// saved data uses NumberInput instead.
struct NumField: View {
    var placeholder: String
    @Binding var text: String
    var onChange: (String) -> Void = { _ in }
    var align: TextAlignment = .center

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .modifier(FieldBox(align: align))
            .onChange(of: text) { _, new in onChange(new) }
    }
}

extension View {
    func sectionGap() -> some View { self.padding(.bottom, 10) }
}
