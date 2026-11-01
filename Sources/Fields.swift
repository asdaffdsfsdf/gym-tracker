import SwiftUI
import UIKit

// Text entry on a phone behaves nothing like it does in a browser: every
// keystroke redraws the card it sits in, the decimal pad has no return key,
// and a field that reformats itself mid-word eats the character you just
// typed. Everything in this file exists to keep typing survivable.

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Taps on empty space put the keyboard away. It sits behind the content,
    /// so it never competes with the buttons and fields on top of it.
    func tapToDismissKeyboard() -> some View {
        background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { Keyboard.dismiss() }
        )
    }

    /// The system's own bar above the keyboard, so it rides up and down with
    /// the keyboard rather than animating on its own. Declared once per screen
    /// and never conditionally: SwiftUI tears a conditional keyboard toolbar
    /// down on the first dismissal and does not put it back.
    func keyboardDoneBar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { Keyboard.dismiss() }
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }
}

/// The sunken box every number sits in.
struct FieldBox: ViewModifier {
    var align: TextAlignment = .center
    var width: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(align)
            .monospacedDigit()
            .frame(width: width)
            .padding(.vertical, 9)
            .padding(.horizontal, width == nil ? 8 : 0)
            .background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A number field over a stored value. The text you are typing is kept exactly
/// as typed, so a half-finished "12." or a field you cleared to retype survives
/// the redraw that every keystroke causes. The stored value is written as soon
/// as it parses, and the text only snaps back to the stored shape once you
/// leave the field.
struct NumberInput: View {
    var placeholder: String = ""
    var value: Double?
    var format: (Double) -> String = { Fmt.trim($0) }
    var keyboard: UIKeyboardType = .decimalPad
    var align: TextAlignment = .center
    var width: CGFloat? = nil
    var commit: (Double?) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private func shown(_ v: Double?) -> String { v.map(format) ?? "" }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .focused($focused)
            .modifier(FieldBox(align: align, width: width))
            .onAppear { text = shown(value) }
            .onChange(of: text) { _, new in
                // only what the person typed is written back; the text also
                // changes when the stored value is loaded in, and echoing that
                // straight back out would save over their data on every redraw
                guard focused else { return }
                let s = new.replacingOccurrences(of: ",", with: ".")
                           .trimmingCharacters(in: .whitespaces)
                if s.isEmpty { commit(nil) }
                else if let v = Double(s) { commit(v) }
            }
            .onChange(of: value) { _, new in
                if !focused { text = shown(new) }
            }
            .onChange(of: focused) { _, now in
                if !now { text = shown(value) }
            }
    }
}

/// The same thing for a value the app stores as text rather than a number,
/// which is how a logged set is kept.
struct RawInput: View {
    var placeholder: String = ""
    var stored: String
    var keyboard: UIKeyboardType = .decimalPad
    var align: TextAlignment = .center
    var width: CGFloat? = nil
    var commit: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .focused($focused)
            .modifier(FieldBox(align: align, width: width))
            .onAppear { text = stored }
            .onChange(of: text) { _, new in
                guard focused, new != stored else { return }
                commit(new)
            }
            .onChange(of: stored) { _, new in
                if !focused && new != text { text = new }
            }
    }
}

/// A name field with autocorrect off, because the phone keyboard will happily
/// turn "RDL" into "Rdl" and "incline db press" into something else again.
/// Unstyled on purpose: callers wrap it in whatever box they already use.
struct NameInput: View {
    var placeholder: String
    var stored: String
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var caps: TextInputAutocapitalization = .sentences
    var commit: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: size, weight: weight))
            .autocorrectionDisabled()
            .textInputAutocapitalization(caps)
            .submitLabel(.done)
            .focused($focused)
            .onAppear { text = stored }
            .onChange(of: text) { _, new in
                guard focused, new != stored else { return }
                commit(new)
            }
            .onChange(of: stored) { _, new in
                if !focused && new != text { text = new }
            }
            .onSubmit { focused = false }
    }
}
