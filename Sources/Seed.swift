import Foundation

extension AppData {
    /// A fresh install: a usable starter plan and split, all of it editable.
    static func seed() -> AppData {
        var d = AppData()
        d.v = SCHEMA
        d.profile = Profile()
        d.foods = Seed.foods()

        let byName = Dictionary(uniqueKeysWithValues: d.foods.map { ($0.name, $0.id) })
        func item(_ name: String, _ qty: Double) -> MealItem {
            MealItem(id: UUID().uuidString, foodId: byName[name] ?? "", qty: qty)
        }

        d.meals = [
            Meal(id: UUID().uuidString, name: "Breakfast", items: [
                item("Rolled oats", 100), item("Scoop whey (30g)", 1),
                item("Banana, medium", 1), item("Tbsp peanut butter", 1)]),
            Meal(id: UUID().uuidString, name: "Lunch", items: [
                item("Chicken breast, cooked", 180), item("White rice, cooked", 250),
                item("Mixed veg", 150), item("Tbsp olive oil", 1)]),
            Meal(id: UUID().uuidString, name: "Pre-gym", items: [
                item("Greek yoghurt, full fat", 200), item("Honey", 20)]),
            Meal(id: UUID().uuidString, name: "Dinner", items: [
                item("Beef mince 5%", 200), item("Pasta, dry", 120), item("Mixed veg", 150)]),
            Meal(id: UUID().uuidString, name: "Before bed", items: [
                item("Milk, full cream", 300), item("Slice wholemeal bread", 2),
                item("Tbsp peanut butter", 1)])
        ]

        let push = ProgramDay(id: UUID().uuidString, name: "Push", exercises: [
            ProgramExercise(name: "Bench press", sets: 4, lo: 5, hi: 8),
            ProgramExercise(name: "Overhead press", sets: 3, lo: 6, hi: 10),
            ProgramExercise(name: "Incline dumbbell press", sets: 3, lo: 8, hi: 12),
            ProgramExercise(name: "Cable fly", sets: 3, lo: 12, hi: 15),
            ProgramExercise(name: "Triceps pushdown", sets: 3, lo: 10, hi: 15)
        ])
        let pull = ProgramDay(id: UUID().uuidString, name: "Pull", exercises: [
            ProgramExercise(name: "Deadlift", sets: 3, lo: 3, hi: 5),
            ProgramExercise(name: "Chin-up", sets: 4, lo: 6, hi: 10),
            ProgramExercise(name: "Barbell row", sets: 3, lo: 6, hi: 10),
            ProgramExercise(name: "Face pull", sets: 3, lo: 12, hi: 20),
            ProgramExercise(name: "Barbell curl", sets: 3, lo: 8, hi: 12)
        ])
        let legs = ProgramDay(id: UUID().uuidString, name: "Legs", exercises: [
            ProgramExercise(name: "Squat", sets: 4, lo: 5, hi: 8),
            ProgramExercise(name: "Romanian deadlift", sets: 3, lo: 8, hi: 12),
            ProgramExercise(name: "Leg press", sets: 3, lo: 10, hi: 15),
            ProgramExercise(name: "Leg curl", sets: 3, lo: 10, hi: 15),
            ProgramExercise(name: "Calf raise", sets: 4, lo: 10, hi: 15),
            ProgramExercise(name: "Plank", mode: .time, sets: 3, lo: 60, hi: 60)
        ])
        d.program = Program(days: [push, pull, legs],
                            schedule: [push.id, pull.id, legs.id, "rest", push.id, pull.id, "rest"])
        return d
    }
}

enum Seed {
    /// Per 100g unless the basis is "unit". Ordinary reference values, all editable.
    static let table: [(String, String, Double, Double, Double, Double)] = [
        ("Rolled oats", "100g", 379, 13.2, 67.7, 6.5),
        ("Whey protein", "100g", 400, 80, 8, 5),
        ("Chicken breast, cooked", "100g", 165, 31, 0, 3.6),
        ("Beef mince 5%", "100g", 137, 21, 0, 5),
        ("Beef mince 20%", "100g", 254, 17, 0, 20),
        ("Salmon fillet", "100g", 208, 20, 0, 13),
        ("Tuna, canned in water", "100g", 116, 26, 0, 1),
        ("Tofu, firm", "100g", 144, 17, 3, 9),
        ("White rice, cooked", "100g", 130, 2.7, 28, 0.3),
        ("Brown rice, cooked", "100g", 123, 2.7, 26, 1),
        ("Pasta, cooked", "100g", 158, 5.8, 31, 0.9),
        ("Pasta, dry", "100g", 371, 13, 75, 1.5),
        ("Potato", "100g", 77, 2, 17, 0.1),
        ("Sweet potato", "100g", 86, 1.6, 20, 0.1),
        ("Lentils, cooked", "100g", 116, 9, 20, 0.4),
        ("Chickpeas, cooked", "100g", 164, 8.9, 27, 2.6),
        ("Greek yoghurt, full fat", "100g", 97, 9, 3.6, 5),
        ("Greek yoghurt, low fat", "100g", 59, 10, 3.6, 0.4),
        ("Cottage cheese", "100g", 98, 11, 3.4, 4.3),
        ("Cheddar", "100g", 403, 25, 1.3, 33),
        ("Milk, full cream", "100g", 64, 3.4, 4.8, 3.6),
        ("Peanut butter", "100g", 588, 25, 20, 50),
        ("Almonds", "100g", 579, 21, 22, 50),
        ("Cashews", "100g", 553, 18, 30, 44),
        ("Pumpkin seeds", "100g", 559, 30, 11, 49),
        ("Olive oil", "100g", 884, 0, 0, 100),
        ("Avocado", "100g", 160, 2, 9, 15),
        ("Honey", "100g", 304, 0.3, 82, 0),
        ("Broccoli", "100g", 34, 2.8, 7, 0.4),
        ("Mixed veg", "100g", 45, 2, 8, 0.3),
        ("Wholemeal bread", "100g", 247, 13, 41, 3.4),
        ("Dark chocolate 70%", "100g", 598, 7.8, 46, 43),
        ("Large egg", "unit", 72, 6.3, 0.4, 4.8),
        ("Banana, medium", "unit", 105, 1.3, 27, 0.4),
        ("Apple, medium", "unit", 95, 0.5, 25, 0.3),
        ("Orange, medium", "unit", 62, 1.2, 15, 0.2),
        ("Slice wholemeal bread", "unit", 89, 4.7, 15, 1.2),
        ("Scoop whey (30g)", "unit", 120, 24, 2.4, 1.5),
        ("Handful of nuts (30g)", "unit", 174, 6, 7, 15),
        ("Tbsp peanut butter", "unit", 94, 4, 3, 8),
        ("Tbsp olive oil", "unit", 119, 0, 0, 13.5),
        ("Protein bar", "unit", 220, 20, 22, 7)
    ]

