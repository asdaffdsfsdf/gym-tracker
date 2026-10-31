import SwiftUI
import UIKit

struct PlanView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var foodSearch = ""
    @State private var showCalc = false
    @State private var addingTo: String? = nil
    @State private var pickerSearch = ""
    @State private var showNewFood = false
    @State private var nf = NewFood()
    @State private var showExport = false
    @State private var importing = false
    @State private var importText = ""
    @State private var danger: Danger? = nil

    enum DangerKind { case loadDemo, clearDemo, wipe }
    struct Danger { var kind: DangerKind; var stage: Int }
    @State private var toast: String? = nil

    struct NewFood {
        var name = ""; var basis = "100g"
        var kcal = ""; var p = ""; var c = ""; var f = ""
    }

    private var d: AppData { store.data }
    private var unit: String { d.profile.unit }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("", selection: $tab) {
                    Text("Targets").tag(0)
                    Text("Food").tag(1)
                    Text("Program").tag(2)
                    Text("Data").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 2)
                .onChange(of: tab) { _, _ in danger = nil }

                switch tab {
                case 0: targetsTab
                case 1: foodTab
                case 2: programTab
                default: dataTab
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(T.bg)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(T.ink, in: Capsule())
                    .foregroundStyle(T.bg)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
    }

    private func flash(_ s: String) {
        withAnimation { toast = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { if toast == s { toast = nil } }
        }
    }

    // MARK: Targets

    private var targetsTab: some View {
        VStack(spacing: 10) {
            Card(title: "Daily targets") {
                HStack(spacing: 10) {
                    numBox("Calories", Binding(
                        get: { Fmt.r0(d.profile.kcal) },
                        set: { store.data.profile.kcal = Double($0) ?? 0; store.save() }))
                    numBox("Protein", Binding(
                        get: { Fmt.r0(d.profile.p) },
                        set: { store.data.profile.p = Double($0) ?? 0; store.save() }))
                }
                HStack(spacing: 10) {
                    numBox("Carbs", Binding(
                        get: { Fmt.r0(d.profile.c) },
                        set: { store.data.profile.c = Double($0) ?? 0; store.save() }))
                    numBox("Fat", Binding(
                        get: { Fmt.r0(d.profile.f) },
                        set: { store.data.profile.f = Double($0) ?? 0; store.save() }))
                }
                let fromMacros = d.profile.p * 4 + d.profile.c * 4 + d.profile.f * 9
                if abs(fromMacros - d.profile.kcal) > 60 {
                    Text("Your macros add up to \(Fmt.r0(fromMacros)) kcal, which does not match your calorie target.")
                        .font(.system(size: 12.5)).foregroundStyle(T.warn)
                }
                Button { showCalc.toggle() } label: {
                    Text(showCalc ? "Hide calculator" : "Work out my targets for me")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if showCalc { calculator }
            }

            Card(title: "Weight goals") {
                HStack(spacing: 10) {
                    numBox("Starting weight", Binding(
                        get: { d.profile.startWeight.map { Fmt.n2($0) } ?? "" },
                        set: { store.data.profile.startWeight = Double($0); store.save() }))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UNIT").font(.system(size: 10, weight: .semibold))
                            .kerning(0.6).foregroundStyle(T.mut)
                        Picker("", selection: Binding(
                            get: { d.profile.unit },
                            set: { store.data.profile.unit = $0; store.save() })) {
                            Text("kg").tag("kg"); Text("lb").tag("lb")
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack(spacing: 10) {
                    numBox("Slowest ok gain/wk", Binding(
                        get: { Fmt.n2(d.profile.rateLow) },
                        set: { store.data.profile.rateLow = Double($0) ?? 0.2; store.save() }))
                    numBox("Fastest ok gain/wk", Binding(
                        get: { Fmt.n2(d.profile.rateHigh) },
                        set: { store.data.profile.rateHigh = Double($0) ?? 0.4; store.save() }))
                }
            }

            Card(title: "Privacy") {
                Toggle(isOn: Binding(
                    get: { d.profile.faceID },
                    set: { store.data.profile.faceID = $0; store.save() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Require Face ID").font(.system(size: 14))
                        Text("Locks the app, your log and your photos behind Face ID.")
                            .font(.system(size: 12)).foregroundStyle(T.mut)
                    }
                }
                .tint(T.accent)
            }
        }
    }

    private var calculator: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                numBox("Weight (\(unit))", Binding(
                    get: { d.profile.calcBw.map { Fmt.n2($0) } ?? "" },
                    set: { store.data.profile.calcBw = Double($0); store.save() }))
                numBox("Height (cm)", Binding(
                    get: { d.profile.height.map { Fmt.r0($0) } ?? "" },
                    set: { store.data.profile.height = Double($0); store.save() }))
            }
            HStack(spacing: 10) {
                numBox("Age", Binding(
                    get: { d.profile.age.map { String($0) } ?? "" },
                    set: { store.data.profile.age = Int($0); store.save() }))
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEX").font(.system(size: 10, weight: .semibold))
                        .kerning(0.6).foregroundStyle(T.mut)
                    Picker("", selection: Binding(
                        get: { d.profile.sex },
                        set: { store.data.profile.sex = $0; store.save() })) {
                        Text("Male").tag("m"); Text("Female").tag("f")
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("ACTIVITY").font(.system(size: 10, weight: .semibold))
                    .kerning(0.6).foregroundStyle(T.mut)
                Picker("", selection: Binding(
                    get: { d.profile.activity },
                    set: { store.data.profile.activity = $0; store.save() })) {
                    Text("Sedentary").tag(1.2)
                    Text("1-3 a week").tag(1.375)
                    Text("3-5").tag(1.55)
                    Text("6-7").tag(1.725)
                    Text("Physical job").tag(1.9)
                }
                .pickerStyle(.menu).tint(T.accent)
            }

            let bw = d.profile.calcBw ?? Calc.trendNow(d.log)?.v ?? 0
            if bw > 0, let h = d.profile.height, h > 0, let age = d.profile.age, age > 0 {
                let r = Calc.macros(bw: bw, height: h, age: age, sex: d.profile.sex,
                                    activity: d.profile.activity, surplusPct: 12)
                KPIRow {
                    KPI(label: "Maintenance", value: "\(r.tdee)", unit: "kcal", sub: "BMR \(r.bmr)")
                    Divider().frame(height: 34)
                    KPI(label: "Bulk target", value: "\(r.kcal)", unit: "kcal", sub: "+12%")
                        .padding(.leading, 12)
                    Divider().frame(height: 34)
                    KPI(label: "Protein", value: "\(r.p)", unit: "g", sub: "1.8/\(unit)")
                        .padding(.leading, 12)
                }
                Button {
                    store.data.profile.kcal = Double(r.kcal)
                    store.data.profile.p = Double(r.p)
                    store.data.profile.c = Double(r.c)
                    store.data.profile.f = Double(r.f)
                    if store.data.profile.startWeight == nil { store.data.profile.startWeight = bw }
                    store.save()
                    showCalc = false
                    flash("Targets set.")
                } label: {
                    Text("Use these targets").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Text("A starting guess. Let the scale correct it over the first fortnight.")
                    .font(.system(size: 12.5)).foregroundStyle(T.mut)
            } else {
                Text("Fill in weight, height and age and the numbers appear.")
                    .font(.system(size: 12.5)).foregroundStyle(T.mut)
            }
        }
    }

    private func numBox(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).kerning(0.6)
                .foregroundStyle(T.mut).lineLimit(1).minimumScaleFactor(0.8)
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .padding(10)
                .background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Food

    private var foodTab: some View {
        let plan = Calc.planTotals(d.meals, d.foods)
        return VStack(spacing: 10) {
            Card(title: "Daily plan") {
                HStack(alignment: .top, spacing: 0) {
                    KPI(label: "Calories", value: Fmt.r0(plan.kcal),
                        sub: Fmt.signedInt(plan.kcal - d.profile.kcal), compact: true)
                    KPI(label: "Protein", value: Fmt.r0(plan.p), unit: "g",
                        sub: Fmt.signedInt(plan.p - d.profile.p), compact: true)
                    KPI(label: "Carbs", value: Fmt.r0(plan.c), unit: "g",
                        sub: Fmt.signedInt(plan.c - d.profile.c), compact: true)
                    KPI(label: "Fat", value: Fmt.r0(plan.f), unit: "g",
                        sub: Fmt.signedInt(plan.f - d.profile.f), compact: true)
                }
                let gap = plan.kcal - d.profile.kcal
                if abs(gap) >= 60 {
                    Text("Eating the whole plan puts you \(Fmt.r0(abs(gap))) kcal \(gap > 0 ? "over" : "under") target. Adjust the quantities below.")
                        .font(.system(size: 12.5)).foregroundStyle(T.mut)
                }
            }

            ForEach(d.meals) { meal in planMealCard(meal) }

            Button { store.data.meals.append(Meal(id: UUID().uuidString, name: "New meal", items: [])); store.save() } label: {
                Text("Add a meal")
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(T.card, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            foodLibrary
        }
    }

    private func planMealCard(_ meal: Meal) -> some View {
        let totals = meal.items.reduce(Calc.Macros()) { $0 + Calc.itemMacros($1, d.foods) }
        return Card {
            HStack {
                TextField("Meal", text: Binding(
                    get: { meal.name },
                    set: { nv in
                        if let i = store.data.meals.firstIndex(where: { $0.id == meal.id }) {
                            store.data.meals[i].name = nv; store.save()
                        }
                    }))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Fmt.r0(totals.kcal)) kcal · \(Fmt.r0(totals.p))P · \(Fmt.r0(totals.c))C · \(Fmt.r0(totals.f))F")
                    .font(.system(size: 11)).foregroundStyle(T.mut).monospacedDigit()
            }

            ForEach(meal.items) { item in
                let food = d.foods.first { $0.id == item.foodId }
                let m = Calc.itemMacros(item, d.foods)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food?.name ?? "(removed food)")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("", text: Binding(
                            get: { Fmt.trim(item.qty) },
                            set: { nv in
                                if let mi = store.data.meals.firstIndex(where: { $0.id == meal.id }),
                                   let ii = store.data.meals[mi].items.firstIndex(where: { $0.id == item.id }) {
                                    store.data.meals[mi].items[ii].qty = Double(nv) ?? 0
                                    store.save()
                                }
                            }))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .frame(width: 66)
                            .padding(.vertical, 7)
                            .background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
                        Text(food?.qtySuffix ?? "")
                            .font(.system(size: 12)).foregroundStyle(T.mut).frame(width: 14)
                        Button {
                            if let mi = store.data.meals.firstIndex(where: { $0.id == meal.id }) {
                                store.data.meals[mi].items.removeAll { $0.id == item.id }
                                store.save()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(T.mut)
                        }
                    }
                    Text("\(Fmt.r0(m.kcal)) kcal · \(Fmt.r0(m.p))P · \(Fmt.r0(m.c))C · \(Fmt.r0(m.f))F")
                        .font(.system(size: 11)).foregroundStyle(T.mut).monospacedDigit()
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
            }

            HStack {
                Button(addingTo == meal.id ? "Close" : "Add food") {
                    addingTo = addingTo == meal.id ? nil : meal.id
                    pickerSearch = ""
                }
                .font(.system(size: 13))
                Spacer()
                Button("Remove meal") {
                    store.data.meals.removeAll { $0.id == meal.id }
                    store.save()
                }
                .font(.system(size: 13)).foregroundStyle(T.mut)
            }

            if addingTo == meal.id {
                Divider()
                TextField("Search your foods", text: $pickerSearch)
                    .padding(9).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                let hits = d.foods.filter {
                    pickerSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(pickerSearch)
                }.prefix(8)
                ForEach(Array(hits)) { f in
                    Button {
                        if let mi = store.data.meals.firstIndex(where: { $0.id == meal.id }) {
                            store.data.meals[mi].items.append(
                                MealItem(id: UUID().uuidString, foodId: f.id,
                                         qty: f.perUnit ? 1 : 100))
                            store.save()
                        }
                        addingTo = nil
                    } label: {
                        HStack {
                            Text(f.name).font(.system(size: 14))
                            Spacer()
                            Text("\(Fmt.r0(f.kcal)) kcal\(f.perUnit ? " each" : "/100g")")
                                .font(.system(size: 11)).foregroundStyle(T.mut)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var foodLibrary: some View {
        let hits = d.foods.filter {
            foodSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(foodSearch)
        }
        return Card(title: "Your foods") {
            Text("Macros per 100g, or per item for countable things. These drive every total.")
                .font(.system(size: 12.5)).foregroundStyle(T.mut)
            TextField("Search", text: $foodSearch)
                .padding(9).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("FOOD").frame(maxWidth: .infinity, alignment: .leading)
                Text("KCAL").frame(width: 46, alignment: .trailing)
                Text("P").frame(width: 36, alignment: .trailing)
                Text("C").frame(width: 36, alignment: .trailing)
                Text("F").frame(width: 36, alignment: .trailing)
                Spacer().frame(width: 24)
            }
            .font(.system(size: 10, weight: .semibold)).kerning(0.6).foregroundStyle(T.mut)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(hits) { f in
                        HStack {
                            Text(f.name).font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Fmt.r0(f.kcal)).frame(width: 46, alignment: .trailing)
                            Text(Fmt.trim(f.p)).frame(width: 36, alignment: .trailing)
                            Text(Fmt.trim(f.c)).frame(width: 36, alignment: .trailing)
                            Text(Fmt.trim(f.f)).frame(width: 36, alignment: .trailing)
                            Button {
                                store.data.foods.removeAll { $0.id == f.id }
                                store.save()
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(T.mut)
                            }
                            .frame(width: 24)
                        }
                        .font(.system(size: 12)).monospacedDigit()
                        .padding(.vertical, 9)
                        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 0.5) }
                    }
                }
            }
            .frame(maxHeight: 300)

            Button { showNewFood.toggle() } label: {
                Text(showNewFood ? "Cancel" : "Add a food")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if showNewFood {
                TextField("Name", text: $nf.name)
                    .padding(9).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                Picker("", selection: $nf.basis) {
                    Text("Per 100g").tag("100g")
                    Text("Per item").tag("unit")
                }
                .pickerStyle(.segmented)
                HStack(spacing: 9) {
                    NumField(placeholder: "kcal", text: $nf.kcal)
                    NumField(placeholder: "protein", text: $nf.p)
                }
                HStack(spacing: 9) {
                    NumField(placeholder: "carbs", text: $nf.c)
                    NumField(placeholder: "fat", text: $nf.f)
                }
                Button {
                    let n = nf.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    store.data.foods.insert(
                        Food(id: UUID().uuidString, name: n, basis: nf.basis,
                             kcal: Double(nf.kcal) ?? 0, p: Double(nf.p) ?? 0,
                             c: Double(nf.c) ?? 0, f: Double(nf.f) ?? 0), at: 0)
                    store.save()
                    nf = NewFood(); showNewFood = false
                    flash("Added \(n).")
                } label: {
                    Text("Save food").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Program

    private var programTab: some View {
        VStack(spacing: 10) {
            Card(title: "Weekly split", meta: "what lands on each day") {
                ForEach(0..<7, id: \.self) { i in
                    HStack(spacing: 11) {
                        Text(DateKey.dayNames[i])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.mut).frame(width: 36, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { d.program.schedule.indices.contains(i) ? d.program.schedule[i] : "rest" },
                            set: { nv in
                                if store.data.program.schedule.indices.contains(i) {
                                    store.data.program.schedule[i] = nv
                                    store.save()
                                }
                            })) {
                            Text("Rest").tag("rest")
                            ForEach(d.program.days) { pd in Text(pd.name).tag(pd.id) }
                        }
                        .pickerStyle(.menu).tint(T.accent)
                        Spacer()
                    }
                }
            }

            ForEach(d.program.days) { pd in programDayCard(pd) }

            Button {
                store.data.program.days.append(
                    ProgramDay(id: UUID().uuidString, name: "New day", exercises: []))
                store.save()
            } label: {
                Text("Add a workout day")
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(T.card, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func programDayCard(_ pd: ProgramDay) -> some View {
        Card {
            HStack {
                TextField("Day", text: Binding(
                    get: { pd.name },
                    set: { nv in
                        if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }) {
                            store.data.program.days[i].name = nv; store.save()
                        }
                    }))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(pd.exercises.count) exercises")
                    .font(.system(size: 11)).foregroundStyle(T.mut)
            }

            ForEach(pd.exercises) { ex in
                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        TextField("Exercise", text: exBinding(pd.id, ex.id, \.name))
                            .font(.system(size: 14))
                            .padding(8).background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
                        Button {
                            if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }) {
                                store.data.program.days[i].exercises.removeAll { $0.id == ex.id }
                                store.save()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(T.mut)
                        }
                    }
                    HStack(spacing: 7) {
                        Picker("", selection: Binding(
                            get: { ex.mode },
                            set: { nv in
                                if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }),
                                   let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == ex.id }) {
                                    store.data.program.days[i].exercises[j].mode = nv
                                    // a rep range and a hold target are different numbers
                                    if nv == .time {
                                        store.data.program.days[i].exercises[j].lo = 60
                                        store.data.program.days[i].exercises[j].hi = 60
                                    } else if store.data.program.days[i].exercises[j].lo
                                              == store.data.program.days[i].exercises[j].hi {
                                        store.data.program.days[i].exercises[j].lo = 8
                                        store.data.program.days[i].exercises[j].hi = 12
                                    }
                                    store.save()
                                }
                            })) {
                            ForEach(ExMode.allCases) { m in Text(m.label).tag(m) }
                        }
                        .pickerStyle(.menu).tint(T.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        intBox(exIntBinding(pd.id, ex.id, \.sets), width: 44)
                        if ex.mode == .time {
                            intBox(secondsBinding(pd.id, ex.id), width: 70)
                        } else {
                            intBox(exIntBinding(pd.id, ex.id, \.lo), width: 50)
                            intBox(exIntBinding(pd.id, ex.id, \.hi), width: 50)
                        }
                    }
                    TextField("Notes", text: exBinding(pd.id, ex.id, \.note))
                        .font(.system(size: 13))
                        .padding(8).background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
            }

            HStack {
                let allTime = !pd.exercises.isEmpty && pd.exercises.allSatisfy { $0.mode == .time }
                let anyTime = pd.exercises.contains { $0.mode == .time }
                Text("Type · sets · " + (allTime ? "seconds"
                                        : anyTime ? "reps or seconds" : "min · max reps"))
                    .font(.system(size: 11)).foregroundStyle(T.mut)
                Spacer()
            }

            HStack {
                Button("Add exercise") {
                    if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }) {
                        store.data.program.days[i].exercises.append(
                            ProgramExercise(name: "New exercise"))
                        store.save()
                    }
                }
                .font(.system(size: 13))
                Spacer()
                Button("Remove day") {
                    store.data.program.days.removeAll { $0.id == pd.id }
                    store.data.program.schedule = store.data.program.schedule.map {
                        $0 == pd.id ? "rest" : $0 }
                    store.save()
                }
                .font(.system(size: 13)).foregroundStyle(T.mut)
            }
        }
    }

    private func exBinding(_ dayId: String, _ exId: String,
                           _ key: WritableKeyPath<ProgramExercise, String>) -> Binding<String> {
        Binding(
            get: {
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId })
                else { return "" }
                return store.data.program.days[i].exercises[j][keyPath: key]
            },
            set: { nv in
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId })
                else { return }
                store.data.program.days[i].exercises[j][keyPath: key] = nv
                store.save()
            })
    }

    private func exIntBinding(_ dayId: String, _ exId: String,
                              _ key: WritableKeyPath<ProgramExercise, Int>) -> Binding<String> {
        Binding(
            get: {
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId })
                else { return "" }
                return String(store.data.program.days[i].exercises[j][keyPath: key])
            },
            set: { nv in
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId }),
                      let v = Int(nv) else { return }
                store.data.program.days[i].exercises[j][keyPath: key] = v
                store.save()
            })
    }

    /// A single hold target, written to both ends of the range.
    private func secondsBinding(_ dayId: String, _ exId: String) -> Binding<String> {
        Binding(
            get: {
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId })
                else { return "" }
                return String(store.data.program.days[i].exercises[j].hi)
            },
            set: { nv in
                guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
                      let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId }),
                      let v = Int(nv) else { return }
                store.data.program.days[i].exercises[j].lo = v
                store.data.program.days[i].exercises[j].hi = v
                store.save()
            })
    }

    private func intBox(_ text: Binding<String>, width: CGFloat) -> some View {
        TextField("", text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: width)
            .padding(.vertical, 9)
            .background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Data

    private var dataTab: some View {
        VStack(spacing: 10) {
            Card(title: "Demo data", meta: d.demo ? "loaded" : nil) {
                if d.demo {
                    Text("Invented history so the charts have something to show. Clearing empties the app back to a fresh start.")
                        .font(.system(size: 13)).foregroundStyle(T.mut)
                    dangerBlock(.clearDemo, opening: "Clear it and start fresh",
                                summary: "Starting fresh removes \(dataSummary), including anything real you have added since loading the demo.",
                                finalLabel: "Clear everything")
                } else {
                    Text("Fills the app with invented history so you can see every feature working.")
                        .font(.system(size: 13)).foregroundStyle(T.mut)
                    dangerBlock(.loadDemo, opening: "Load demo data",
                                summary: untouched
                                    ? "Nothing of yours is in the app yet, so there is nothing to lose. The demo replaces the starter plan and program."
                                    : "Loading the demo replaces \(dataSummary) with invented history.",
                                finalLabel: "Replace it with demo data")
                }
            }

            Card(title: "Backup", meta: "\(d.log.count) days · \(d.sessions.count) sessions") {
                HStack(spacing: 9) {
                    Button {
                        UIPasteboard.general.string = store.backupJSON()
                        store.markBackedUp()
                        flash("Copied.")
                    } label: {
                        Text("Copy backup").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.accent, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    ShareLink(item: store.backupJSON()) {
                        Text("Share")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
                Text(d.lastBackup == nil
                     ? "Never backed up. This phone is the only place your data exists."
                     : "Last copied \(DateKey.dmy(d.lastBackup!)).")
                    .font(.system(size: 12.5)).foregroundStyle(T.mut)
            }

            Card(title: "Import", meta: "replaces everything") {
                Text("Paste a backup from this app or from the web version.")
                    .font(.system(size: 13)).foregroundStyle(T.mut)
                plainButton(importing ? "Cancel" : "Import a backup") { importing.toggle() }
                if importing {
                    TextEditor(text: $importText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 130)
                        .padding(6)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        switch store.importBackup(importText) {
                        case .ok(let older):
                            importText = ""; importing = false
                            flash(older ? "Restored and updated from an older version." : "Restored.")
                        case .bad:
                            flash("That does not look like a Gym Tracker backup.")
                        }
                    } label: {
                        Text("Replace everything with this").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(T.bad.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(T.bad)
                    }
                    .buttonStyle(.plain)
                }
            }

            Card(title: "Spreadsheet", meta: "csv") {
                Text("Your days and sessions as two tables. For reading only, it cannot be imported back.")
                    .font(.system(size: 13)).foregroundStyle(T.mut)
                HStack(spacing: 9) {
                    plainButton("Copy CSV") {
                        UIPasteboard.general.string = store.csv()
                        flash("Copied.")
                    }
                    ShareLink(item: store.csv()) {
                        Text("Share")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }

            Card(title: "Start over") {
                dangerBlock(.wipe, opening: "Erase all data",
                            summary: "Erasing removes \(dataSummary). It only exists on this phone, so there is no copy to get it back from.",
                            finalLabel: "Erase everything")
            }
        }
    }

    private var untouched: Bool {
        d.log.isEmpty && d.sessions.isEmpty && store.photoEntries().isEmpty && !d.touched
    }

    private var dataSummary: String {
        let photos = store.photoEntries().count
        return "\(d.log.count) logged day\(d.log.count == 1 ? "" : "s"), "
             + "\(d.sessions.count) session\(d.sessions.count == 1 ? "" : "s"), "
             + "\(photos) photo\(photos == 1 ? "" : "s"), your meal plan and your program"
    }

    /// Three deliberate taps before anything irreversible. A stray tap can
    /// only ever open the first panel.
    @ViewBuilder
    private func dangerBlock(_ kind: DangerKind, opening: String,
                             summary: String, finalLabel: String) -> some View {
        let stage = (danger?.kind == kind) ? (danger?.stage ?? 0) : 0
        if stage == 0 {
            plainButton(opening) { danger = Danger(kind: kind, stage: 1) }
        } else {
            Text(summary)
                .font(.system(size: 12.5))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(T.bad.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            if stage == 1 {
                plainButton("Copy a backup first") {
                    UIPasteboard.general.string = store.backupJSON()
                    store.markBackedUp()
                    flash("Copied.")
                }
                HStack(spacing: 9) {
                    plainButton("Keep my data") { danger = nil; flash("Nothing changed.") }
                    plainButton("Continue") { danger = Danger(kind: kind, stage: 2) }
                }
                Text("Step 1 of 3.").font(.system(size: 12.5)).foregroundStyle(T.mut)
            } else {
                Text("Last check. This cannot be undone.")
                    .font(.system(size: 12.5)).foregroundStyle(T.mut)
                HStack(spacing: 9) {
                    plainButton("Keep my data") { danger = nil; flash("Nothing changed.") }
                    Button {
                        danger = nil
                        switch kind {
                        case .loadDemo:  store.loadDemo();  flash("Demo data loaded.")
                        case .clearDemo: store.clearDemo(); flash("Cleared.")
                        case .wipe:      store.wipe();      flash("Wiped.")
                        }
                    } label: {
                        Text(finalLabel).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.bad.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(T.bad)
                    }
                    .buttonStyle(.plain)
                }
                Text("Step 3 of 3.").font(.system(size: 12.5)).foregroundStyle(T.mut)
            }
        }
    }

    private func plainButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}
