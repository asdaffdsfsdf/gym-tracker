import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: Store
    @Binding var tab: Int
    @State private var weightText = ""
    @State private var pick: String? = nil

    private var d: AppData { store.data }
    private var unit: String { d.profile.unit }
    private var todayKey: String { DateKey.today() }

    private var series: [Calc.WeighIn] { Calc.series(d.log) }
    private var trend: Calc.Trend? { Calc.trendNow(d.log) }
    private var rate: Double? { Calc.ratePerWeek(d.log) }

    private var start: Double? {
        if let s = d.profile.startWeight, s > 0 { return s }
        return series.first?.w
    }
    private var gained: Double? {
        guard let t = trend, let s = start else { return nil }
        return t.v - s
    }
    private var rateVerdict: String {
        guard let r = rate else { return "needs ~2 weeks" }
        if r < d.profile.rateLow { return "under your band" }
        if r > d.profile.rateHigh { return "over your band" }
        return "inside your band"
    }
    private var rateTint: Color {
        guard let r = rate else { return T.mut }
        if r < d.profile.rateLow { return T.bad }
        if r > d.profile.rateHigh { return T.warn }
        return T.good
    }

    private var exerciseNames: [String] {
        var counts: [String: Int] = [:]
        for s in d.sessions {
            for en in s.entries where !en.doneSets.isEmpty {
                counts[en.name, default: 0] += 1
            }
        }
        return counts.keys.sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if d.demo { demoBanner }
                backupBanner
                weightCard
                foodCard
                trainingCard
                intakeCard
                strengthCard
                weeklyCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(T.bg)
        .onAppear { weightText = store.day(todayKey).weight.map { Fmt.n2($0) } ?? "" }
    }

    // MARK: Banners

    private var demoBanner: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Demo data").font(.system(size: 14, weight: .semibold))
                    Text("Invented history so the charts have something to show. None of it is yours.")
                        .font(.system(size: 12.5)).foregroundStyle(T.mut)
                }
                Spacer(minLength: 8)
                Button("Clear") { store.clearDemo() }
                    .font(.system(size: 13, weight: .medium))
            }
        }
    }

    @ViewBuilder private var backupBanner: some View {
        let stale = d.lastBackup == nil || DateKey.diff(d.lastBackup!, todayKey) > 7
        let hasData = !d.log.isEmpty || !d.sessions.isEmpty
        if hasData && stale && !d.demo {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Back this up").font(.system(size: 14, weight: .semibold))
                        Text(d.lastBackup == nil
                             ? "Never copied. This phone is the only place it exists."
                             : "Last copy \(DateKey.diff(d.lastBackup!, todayKey)) days ago.")
                            .font(.system(size: 12.5)).foregroundStyle(T.mut)
                    }
                    Spacer(minLength: 8)
                    Button("Back up") { tab = 4 }
                        .font(.system(size: 13, weight: .medium))
                }
            }
        }
    }

    // MARK: Cards

    private var weightCard: some View {
        Card(title: "Weight",
             meta: series.isEmpty ? "no weigh-ins yet" : "7-day average\n\(series.count) weigh-ins") {
            Hero(value: trend.map { Fmt.n2($0.v) } ?? "--", unit: unit)
            Pill(text: rate.map { "\(Fmt.signed($0, 2)) \(unit) per week" } ?? "Rate needs ~2 weeks",
                 tint: rateTint)

            VStack(alignment: .leading, spacing: 6) {
                Text("LOG THIS MORNING")
                    .font(.system(size: 10, weight: .semibold)).kerning(0.6)
                    .foregroundStyle(T.mut)
                NumField(placeholder: "--.--", text: $weightText, onChange: { t in
                    store.setWeight(todayKey, t)
                }, align: .leading)
            }
            .padding(.top, 2)

            if series.count >= 2 {
                WeightChart(points: series, unit: unit)
                KPIRow {
                    KPI(label: "Since start",
                        value: gained.map { Fmt.signed($0, 2) } ?? "--",
                        unit: unit,
                        sub: start.map { "from \(Fmt.n2($0))" },
                        tint: (gained ?? 0) > 0 ? T.good : nil)
                    Divider().frame(height: 34)
                    KPI(label: "Target rate",
                        value: "\(Fmt.n2(d.profile.rateLow))-\(Fmt.n2(d.profile.rateHigh))",
                        unit: "\(unit)/wk", sub: rateVerdict, compact: true)
                        .padding(.leading, 12)
                    Divider().frame(height: 34)
                    KPI(label: "6mo at rate",
                        value: rate.map { Fmt.signed($0 * 26, 2) } ?? "--",
                        unit: unit, sub: "projected")
                        .padding(.leading, 12)
                }
            } else {
                Text("Two mornings of weight and the trend line starts.")
                    .font(.system(size: 13)).foregroundStyle(T.mut)
            }
        }
    }

    private var foodCard: some View {
        let t = Calc.dayTotals(store.day(todayKey), d.meals, d.foods)
        let logged = store.day(todayKey).logged
        return Card(title: "Today's food", meta: DateKey.pretty(todayKey)) {
            MacroBar(label: "Calories", have: t.kcal, target: d.profile.kcal)
            MacroBar(label: "Protein", have: t.p, target: d.profile.p, unit: "g")
            MacroBar(label: "Carbs", have: t.c, target: d.profile.c, unit: "g")
            MacroBar(label: "Fat", have: t.f, target: d.profile.f, unit: "g")

            if logged {
                Button { tab = 1 } label: {
                    Text("\(Fmt.r0(t.kcal)) kcal logged, edit")
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                Button { store.ateFullPlan(todayKey) } label: {
                    Text("Ate the full plan").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button { tab = 1 } label: {
                    Text("Cross off what I missed")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trainingCard: some View {
        let sess = store.session(on: todayKey)
        let day = store.trainingDay(on: todayKey)
        return Card(title: "Training",
                    meta: "\(DateKey.dayNames[DateKey.weekdayIndex(todayKey)]) · \(day?.name ?? "rest")") {
            if let sess {
                KPIRow {
                    KPI(label: "Volume", value: Fmt.r0(sess.volume), unit: unit)
                    Divider().frame(height: 34)
                    KPI(label: "Top set", value: Fmt.n1(sess.topSet), unit: unit, sub: "est. 1RM")
                        .padding(.leading, 12)
                }
                Button { tab = 2 } label: {
                    Text("\(sess.dayName) \(sess.locked ? "finished" : "in progress"), open")
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else if let day {
                ForEach(day.exercises) { ex in
                    let last = Calc.history(ex.name, d.sessions).last
                    RowLine(text: ex.name) {
                        Text(Calc.target(ex.sets, ex.lo, ex.hi, ex.mode)
                             + (last.map { " · last \(Fmt.metric($0.best, ex.mode, unit))" } ?? ""))
                            .font(.system(size: 12)).foregroundStyle(T.mut)
                    }
                }
                Button { store.startSession(day: day, on: todayKey); tab = 2 } label: {
                    Text("Start \(day.name)").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Text("Nothing scheduled. Rest day.")
                    .font(.system(size: 13)).foregroundStyle(T.mut)
                Button { tab = 2 } label: {
                    Text("Train anyway")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var intakeCard: some View {
        var bars: [IntakeChart.Bar] = []
        for i in stride(from: 13, through: 0, by: -1) {
            let key = DateKey.shift(todayKey, -i)
            let day = d.log[key]
            let v = (day?.logged == true) ? Calc.dayTotals(day, d.meals, d.foods).kcal : 0
            bars.append(IntakeChart.Bar(date: key, kcal: v))
        }
        let loggedCount = bars.filter { $0.kcal > 0 }.count
        let week = (0..<7).map { DateKey.shift(todayKey, -$0) }
            .filter { d.log[$0]?.logged == true }
        let avgK = week.isEmpty ? 0 : week.reduce(0.0) {
            $0 + Calc.dayTotals(d.log[$1], d.meals, d.foods).kcal } / Double(week.count)
        let avgP = week.isEmpty ? 0 : week.reduce(0.0) {
            $0 + Calc.dayTotals(d.log[$1], d.meals, d.foods).p } / Double(week.count)

        return Card(title: "Intake, 14 days", meta: "\(loggedCount)/14 logged") {
            if loggedCount == 0 {
                EmptyNote(text: "Log a few days and the bars appear against your target line.")
            } else {
                IntakeChart(bars: bars, target: d.profile.kcal)
                KPIRow {
                    KPI(label: "Avg kcal", value: Fmt.r0(avgK),
                        sub: "\(Fmt.signedInt(avgK - d.profile.kcal)) vs target")
                    Divider().frame(height: 34)
                    KPI(label: "Avg protein", value: Fmt.r0(avgP), unit: "g",
                        sub: "\(Fmt.signedInt(avgP - d.profile.p)) vs target")
                        .padding(.leading, 12)
                    Divider().frame(height: 34)
                    KPI(label: "Days logged", value: "\(week.count)/7", sub: "last week")
                        .padding(.leading, 12)
                }
                if avgK < d.profile.kcal - 150, let r = rate, r < d.profile.rateLow {
                    Text("Averaging under target and gaining under your band. The two agree, so the fix is food rather than patience.")
                        .font(.system(size: 12.5)).foregroundStyle(T.mut)
                }
            }
        }
    }

    private var strengthCard: some View {
        let names = exerciseNames
        let chosen = (pick.flatMap { names.contains($0) ? $0 : nil }) ?? names.first
        return Card(title: "Strength", meta: "best set") {
            if names.isEmpty {
                EmptyNote(text: "Finish a session and your progression charts start here.")
            } else if let chosen {
                Picker("Lift", selection: Binding(
                    get: { chosen },
                    set: { pick = $0 }
                )) {
                    ForEach(names, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(T.accent)

                let hist = Calc.history(chosen, d.sessions)
                if hist.count < 2 {
                    EmptyNote(text: "One session of \(chosen) so far. The line needs two.")
                } else {
                    let first = hist.first!, last = hist.last!
                    let weeks = Double(DateKey.diff(first.date, last.date)) / 7
                    let delta = last.best - first.best
                    let m = last.mode
                    Hero(value: m == .weight ? Fmt.n1(last.best) : Fmt.r0(last.best),
                         unit: m.unit(unit))
                    Pill(text: "\(m == .weight ? Fmt.signed(delta, 1) : Fmt.signedInt(delta)) \(m.unit(unit)) in \(Fmt.n1(weeks)) weeks",
                         tint: delta > 0 ? T.good : T.mut)
                    StrengthChart(points: hist, mode: m, unit: unit)
                }

                Divider().padding(.vertical, 2)
                strengthTable(names)
            }
        }
    }

    private func strengthTable(_ names: [String]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("LIFT").frame(maxWidth: .infinity, alignment: .leading)
                Text("BEST").frame(width: 76, alignment: .trailing)
                Text("VS LAST").frame(width: 62, alignment: .trailing)
                Text("VS 4WK").frame(width: 58, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold)).kerning(0.6)
            .foregroundStyle(T.mut)
            .padding(.bottom, 8)

            ForEach(names, id: \.self) { name in
                let h = Calc.history(name, d.sessions)
                if let last = h.last {
                    let prev: Double? = h.count > 1 ? last.best - h[h.count - 2].best : nil
                    let cut = DateKey.shift(last.date, -28)
                    let older = h.last { DateKey.diff($0.date, cut) >= 0 && $0.date != last.date }
                    let four: Double? = older.map { last.best - $0.best }
                    HStack {
                        Text(name).frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1).truncationMode(.tail)
                        Text(Fmt.metric(last.best, last.mode, unit))
                            .frame(width: 76, alignment: .trailing).monospacedDigit()
                        changeCell(prev, last.mode).frame(width: 62, alignment: .trailing)
                        changeCell(four, last.mode).frame(width: 58, alignment: .trailing)
                    }
                    .font(.system(size: 12.5))
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 0.5) }
                }
            }
        }
    }

    private func changeCell(_ v: Double?, _ mode: ExMode) -> some View {
        Group {
            if let v {
                Text(mode == .weight ? Fmt.signed(v, 1) : Fmt.signedInt(v))
                    .foregroundStyle(v > 0.5 ? T.good : (v < -0.5 ? T.bad : T.mut))
                    .fontWeight(abs(v) > 0.5 ? .semibold : .regular)
            } else {
                Text("--").foregroundStyle(T.mut)
            }
        }
        .monospacedDigit()
    }

    private var weeklyCard: some View {
        let rows = Calc.weekRows(d)
        return Card(title: "Week by week", meta: "\(rows.count) weeks · newest first") {
            if rows.isEmpty {
                EmptyNote(text: "Each week you log fills a row here.")
            } else {
                HStack {
                    Text("WEEK").frame(width: 48, alignment: .leading)
                    Text("WEIGHT").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("KCAL").frame(width: 46, alignment: .trailing)
                    Text("LOG").frame(width: 34, alignment: .trailing)
                    Text("SESS").frame(width: 34, alignment: .trailing)
                    Text("VOL").frame(width: 40, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).kerning(0.6)
                .foregroundStyle(T.mut)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                            let prev = idx + 1 < rows.count ? rows[idx + 1] : nil
                            let dw: Double? = {
                                guard let a = r.avgWeight, let b = prev?.avgWeight else { return nil }
                                return a - b
                            }()
                            HStack {
                                Text(DateKey.dm(r.week)).frame(width: 48, alignment: .leading)
                                HStack(spacing: 4) {
                                    Spacer(minLength: 0)
                                    Text(r.avgWeight.map { Fmt.n2($0) } ?? "--")
                                    if let dw {
                                        Text(Fmt.signed(dw, 2))
                                            .foregroundStyle(T.mut).font(.system(size: 11))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(r.avgKcal.map { Fmt.r0($0) } ?? "--")
                                    .frame(width: 46, alignment: .trailing)
                                Text("\(r.logged)/7").foregroundStyle(T.mut)
                                    .frame(width: 34, alignment: .trailing)
                                Text("\(r.sessions)").foregroundStyle(T.mut)
                                    .frame(width: 34, alignment: .trailing)
                                Text(r.volume > 0 ? "\(Fmt.r0(r.volume / 1000))k" : "--")
                                    .foregroundStyle(T.mut)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .padding(.vertical, 9)
                            .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 0.5) }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }
}