    static func foods() -> [Food] {
        table.map { Food(id: UUID().uuidString, name: $0.0, basis: $0.1,
                         kcal: $0.2, p: $0.3, c: $0.4, f: $0.5) }
    }
}

/// Reproducible invented history, so the charts have something to show
/// before there is anything real in the app.
enum Demo {
    private struct RNG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
        }
    }

    static let startWeights: [String: Double] = [
        "Bench press": 75, "Overhead press": 45, "Incline dumbbell press": 26,
        "Cable fly": 14, "Triceps pushdown": 30, "Deadlift": 120, "Chin-up": 75,
        "Barbell row": 60, "Face pull": 25, "Barbell curl": 25, "Squat": 100,
        "Romanian deadlift": 80, "Leg press": 150, "Leg curl": 40,
        "Calf raise": 60, "Plank": 60
    ]

    static func build() -> AppData {
        var d = AppData.seed()
        d.demo = true
        d.profile.startWeight = 71

        var rng = RNG(state: 20261030)
        let days = 112
        let today = DateKey.today()
        let perDay = 0.3 / 7.0
        var counts: [String: Int] = [:]
        var sessions: [Session] = []

        for i in stride(from: days - 1, through: 0, by: -1) {
            let key = DateKey.shift(today, -i)
            let idx = Double(days - 1 - i)
            let trend = 71 + perDay * idx

            if rng.next() < 0.88 {
                var day = d.log[key] ?? DayLog(date: key)
                day.weight = ((trend + (rng.next() - 0.5) * 0.9) * 100).rounded() / 100
                d.log[key] = day
            }
            if rng.next() < 0.84 {
                var day = d.log[key] ?? DayLog(date: key)
                day.logged = true
                day.missed = []
                let roll = rng.next()
                if roll > 0.52 {
                    let all = d.meals.flatMap { $0.items.map { $0.id } }
                    let count = roll > 0.9 ? 2 : 1
                    for _ in 0..<count {
                        let pick = all[Int(rng.next() * Double(all.count)) % max(1, all.count)]
                        if !day.missed.contains(pick) { day.missed.append(pick) }
                    }
                }
                if rng.next() < 0.13 {
                    day.extras = [Extra(name: "Takeaway on the way home",
                                        kcal: 650 + (rng.next() * 450).rounded(),
                                        p: 32, c: 68, f: 34)]
                }
                d.log[key] = day
            }

            guard let programDay = d.program.day(forWeekdayIndex: DateKey.weekdayIndex(key)),
                  rng.next() < 0.86 else { continue }

            let entries = programDay.exercises.map { ex -> SessionEntry in
                let c = (counts[ex.name] ?? 0) + 1
                counts[ex.name] = c
                let base = startWeights[ex.name] ?? 40
                let step: Double = base >= 100 ? 5 : 2.5
                let weight = base + Double((c - 1) / 2) * step
                var sets: [SetEntry] = []
                for q in 0..<max(1, ex.sets) {
                    var val = ex.lo + Int(rng.next() * Double(max(1, ex.hi - ex.lo + 1)))
                    if q == ex.sets - 1 && val > ex.lo { val -= 1 }
                    switch ex.mode {
                    case .time:
                        sets.append(SetEntry(t: String(val + ((c - 1) / 3) * 5)))
                    case .weight:
                        sets.append(SetEntry(w: Fmt.trim(weight), r: String(val)))
                    }
                }
                return SessionEntry(name: ex.name, mode: ex.mode,
                                    target: SessionTarget(sets: ex.sets, lo: ex.lo, hi: ex.hi),
                                    sets: sets)
            }
            sessions.append(Session(date: key, dayId: programDay.id, dayName: programDay.name,
                                    locked: true, entries: entries))
        }
        d.sessions = sessions.reversed()
        return d
    }
}
