import Foundation

// The on-disk shape is deliberately identical to the web version's backup JSON,
// so a backup exported there imports here untouched, and vice versa.
// Set values stay as strings for exactly that reason.

let SCHEMA = 2

// MARK: - Lenient scalar

/// Decodes a field that may arrive as a string or a number and keeps it as text.
struct Flex: Codable, Hashable {
    var text: String

    init(_ t: String = "") { text = t }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s }
        else if let d = try? c.decode(Double.self) { text = Fmt.trim(d) }
        else if let i = try? c.decode(Int.self) { text = String(i) }
        else if let b = try? c.decode(Bool.self) { text = b ? "1" : "" }
        else { text = "" }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(text)
    }

    var value: Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var filled: Bool { value > 0 }
}

// MARK: - Progress photo slots

enum PhotoSlot: String, Codable, CaseIterable, Identifiable {
    case front, back, frontflex, backflex
    var id: String { rawValue }

    var label: String {
        switch self {
        case .front:     return "Front relaxed"
        case .back:      return "Back relaxed"
        case .frontflex: return "Front flexed"
        case .backflex:  return "Back flexed"
        }
    }
    /// Shorter form for chips and captions.
    var short: String {
        switch self {
        case .front:     return "Front"
        case .back:      return "Back"
        case .frontflex: return "Front flex"
        case .backflex:  return "Back flex"
        }
    }
}

// MARK: - Exercise kinds

enum ExMode: String, Codable, CaseIterable, Identifiable {
    case weight, time
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight x reps"
        case .time:   return "Time held"
        }
    }
    /// Unit shown beside a best-set figure.
    func unit(_ bodyUnit: String) -> String {
        switch self {
        case .weight: return bodyUnit
        case .time:   return "s"
        }
    }
    var minMaxNoun: String {
        self == .time ? "seconds" : "reps"
    }

    /// Backups written by an earlier version may name a mode this one dropped.
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? "weight"
        self = (raw == "time") ? .time : .weight
    }
}

// MARK: - Food

struct Food: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var basis: String      // "100g" or "unit"
    var kcal: Double
    var p: Double
    var c: Double
    var f: Double

    var perUnit: Bool { basis == "unit" }
    var qtySuffix: String { perUnit ? "x" : "g" }
}

struct MealItem: Codable, Identifiable, Hashable {
    var id: String
    var foodId: String
    var qty: Double
}

struct Meal: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var items: [MealItem]
}

// MARK: - Training

struct ProgramExercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var mode: ExMode
    var sets: Int
    var lo: Int
    var hi: Int
    var note: String

    enum CodingKeys: String, CodingKey { case id, name, mode, sets, lo, hi, note }

    init(id: String = UUID().uuidString, name: String, mode: ExMode = .weight,
         sets: Int = 3, lo: Int = 8, hi: Int = 12, note: String = "") {
        self.id = id; self.name = name; self.mode = mode
        self.sets = sets; self.lo = lo; self.hi = hi; self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Exercise"
        mode = (try? c.decode(ExMode.self, forKey: .mode)) ?? .weight
        sets = (try? c.decode(Int.self, forKey: .sets)) ?? 3
        lo   = (try? c.decode(Int.self, forKey: .lo)) ?? 8
        hi   = (try? c.decode(Int.self, forKey: .hi)) ?? 12
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
    }
}

struct ProgramDay: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var exercises: [ProgramExercise]
}

struct Program: Codable, Hashable {
    var days: [ProgramDay]
    var schedule: [String]      // 7 entries, Monday first, "rest" or a day id

    func day(forWeekdayIndex i: Int) -> ProgramDay? {
        guard i >= 0, i < schedule.count else { return nil }
        let id = schedule[i]
        guard id != "rest" else { return nil }
        return days.first { $0.id == id }
    }
}

