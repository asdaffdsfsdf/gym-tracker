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
    /// One pending deletion at a time, held by id so a stray tap never removes
    /// anything on its own.
    @State private var armed: String? = nil
    @State private var showAllFoods = false
    @State private var removingFood = false
    @State private var exportJSON = ""
    @State private var exportCSV = ""

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
            .tapToDismissKeyboard()
        }
        .background(T.bg)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
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

    private func arm(_ id: String, _ label: String) {
        armed = id
        flash("Tap again to remove \(label).")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if armed == id { armed = nil }
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
                    numBox("Calories", value: d.profile.kcal, format: { Fmt.r0($0) }) {
                        store.data.profile.kcal = $0 ?? 0; store.save()
                    }
                    numBox("Protein", value: d.profile.p, format: { Fmt.r0($0) }) {
                        store.data.profile.p = $0 ?? 0; store.save()
                    }
                }
                HStack(spacing: 10) {
                    numBox("Carbs", value: d.profile.c, format: { Fmt.r0($0) }) {
                        store.data.profile.c = $0 ?? 0; store.save()
                    }
                    numBox("Fat", value: d.profile.f, format: { Fmt.r0($0) }) {
                        store.data.profile.f = $0 ?? 0; store.save()
                    }
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
                    numBox("Starting weight", value: d.profile.startWeight,
                           format: { Fmt.n2($0) }) {
                        store.data.profile.startWeight = $0; store.save()
                    }
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
                    numBox("Slowest ok gain/wk", value: d.profile.rateLow,
                           format: { Fmt.n2($0) }) {
                        store.data.profile.rateLow = $0 ?? 0.2; store.save()
                    }
                    numBox("Fastest ok gain/wk", value: d.profile.rateHigh,
                           format: { Fmt.n2($0) }) {
                        store.data.profile.rateHigh = $0 ?? 0.4; store.save()
                    }
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
                numBox("Weight (\(unit))", value: d.profile.calcBw, format: { Fmt.n2($0) }) {
                    store.data.profile.calcBw = $0; store.save()
                }
                numBox("Height (cm)", value: d.profile.height, format: { Fmt.r0($0) }) {
                    store.data.profile.height = $0; store.save()
                }
            }
            HStack(spacing: 10) {
                numBox("Age", value: d.profile.age.map { Double($0) },
                       format: { String(Int($0)) }, keyboard: .numberPad) {
                    store.data.profile.age = $0.map { Int($0) }; store.save()
                }
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

            let bw = d.profile.calcBw ?? store.trend?.v ?? 0
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

    private func numBox(_ label: String, value: Double?,
                        format: @escaping (Double) -> String = { Fmt.trim($0) },
                        keyboard: UIKeyboardType = .decimalPad,
                        commit: @escaping (Double?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).kerning(0.6)
                .foregroundStyle(T.mut).lineLimit(1).minimumScaleFactor(0.8)
            NumberInput(value: value, format: format, keyboard: keyboard,
                        align: .leading, commit: commit)
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
                NameInput(placeholder: "Meal", stored: meal.name, size: 15,
                          weight: .semibold, caps: .words) { nv in
                    if let i = store.data.meals.firstIndex(where: { $0.id == meal.id }) {
                        store.data.meals[i].name = nv; store.save()
                    }
                }
                Spacer()
                Text("\(Fmt.r0(totals.kcal)) kcal · \(Fmt.r0(totals.p))P · \(Fmt.r0(totals.c))C · \(Fmt.r0(totals.f))F")
                    .font(.system(size: 11)).foregroundStyle(T.mut).monospacedDigit()
            }

            ForEach(meal.items) { item in
                let food = d.foods.first { $0.id == item.foodId }
                let m = Calc.itemMacros(item, d.foods)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food?.name ?? "(removed food)")
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(2)
                        Text("\(Fmt.r0(m.kcal)) kcal · \(Fmt.r0(m.p))P · \(Fmt.r0(m.c))C · \(Fmt.r0(m.f))F")
                            .font(.system(size: 11)).foregroundStyle(T.mut).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 3) {
                        NumberInput(value: item.qty, width: 50) { nv in
                            if let mi = store.data.meals.firstIndex(where: { $0.id == meal.id }),
                               let ii = store.data.meals[mi].items.firstIndex(where: { $0.id == item.id }) {
                                store.data.meals[mi].items[ii].qty = nv ?? 0
                                store.save()
                            }
                        }
                        Text(food?.qtySuffix ?? "")
                            .font(.system(size: 11)).foregroundStyle(T.mut)
                            .frame(width: 11, alignment: .leading)
                    }
                    Button {
                        let name = food?.name ?? "this item"
                        if armed == item.id {
                            armed = nil
                            if let mi = store.data.meals.firstIndex(where: { $0.id == meal.id }) {
                                store.data.meals[mi].items.removeAll { $0.id == item.id }
                                store.save()
                                flash("Removed \(name).")
                            }
                        } else {
                            arm(item.id, name)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(armed == item.id ? T.bad : T.mut)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
            }

            HStack {
                Button(addingTo == meal.id ? "Close" : "Add food") {
                    addingTo = addingTo == meal.id ? nil : meal.id
                    pickerSearch = ""
                }
                .font(.system(size: 13))
                Spacer()
                Button(armed == meal.id ? "Tap again to remove" : "Remove meal") {
                    if armed == meal.id {
                        armed = nil
                        store.data.meals.removeAll { $0.id == meal.id }
                        store.save()
                        flash("Removed \(meal.name).")
                    } else {
                        arm(meal.id, meal.name.isEmpty ? "this meal" : meal.name)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(armed == meal.id ? T.bad : T.mut)
            }

            if addingTo == meal.id {
                Divider()
                TextField("Search your foods", text: $pickerSearch)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
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

    private var matchingFoods: [Food] {
        d.foods.filter {
            foodSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(foodSearch)
        }
    }

    /// The whole library in one scrolling page was a scroll view inside a
    /// scroll view, which fights the gesture on a phone.
    private var shownFoods: [Food] {
        let hits = matchingFoods
        return showAllFoods ? hits : Array(hits.prefix(12))
    }

    private var foodLibrary: some View {
        let hits = matchingFoods
        return Card(title: "Your foods") {
            Text("Macros per 100g, or per item for countable things. These drive every total.")
                .font(.system(size: 12.5)).foregroundStyle(T.mut)
            TextField("Search", text: $foodSearch)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(9).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))

            if removingFood {
                ForEach(shownFoods) { f in
                    HStack {
                        Text(f.name).font(.system(size: 14))
                        Spacer(minLength: 8)
                        Button(armed == f.id ? "Tap again to remove" : "Remove") {
                            if armed == f.id {
                                armed = nil
                                store.data.foods.removeAll { $0.id == f.id }
                                store.save()
                                flash("Removed \(f.name).")
                            } else {
                                arm(f.id, f.name)
                            }
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(T.bad)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
                }
            } else {
                // a Grid so the column headings cannot drift out of line with
                // the numbers underneath them, whatever the names are
                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        Text("FOOD")
                            .gridColumnAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("KCAL")
                        Text("P")
                        Text("C")
                        Text("F")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(T.mut)
                    .padding(.bottom, 7)

                    ForEach(shownFoods) { f in
                        Divider().gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text(f.name)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Fmt.r0(f.kcal))
                            Text(Fmt.trim(f.p))
                            Text(Fmt.trim(f.c))
                            Text(Fmt.trim(f.f))
                        }
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .padding(.vertical, 9)
                    }
                }
            }

            if hits.count > 12 {
                Button {
                    showAllFoods.toggle()
                } label: {
                    Text(showAllFoods ? "Show fewer" : "Show all \(hits.count) foods")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 9) {
                plainButton(showNewFood ? "Cancel" : "Add a food") {
                    showNewFood.toggle()
                    if showNewFood { removingFood = false }
                }
                plainButton(removingFood ? "Done removing" : "Remove a food") {
                    removingFood.toggle()
                    armed = nil
                    if removingFood { showNewFood = false }
                }
            }

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
            Card(title: "Weekly split") {
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
                NameInput(placeholder: "Day", stored: pd.name, size: 15,
                          weight: .semibold, caps: .words) { nv in
                    if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }) {
                        store.data.program.days[i].name = nv; store.save()
                    }
                }
                Spacer()
                Text("\(pd.exercises.count) exercises")
                    .font(.system(size: 11)).foregroundStyle(T.mut)
            }

            ForEach(pd.exercises) { ex in
                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        NameInput(placeholder: "Exercise", stored: ex.name, caps: .words) { nv in
                            setEx(pd.id, ex.id) { $0.name = nv }
                        }
                        .padding(8).background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
                        Button {
                            if armed == ex.id {
                                armed = nil
                                if let i = store.data.program.days.firstIndex(where: { $0.id == pd.id }) {
                                    store.data.program.days[i].exercises.removeAll { $0.id == ex.id }
                                    store.save()
                                    flash("Removed \(ex.name).")
                                }
                            } else {
                                arm(ex.id, ex.name)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(armed == ex.id ? T.bad : T.mut)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 7) {
                        Picker("", selection: Binding(
                            get: { ex.mode },
                            set: { nv in
                                setEx(pd.id, ex.id) { e in
                                    e.mode = nv
                                    // a rep range and a hold target are different numbers
                                    if nv == .time {
                                        e.lo = 60; e.hi = 60
                                    } else if e.lo == e.hi {
                                        e.lo = 8; e.hi = 12
                                    }
                                }
                            })) {
                            ForEach(ExMode.allCases) { m in Text(m.label).tag(m) }
                        }
                        .pickerStyle(.menu).tint(T.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        intBox(ex.sets, width: 40) { v in setEx(pd.id, ex.id) { $0.sets = v } }
                        if ex.mode == .time {
                            intBox(ex.hi, width: 64) { v in
                                setEx(pd.id, ex.id) { $0.lo = v; $0.hi = v }
                            }
                        } else {
                            intBox(ex.lo, width: 46) { v in setEx(pd.id, ex.id) { $0.lo = v } }
                            intBox(ex.hi, width: 46) { v in setEx(pd.id, ex.id) { $0.hi = v } }
                        }
                    }
                    NameInput(placeholder: "Notes", stored: ex.note, size: 13) { nv in
                        setEx(pd.id, ex.id) { $0.note = nv }
                    }
                    .padding(8).background(T.sunken, in: RoundedRectangle(cornerRadius: 7))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
            }

            HStack {
                let allTime = !pd.exercises.isEmpty && pd.exercises.allSatisfy { $0.mode == .time }
                let anyTime = pd.exercises.contains { $0.mode == .time }
                Text("Type · sets · " + (allTime ? "hold in seconds"
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

    private func setEx(_ dayId: String, _ exId: String,
                       _ change: (inout ProgramExercise) -> Void) {
        guard let i = store.data.program.days.firstIndex(where: { $0.id == dayId }),
              let j = store.data.program.days[i].exercises.firstIndex(where: { $0.id == exId })
        else { return }
        change(&store.data.program.days[i].exercises[j])
        store.save()
    }

    /// Clearing the box leaves the stored number alone until you type a new
    /// one, so a field can be emptied and retyped.
    private func intBox(_ value: Int, width: CGFloat,
                        commit: @escaping (Int) -> Void) -> some View {
        NumberInput(value: Double(value), format: { String(Int($0)) },
                    keyboard: .numberPad, width: width) { v in
            if let v { commit(Int(v)) }
        }
    }

    // MARK: Data

    /// Built once per change rather than on every redraw: serialising the
    /// whole log to share it was happening on each character typed on this tab.
    private func refreshExports() {
        exportJSON = store.backupJSON()
        exportCSV = store.csv()
    }

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
                        flash("Backup copied to the clipboard.")
                    } label: {
                        Text("Copy backup").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.accent, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    ShareLink(item: exportJSON) {
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
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                        flash("CSV copied to the clipboard.")
                    }
                    ShareLink(item: exportCSV) {
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
        .onAppear { refreshExports() }
        .onChange(of: store.revision) { _, _ in refreshExports() }
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
