import Foundation

// MARK: - Formatting

enum Fmt {
    static func n(_ v: Double, _ places: Int) -> String {
        String(format: "%.\(places)f", v)
    }
    static func n1(_ v: Double) -> String { n(v, 1) }
    static func n2(_ v: Double) -> String { n(v, 2) }
    static func r0(_ v: Double) -> String { String(Int(v.rounded())) }

    /// One decimal, with a trailing ".0" dropped, for plate weights.
    static func trim(_ v: Double) -> String {
        let s = n1(v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    static func signed(_ v: Double, _ places: Int) -> String {
        (v >= 0 ? "+" : "") + n(v, places)
    }
    static func signedInt(_ v: Double) -> String {
        (v >= 0 ? "+" : "") + r0(v)
    }

    /// A best-set figure with the right unit for its exercise kind.
    static func metric(_ v: Double, _ mode: ExMode, _ unit: String) -> String {
        switch mode {
        case .weight: return n1(v)
        case .time:   return r0(v) + "s"
        case .reps:   return r0(v)
        }
    }
}

// MARK: - Dates, as "yyyy-MM-dd" keys

/// All of this is plain integer arithmetic on purpose. Calendar is far too
/// slow to sit inside a sort comparator that runs thousands of times for every
/// character typed, and it was the single biggest cause of the lag.
enum DateKey {
    // MARK: civil date arithmetic

    static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = y0 - (m <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ z0: Int) -> (y: Int, m: Int, d: Int) {
        var z = z0
        z += 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    /// Days since 1970-01-01.
    static func dayNumber(_ key: String) -> Int {
        let p = key.split(separator: "-")
        guard p.count == 3, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else { return 0 }
        return daysFromCivil(y, m, d)
    }

    static func key(day n: Int) -> String {
        let c = civilFromDays(n)
        return String(format: "%04d-%02d-%02d", c.y, c.m, c.d)
    }

    // MARK: today, in the phone's own time zone

    static func today() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// Charts need real Dates. Noon UTC, so a key survives the round trip
    /// whatever the phone's time zone is doing.
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-")
        guard p.count == 3 else { return nil }
        return Date(timeIntervalSince1970: Double(dayNumber(key)) * 86_400 + 43_200)
    }

    static func string(_ d: Date) -> String {
        key(day: Int(floor(d.timeIntervalSince1970 / 86_400)))
    }

    static func shift(_ key: String, _ days: Int) -> String {
        self.key(day: dayNumber(key) + days)
    }

    /// Whole days between two keys, b minus a.
    static func diff(_ a: String, _ b: String) -> Int {
        dayNumber(b) - dayNumber(a)
    }

    /// 0 = Monday, matching the program schedule's order. 1 January 1970 was a
    /// Thursday, which is index 3.
    static func weekdayIndex(_ key: String) -> Int {
        ((dayNumber(key) + 3) % 7 + 7) % 7
    }

    static func weekStart(_ key: String) -> String {
        shift(key, -weekdayIndex(key))
    }

    /// "29/10", day first.
    static func dm(_ key: String) -> String {
        let p = key.split(separator: "-")
        guard p.count == 3 else { return key }
        return "\(p[2])/\(p[1])"
    }

    static let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    /// "29 Oct".
    static func dmy(_ key: String) -> String {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, p[1] >= 1, p[1] <= 12 else { return key }
        return "\(p[2]) \(months[p[1] - 1])"
    }

    private static let prettyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func pretty(_ key: String) -> String {
        let t = today()
        if key == t { return "Today" }
        if key == shift(t, -1) { return "Yesterday" }
        if key == shift(t, 1) { return "Tomorrow" }
        guard let d = date(key) else { return key }
        return prettyFormatter.string(from: d)
    }

    static func agoShort(_ key: String) -> String {
        let n = diff(key, today())
        return n <= 0 ? "today" : "\(n)d"
    }

    static let dayNames = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
}

// MARK: - The numbers

enum Calc {
    /// "3 x 8-12", or "3 x 60s" once the range collapses to one target.
    static func target(_ sets: Int, _ lo: Int, _ hi: Int, _ mode: ExMode) -> String {
        let s = mode == .time ? "s" : ""
        return lo == hi ? "\(sets) x \(hi)\(s)" : "\(sets) x \(lo)-\(hi)\(s)"
    }

    static func epley(_ w: Double, _ r: Double) -> Double { w * (1 + r / 30) }

    struct WeighIn { var date: String; var w: Double }
    struct Trend { var date: String; var v: Double; var n: Int }

    /// Every weigh-in, oldest first.
    static func series(_ log: [String: DayLog]) -> [WeighIn] {
        log.compactMap { (k, v) in v.weight.map { WeighIn(date: k, w: $0) } }
           .sorted { DateKey.dayNumber($0.date) < DateKey.dayNumber($1.date) }
    }

    /// Trailing average over `window` days, one point per weigh-in.
    static func rolling(_ e: [WeighIn], _ window: Int) -> [Trend] {
        var out: [Trend] = []
        out.reserveCapacity(e.count)
        for (i, p) in e.enumerated() {
            var sum = 0.0, n = 0
            var j = i
            while j >= 0 {
                let gap = DateKey.diff(e[j].date, p.date)
                if gap < window { sum += e[j].w; n += 1; j -= 1 } else { break }
            }
            out.append(Trend(date: p.date, v: n > 0 ? sum / Double(n) : p.w, n: n))
        }
        return out
    }

    static func trendNow(_ log: [String: DayLog]) -> Trend? {
        let e = series(log)
        guard !e.isEmpty else { return nil }
        return rolling(e, 7).last
    }

    /// Change per week, the latest average against the one a week earlier.
    /// Nil until there is genuinely enough to compare.
    static func ratePerWeek(_ log: [String: DayLog]) -> Double? {
        rate(from: series(log))
    }

    static func rate(from e: [WeighIn]) -> Double? {
        guard e.count >= 4 else { return nil }
        let r = rolling(e, 7)
        guard let last = r.last, last.n >= 2 else { return nil }
        var best: Trend? = nil
        var bestGap = Int.max
        for p in r where p.n >= 2 {
            let gap = abs(DateKey.diff(p.date, last.date) - 7)
            if gap < bestGap { bestGap = gap; best = p }
        }
        guard let b = best, bestGap <= 3 else { return nil }
        let weeks = Double(DateKey.diff(b.date, last.date)) / 7.0
        guard weeks > 0.3 else { return nil }
        return (last.v - b.v) / weeks
    }

    struct Macros { var kcal = 0.0; var p = 0.0; var c = 0.0; var f = 0.0
        static func + (a: Macros, b: Macros) -> Macros {
            Macros(kcal: a.kcal + b.kcal, p: a.p + b.p, c: a.c + b.c, f: a.f + b.f)
        }
    }

    /// The amount of an item actually eaten on a day: the plan's quantity
    /// unless that day carries its own.
    static func qty(_ item: MealItem, _ day: DayLog?) -> Double {
        day?.qty[item.id] ?? item.qty
    }

    static func itemMacros(_ item: MealItem, _ foods: [Food], qty: Double? = nil) -> Macros {
        guard let f = foods.first(where: { $0.id == item.foodId }) else { return Macros() }
        let amount = qty ?? item.qty
        let k = f.perUnit ? amount : amount / 100.0
        return Macros(kcal: f.kcal * k, p: f.p * k, c: f.c * k, f: f.f * k)
    }

    static func planTotals(_ meals: [Meal], _ foods: [Food]) -> Macros {
        meals.flatMap { $0.items }.reduce(Macros()) { $0 + itemMacros($1, foods) }
    }

    static func dayTotals(_ day: DayLog?, _ meals: [Meal], _ foods: [Food]) -> Macros {
        let missed = Set(day?.missed ?? [])
        var t = meals.flatMap { $0.items }
            .filter { !missed.contains($0.id) }
            .reduce(Macros()) { $0 + itemMacros($1, foods, qty: qty($1, day)) }
        for x in day?.extras ?? [] {
            t = t + Macros(kcal: x.kcal, p: x.p, c: x.c, f: x.f)
        }
        return t
    }

    struct TDEE { var bmr: Int; var tdee: Int; var kcal: Int; var p: Int; var c: Int; var f: Int }

    /// Mifflin-St Jeor, then a surplus, then protein and fat per kg with carbs as the remainder.
    static func macros(bw: Double, height: Double, age: Int, sex: String,
                       activity: Double, surplusPct: Double) -> TDEE {
        let bmr = 10 * bw + 6.25 * height - 5 * Double(age) + (sex == "m" ? 5 : -161)
        let tdee = bmr * activity
        let kcal = (tdee * (1 + surplusPct / 100) / 10).rounded() * 10
        let p = (bw * 1.8).rounded()
        let f = (bw * 0.9).rounded()
        let c = ((kcal - p * 4 - f * 9) / 4).rounded()
        return TDEE(bmr: Int(bmr.rounded()), tdee: Int(tdee.rounded()),
                    kcal: Int(kcal), p: Int(p), c: Int(c), f: Int(max(0, f)))
    }

    /// One row per session that contained this exercise, oldest first.
    struct ExPoint { var date: String; var best: Double; var bestSet: SetEntry
                     var sets: [SetEntry]; var mode: ExMode }

    static func history(_ name: String, _ sessions: [Session]) -> [ExPoint] {
        var out: [ExPoint] = []
        for s in sessions {
            for en in s.entries where en.name == name {
                let done = en.doneSets
                guard !done.isEmpty else { continue }
                var best = 0.0
                var bestSet = done[0]
                for st in done {
                    let v = st.metric(en.mode)
                    if v > best { best = v; bestSet = st }
                }
                out.append(ExPoint(date: s.date, best: best, bestSet: bestSet,
                                   sets: done, mode: en.mode))
            }
        }
        return out.sorted { DateKey.dayNumber($0.date) < DateKey.dayNumber($1.date) }
    }

    static func setsLabel(_ sets: [SetEntry], _ mode: ExMode) -> String {
        guard !sets.isEmpty else { return "" }
        switch mode {
        case .time:
            return sets.map { Fmt.r0($0.t.value) + "s" }.joined(separator: ", ")
        case .reps:
            return sets.map { Fmt.r0($0.r.value) }.joined(separator: ", ")
        case .weight:
            var groups: [(w: Double, reps: [Int])] = []
            for s in sets {
                if var last = groups.last, last.w == s.w.value {
                    last.reps.append(Int(s.r.value.rounded()))
                    groups[groups.count - 1] = last
                } else {
                    groups.append((w: s.w.value, reps: [Int(s.r.value.rounded())]))
                }
            }
            return groups.map { g in
                Fmt.trim(g.w) + " x " + g.reps.map(String.init).joined(separator: ", ")
            }.joined(separator: "  |  ")
        }
    }

    /// Nudge for the next session, only when the last one earned it.
    static func suggestion(_ ex: ProgramExercise, before: String?, history h: [ExPoint],
                           unit: String) -> (text: String, weight: Double?)? {
        let prior = h.last { before == nil || DateKey.diff($0.date, before!) > 0 }
        guard let last = prior else { return nil }
        switch ex.mode {
        case .time:
            let all = last.sets.count >= ex.sets && last.sets.allSatisfy { $0.t.value >= Double(ex.hi) }
            return all ? ("You held \(ex.hi)s on every set. Add 10s today.", nil) : nil
        case .reps:
            let all = last.sets.count >= ex.sets && last.sets.allSatisfy { $0.r.value >= Double(ex.hi) }
            return all ? ("You hit \(ex.hi) on every set. Push past it today.", nil) : nil
        case .weight:
            let all = last.sets.count >= ex.sets && last.sets.allSatisfy { $0.r.value >= Double(ex.hi) }
            if all {
                let w = last.sets.map { $0.w.value }.max() ?? 0
                let step = w < 100 ? 2.5 : 5.0
                return ("You hit \(ex.hi) on every set. Go \(Fmt.trim(w + step)) \(unit) today.", w + step)
            }
            if last.sets.contains(where: { $0.r.value < Double(ex.lo) }) {
                return ("Last time you dropped under \(ex.lo) reps. Hold the weight and add reps.", nil)
            }
            return nil
        }
    }

    struct WeekRow: Identifiable {
        var id: String { week }
        var week: String
        var avgWeight: Double?
        var avgKcal: Double?
        var logged: Int
        var sessions: Int
        var volume: Double
    }

    /// Newest week first.
    static func weekRows(_ data: AppData) -> [WeekRow] {
        var days: [String: [String]] = [:]
        var sess: [String: [Session]] = [:]
        for k in data.log.keys { days[DateKey.weekStart(k), default: []].append(k) }
        for s in data.sessions { sess[DateKey.weekStart(s.date), default: []].append(s) }
        let keys = Set(days.keys).union(sess.keys)
            .sorted { DateKey.dayNumber($0) > DateKey.dayNumber($1) }
        return keys.map { wk in
            let ds = days[wk] ?? []
            let weights = ds.compactMap { data.log[$0]?.weight }
            let loggedDays = ds.filter { data.log[$0]?.logged == true }
            let ss = sess[wk] ?? []
            return WeekRow(
                week: wk,
                avgWeight: weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count),
                avgKcal: loggedDays.isEmpty ? nil :
                    loggedDays.reduce(0.0) { $0 + dayTotals(data.log[$1], data.meals, data.foods).kcal }
                    / Double(loggedDays.count),
                logged: loggedDays.count,
                sessions: Set(ss.map { $0.date }).count,
                volume: ss.reduce(0) { $0 + $1.volume }
            )
        }
    }
}