struct SetEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var w: Flex
    var r: Flex
    var t: Flex

    enum CodingKeys: String, CodingKey { case w, r, t }

    init(w: String = "", r: String = "", t: String = "") {
        self.w = Flex(w); self.r = Flex(r); self.t = Flex(t)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        w = (try? c.decode(Flex.self, forKey: .w)) ?? Flex()
        r = (try? c.decode(Flex.self, forKey: .r)) ?? Flex()
        t = (try? c.decode(Flex.self, forKey: .t)) ?? Flex()
        id = UUID()
    }

    func filled(_ mode: ExMode) -> Bool {
        switch mode {
        case .time:   return t.filled
        case .weight: return w.filled && r.filled
        }
    }

    /// The number this set contributes to a best-set comparison.
    func metric(_ mode: ExMode) -> Double {
        switch mode {
        case .time:   return t.value
        case .weight: return Calc.epley(w.value, r.value)
        }
    }
}

struct SessionTarget: Codable, Hashable {
    var sets: Int
    var lo: Int
    var hi: Int
}

struct SessionEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var mode: ExMode
    var note: String
    var target: SessionTarget?
    var sets: [SetEntry]

    enum CodingKeys: String, CodingKey { case name, mode, note, target, sets }

    init(name: String, mode: ExMode = .weight, note: String = "",
         target: SessionTarget? = nil, sets: [SetEntry] = []) {
        self.name = name; self.mode = mode; self.note = note
        self.target = target; self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name   = (try? c.decode(String.self, forKey: .name)) ?? "Exercise"
        mode   = (try? c.decode(ExMode.self, forKey: .mode)) ?? .weight
        note   = (try? c.decode(String.self, forKey: .note)) ?? ""
        target = try? c.decode(SessionTarget.self, forKey: .target)
        sets   = (try? c.decode([SetEntry].self, forKey: .sets)) ?? []
        id = UUID()
    }

    var doneSets: [SetEntry] { sets.filter { $0.filled(mode) } }
}

struct Session: Codable, Hashable, Identifiable {
    var id: String
    var date: String
    var dayId: String?
    var dayName: String
    var locked: Bool
    var entries: [SessionEntry]

    enum CodingKeys: String, CodingKey { case id, date, dayId, dayName, locked, entries }

    init(id: String = UUID().uuidString, date: String, dayId: String?,
         dayName: String, locked: Bool = false, entries: [SessionEntry]) {
        self.id = id; self.date = date; self.dayId = dayId
        self.dayName = dayName; self.locked = locked; self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id      = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        date    = (try? c.decode(String.self, forKey: .date)) ?? DateKey.today()
        dayId   = try? c.decode(String.self, forKey: .dayId)
        dayName = (try? c.decode(String.self, forKey: .dayName)) ?? "Session"
        locked  = (try? c.decode(Bool.self, forKey: .locked)) ?? true
        entries = (try? c.decode([SessionEntry].self, forKey: .entries)) ?? []
    }

    var volume: Double {
        entries.reduce(0) { acc, en in
            guard en.mode == .weight else { return acc }
            return acc + en.sets.reduce(0) { $0 + $1.w.value * $1.r.value }
        }
    }
    var topSet: Double {
        entries.reduce(0) { acc, en in
            guard en.mode == .weight else { return acc }
            return max(acc, en.sets.filter { $0.filled(.weight) }
                                   .reduce(0) { max($0, Calc.epley($1.w.value, $1.r.value)) })
        }
    }
}

// MARK: - Daily log

struct Extra: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var kcal: Double
    var p: Double
    var c: Double
    var f: Double

    enum CodingKeys: String, CodingKey { case name, kcal, p, c, f }

    init(name: String, kcal: Double, p: Double, c: Double, f: Double) {
        self.name = name; self.kcal = kcal; self.p = p; self.c = c; self.f = f
    }

    init(from decoder: Decoder) throws {
        let cc = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? cc.decode(String.self, forKey: .name)) ?? "Extra"
        kcal = (try? cc.decode(Double.self, forKey: .kcal)) ?? 0
        p = (try? cc.decode(Double.self, forKey: .p)) ?? 0
        c = (try? cc.decode(Double.self, forKey: .c)) ?? 0
        f = (try? cc.decode(Double.self, forKey: .f)) ?? 0
        id = UUID()
    }
}

struct DayLog: Codable, Hashable {
    var date: String
    var weight: Double?
    var logged: Bool
    var missed: [String]
    var extras: [Extra]

    enum CodingKeys: String, CodingKey { case date, weight, logged, missed, extras }

