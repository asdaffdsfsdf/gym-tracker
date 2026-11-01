import SwiftUI

struct TrainView: View {
    @EnvironmentObject var store: Store
    @State private var cursor = DateKey.today()
    @State private var showPick = false
    @State private var customName = ""
    @State private var showAddExo = false
    @State private var newExo = ""
    @State private var newExoMode: ExMode = .weight
    @State private var confirmRemove: UUID? = nil
    @State private var notice: String? = nil

    private var d: AppData { store.data }
    private var unit: String { d.profile.unit }
    private var isToday: Bool { cursor == DateKey.today() }
    private var session: Session? { store.session(on: cursor) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                dayHeader
                if let s = session {
                    sessionSummary(s)
                    ForEach(Array(s.entries.enumerated()), id: \.element.id) { idx, en in
                        exerciseCard(session: s, index: idx, entry: en)
                    }
                    footerCard(s)
                } else {
                    plannedCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .tapToDismissKeyboard()
        }
        .background(T.bg)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .overlay(alignment: .bottom) {
            if let notice {
                Text(notice)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(T.ink, in: Capsule())
                    .foregroundStyle(T.bg)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
    }

    private func flash(_ s: String) {
        withAnimation { notice = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation { if notice == s { notice = nil } }
        }
    }

    private var dayHeader: some View {
        let day = store.trainingDay(on: cursor)
        return Card {
            HStack {
                Button { cursor = DateKey.shift(cursor, -1); reset() } label: {
                    Image(systemName: "chevron.left").padding(8)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(DateKey.pretty(cursor)).font(.system(size: 16, weight: .semibold))
                    Text("\(DateKey.dayNames[DateKey.weekdayIndex(cursor)]) · \(day?.name ?? "rest")")
                        .font(.system(size: 12)).foregroundStyle(T.mut)
                }
                Spacer()
                Button { cursor = DateKey.shift(cursor, 1); reset() } label: {
                    Image(systemName: "chevron.right").padding(8)
                }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
            }
        }
    }

    private func reset() {
        showPick = false; showAddExo = false; confirmRemove = nil
        Keyboard.dismiss()
    }

    // MARK: Before a session exists

    private var plannedCard: some View {
        let day = store.trainingDay(on: cursor)
        return Card(title: day?.name ?? "Rest day",
                    meta: day.map { "\($0.exercises.count) exercises" }) {
            if let day {
                ForEach(day.exercises) { ex in
                    let last = store.history(ex.name).last
                    RowLine(text: ex.name) {
                        Text(Calc.target(ex.sets, ex.lo, ex.hi, ex.mode)
                             + (last.map { " · last \(Fmt.metric($0.best, ex.mode, unit))" } ?? ""))
                            .font(.system(size: 12)).foregroundStyle(T.mut)
                    }
                }
                Button {
                    store.startSession(day: day, on: cursor)
                } label: {
                    Text("Start \(day.name)").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button { showPick.toggle() } label: {
                    Text("Train something else")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                EmptyNote(text: "Nothing scheduled for \(DateKey.dayNames[DateKey.weekdayIndex(cursor)]).")
                Button { showPick.toggle() } label: {
                    Text("Train anyway")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if showPick {
                Divider().padding(.vertical, 2)
                Text("PICK A WORKOUT")
                    .font(.system(size: 10, weight: .semibold)).kerning(0.6).foregroundStyle(T.mut)
                ForEach(d.program.days) { pd in
                    Button { store.startSession(day: pd, on: cursor); showPick = false } label: {
                        Text(pd.name)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHAT DID YOU TRAIN TODAY")
                        .font(.system(size: 10, weight: .semibold)).kerning(0.6).foregroundStyle(T.mut)
                    TextField("e.g. Basketball, climbing, random pump", text: $customName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(10).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    store.startBlankSession(name: customName, on: cursor)
                    customName = ""; showPick = false; showAddExo = true
                } label: {
                    Text("Start a blank session")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: During and after

    private func sessionSummary(_ s: Session) -> some View {
        Card(title: s.dayName, meta: s.locked ? "finished" : nil) {
            KPIRow {
                KPI(label: "Volume", value: Fmt.r0(s.volume), unit: unit)
                Divider().frame(height: 34)
                KPI(label: "Top set", value: Fmt.n1(s.topSet), unit: unit, sub: "est. 1RM")
                    .padding(.leading, 12)
            }
        }
    }

    private func exerciseCard(session s: Session, index idx: Int, entry en: SessionEntry) -> some View {
        let hist = store.history(en.name)
        let last = hist.last { DateKey.diff($0.date, s.date) > 0 }
        let cue = store.cue(for: en.name)
        let tip: (text: String, weight: Double?)? = {
            guard !s.locked, let t = en.target else { return nil }
            return Calc.suggestion(ProgramExercise(name: en.name, mode: en.mode,
                                                   sets: t.sets, lo: t.lo, hi: t.hi),
                                   before: s.date, history: hist, unit: unit)
        }()

        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text(en.name).font(.system(size: 15, weight: .semibold))
                Spacer()
                if let t = en.target {
                    Text(Calc.target(t.sets, t.lo, t.hi, en.mode))
                        .font(.system(size: 12)).foregroundStyle(T.mut)
                }
            }

            Text(last.map { "Last \(DateKey.agoShort($0.date)) · \(Calc.setsLabel($0.sets, $0.mode))" }
                 ?? "First time logging this")
                .font(.system(size: 12.5)).foregroundStyle(T.mut)

            if !cue.isEmpty {
                Text(cue).font(.system(size: 12)).foregroundStyle(T.mut)
            }
            if let tip {
                Text(tip.text)
                    .font(.system(size: 12.5))
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(T.good.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            }

            if s.locked {
                let done = en.doneSets
                Text(done.isEmpty ? "nothing logged" : Calc.setsLabel(done, en.mode))
                    .font(.system(size: 14, weight: done.isEmpty ? .regular : .semibold))
                    .foregroundStyle(done.isEmpty ? T.mut : T.ink)
                if !en.note.isEmpty {
                    Text(en.note).font(.system(size: 12.5)).foregroundStyle(T.ink2)
                }
            } else {
                ForEach(Array(en.sets.enumerated()), id: \.element.id) { si, _ in
                    setRow(sessionIndex: idx, setIndex: si, mode: en.mode,
                           canRemove: en.sets.count > 1)
                }
                NameInput(placeholder: "Notes for today",
                          stored: store.data.sessions.first { $0.id == s.id }?.entries[safe: idx]?.note ?? "",
                          size: 13) { nv in
                    if let i = store.sessionIndex(on: cursor),
                       store.data.sessions[i].entries.indices.contains(idx) {
                        store.data.sessions[i].entries[idx].note = nv
                        store.save()
                    }
                }
                .padding(9)
                .background(T.sunken, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Add set") { store.addSetRow(on: cursor, entry: idx) }
                        .font(.system(size: 12.5))
                    Spacer()
                    Button(confirmRemove == en.id ? "Tap to remove" : "Remove exercise") {
                        if confirmRemove == en.id {
                            store.removeEntry(on: cursor, entry: idx)
                            confirmRemove = nil
                        } else {
                            confirmRemove = en.id
                        }
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(confirmRemove == en.id ? T.bad : T.mut)
                }
            }
        }
    }

    private func setRow(sessionIndex idx: Int, setIndex si: Int,
                        mode: ExMode, canRemove: Bool) -> some View {
        HStack(spacing: 9) {
            Text("\(si + 1)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(T.mut)
                .frame(width: 18)
            switch mode {
            case .weight:
                setField(idx, si, \.w, placeholder: unit)
                setField(idx, si, \.r, placeholder: "reps")
            case .reps:
                setField(idx, si, \.r, placeholder: "reps")
            case .time:
                setField(idx, si, \.t, placeholder: "seconds")
            }
            Button {
                Keyboard.dismiss()
                store.removeSetRow(on: cursor, entry: idx, set: si)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(canRemove ? T.mut : T.line)
                    .frame(width: 26, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
        }
    }

    /// Writes straight back into the stored set so nothing is lost on redraw,
    /// while the field itself holds the characters being typed.
    private func setField(_ entry: Int, _ set: Int,
                          _ key: WritableKeyPath<SetEntry, Flex>,
                          placeholder: String) -> some View {
        RawInput(placeholder: placeholder, stored: stored(entry, set, key)) { nv in
            guard let i = store.sessionIndex(on: cursor),
                  store.data.sessions[i].entries.indices.contains(entry),
                  store.data.sessions[i].entries[entry].sets.indices.contains(set)
            else { return }
            store.data.sessions[i].entries[entry].sets[set][keyPath: key] = Flex(nv)
            store.save()
        }
    }

    private func stored(_ entry: Int, _ set: Int, _ key: WritableKeyPath<SetEntry, Flex>) -> String {
        guard let i = store.sessionIndex(on: cursor),
              store.data.sessions[i].entries.indices.contains(entry),
              store.data.sessions[i].entries[entry].sets.indices.contains(set)
        else { return "" }
        return store.data.sessions[i].entries[entry].sets[set][keyPath: key].text
    }

    private func footerCard(_ s: Session) -> some View {
        Card {
            if s.locked {
                Button { store.unlockSession(on: cursor) } label: {
                    Text("Edit session")
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Button("Add exercise") { showAddExo.toggle() }
                        .font(.system(size: 14))
                    Spacer()
                    Button {
                        Keyboard.dismiss()
                        let kept = store.finishSession(on: cursor)
                        showAddExo = false
                        flash(kept ? "Session saved. Unfinished sets were dropped."
                                   : "Nothing was logged, so that session was discarded.")
                    } label: {
                        Text("Finish session").fontWeight(.semibold)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(T.accent, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                if showAddExo {
                    Divider().padding(.vertical, 2)
                    TextField("Exercise name", text: $newExo)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(10).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                    Picker("Type", selection: $newExoMode) {
                        ForEach(ExMode.allCases) { m in Text(m.shortLabel).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    Button {
                        store.addEntry(on: cursor, name: newExo, mode: newExoMode)
                        newExo = ""; showAddExo = false
                    } label: {
                        Text("Add to this session")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