    init(date: String) {
        self.date = date; weight = nil; logged = false; missed = []; extras = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date   = (try? c.decode(String.self, forKey: .date)) ?? ""
        weight = try? c.decode(Double.self, forKey: .weight)
        logged = (try? c.decode(Bool.self, forKey: .logged)) ?? false
        missed = (try? c.decode([String].self, forKey: .missed)) ?? []
        extras = (try? c.decode([Extra].self, forKey: .extras)) ?? []
        if let w = weight, w <= 0 { weight = nil }
    }
}

// MARK: - Profile

struct Profile: Codable, Hashable {
    var unit: String = "kg"
    var startWeight: Double? = nil
    var sex: String = "m"
    var age: Int? = nil
    var height: Double? = nil
    var activity: Double = 1.55
    var kcal: Double = 3000
    var p: Double = 210
    var c: Double = 355
    var f: Double = 81
    var rateLow: Double = 0.2
    var rateHigh: Double = 0.4
    var calcBw: Double? = nil
    var faceID: Bool = false

    enum CodingKeys: String, CodingKey {
        case unit, startWeight, sex, age, height, activity
        case kcal, p, c, f, rateLow, rateHigh, calcBw, faceID
    }

    init() {}

    init(from decoder: Decoder) throws {
        let cc = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        unit        = (try? cc.decode(String.self, forKey: .unit)) ?? d.unit
        startWeight = try? cc.decode(Double.self, forKey: .startWeight)
        sex         = (try? cc.decode(String.self, forKey: .sex)) ?? d.sex
        age         = try? cc.decode(Int.self, forKey: .age)
        height      = try? cc.decode(Double.self, forKey: .height)
        activity    = (try? cc.decode(Double.self, forKey: .activity)) ?? d.activity
        kcal        = (try? cc.decode(Double.self, forKey: .kcal)) ?? d.kcal
        p           = (try? cc.decode(Double.self, forKey: .p)) ?? d.p
        c           = (try? cc.decode(Double.self, forKey: .c)) ?? d.c
        f           = (try? cc.decode(Double.self, forKey: .f)) ?? d.f
        rateLow     = (try? cc.decode(Double.self, forKey: .rateLow)) ?? d.rateLow
        rateHigh    = (try? cc.decode(Double.self, forKey: .rateHigh)) ?? d.rateHigh
        calcBw      = try? cc.decode(Double.self, forKey: .calcBw)
        faceID      = (try? cc.decode(Bool.self, forKey: .faceID)) ?? false
    }
}

// MARK: - Root

struct AppData: Codable {
    var v: Int = SCHEMA
    var profile = Profile()
    var foods: [Food] = []
    var meals: [Meal] = []
    var program = Program(days: [], schedule: Array(repeating: "rest", count: 7))
    var log: [String: DayLog] = [:]
    var sessions: [Session] = []
    var demo: Bool = false
    var touched: Bool = false
    var lastBackup: String? = nil

    enum CodingKeys: String, CodingKey {
        case v, profile, foods, meals, program, log, sessions, demo, touched, lastBackup
    }

    init() {}

    /// Anything an older backup is missing falls back to a fresh default,
    /// so data from any earlier version opens without losing what it did have.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let seed = AppData.seed()
        v        = SCHEMA
        profile  = (try? c.decode(Profile.self, forKey: .profile)) ?? seed.profile
        foods    = (try? c.decode([Food].self, forKey: .foods)) ?? seed.foods
        meals    = (try? c.decode([Meal].self, forKey: .meals)) ?? []
        program  = (try? c.decode(Program.self, forKey: .program)) ?? seed.program
        log      = (try? c.decode([String: DayLog].self, forKey: .log)) ?? [:]
        sessions = (try? c.decode([Session].self, forKey: .sessions)) ?? []
        demo     = (try? c.decode(Bool.self, forKey: .demo)) ?? false
        touched  = (try? c.decode(Bool.self, forKey: .touched)) ?? false
        lastBackup = try? c.decode(String.self, forKey: .lastBackup)

        if program.schedule.count != 7 {
            var s = program.schedule
            while s.count < 7 { s.append("rest") }
            program.schedule = Array(s.prefix(7))
        }
        for (k, var day) in log where day.date.isEmpty {
            day.date = k
            log[k] = day
        }
    }
}
