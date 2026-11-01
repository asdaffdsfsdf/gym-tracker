import SwiftUI

struct FoodView: View {
    @EnvironmentObject var store: Store
    @State private var cursor = DateKey.today()
    @State private var showExtra = false
    @State private var xName = ""
    @State private var xKcal = ""
    @State private var xP = ""
    @State private var xC = ""
    @State private var xF = ""

    private var d: AppData { store.data }
    private var day: DayLog { store.day(cursor) }
    private var isToday: Bool { cursor == DateKey.today() }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headerCard
                ForEach(d.meals) { meal in
                    mealCard(meal)
                }
                extrasCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .tapToDismissKeyboard()
        }
        .background(T.bg)
        .scrollDismissesKeyboard(.interactively)
    }

    private var summaryLine: String {
        var bits: [String] = []
        if !day.missed.isEmpty {
            bits.append("\(day.missed.count) crossed off")
        }
        if !day.qty.isEmpty {
            bits.append("\(day.qty.count) portion\(day.qty.count == 1 ? "" : "s") changed")
        }
        return bits.isEmpty ? "Full plan eaten." : bits.joined(separator: ", ") + "."
    }

    private var headerCard: some View {
        let t = Calc.dayTotals(day, d.meals, d.foods)
        return Card {
            HStack {
                Button { cursor = DateKey.shift(cursor, -1) } label: {
                    Image(systemName: "chevron.left").padding(8)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(DateKey.pretty(cursor)).font(.system(size: 16, weight: .semibold))
                    Text(cursor).font(.system(size: 12)).foregroundStyle(T.mut).monospacedDigit()
                }
                Spacer()
                Button { cursor = DateKey.shift(cursor, 1) } label: {
                    Image(systemName: "chevron.right").padding(8)
                }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
            }

            MacroBar(label: "Calories", have: t.kcal, target: d.profile.kcal)
            MacroBar(label: "Protein", have: t.p, target: d.profile.p, unit: "g")
            MacroBar(label: "Carbs", have: t.c, target: d.profile.c, unit: "g")
            MacroBar(label: "Fat", have: t.f, target: d.profile.f, unit: "g")

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("MORNING WEIGHT")
                    .font(.system(size: 10, weight: .semibold)).kerning(0.6)
                    .foregroundStyle(T.mut)
                NumberInput(placeholder: "--.--",
                            value: store.day(cursor).weight,
                            format: { Fmt.n2($0) },
                            align: .leading) { v in
                    store.setWeight(cursor, v)
                }
            }

            if !day.logged {
                Button { store.ateFullPlan(cursor) } label: {
                    Text("Ate the full plan").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Text("Or cross off what you missed.")
                    .font(.system(size: 12.5)).foregroundStyle(T.mut)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Text(summaryLine)
                        .font(.system(size: 12.5)).foregroundStyle(T.mut)
                    Spacer()
                    Button("Reset day") { store.resetDay(cursor) }
                        .font(.system(size: 12.5))
                }
            }
        }
    }

    private func mealCard(_ meal: Meal) -> some View {
        let missed = Set(day.missed)
        let total = meal.items.reduce(Calc.Macros()) {
            $0 + Calc.itemMacros($1, d.foods, qty: Calc.qty($1, day)) }
        let eaten = meal.items.filter { !missed.contains($0.id) }
            .reduce(Calc.Macros()) {
                $0 + Calc.itemMacros($1, d.foods, qty: Calc.qty($1, day)) }
        return Card {
            HStack {
                Text(meal.name).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Fmt.r0(eaten.kcal)) / \(Fmt.r0(total.kcal)) kcal")
                    .font(.system(size: 12)).foregroundStyle(T.mut).monospacedDigit()
            }
            if meal.items.isEmpty {
                Text("Nothing in this meal yet.")
                    .font(.system(size: 13)).foregroundStyle(T.mut)
            }
            ForEach(meal.items) { item in
                itemRow(item, off: missed.contains(item.id))
            }
        }
    }

    /// Tick or cross the item on the left, change today's portion on the right.
    /// Clearing the box puts the plan's own amount back.
    private func itemRow(_ item: MealItem, off: Bool) -> some View {
        let food = d.foods.first { $0.id == item.foodId }
        let amount = Calc.qty(item, day)
        let m = Calc.itemMacros(item, d.foods, qty: amount)
        let changed = day.qty[item.id] != nil
        let suffix = food?.qtySuffix ?? ""
        return HStack(spacing: 10) {
            Button {
                store.toggleItem(cursor, item.id)
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(off ? T.line : T.accent, lineWidth: 1.5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(off ? .clear : T.accent))
                            .frame(width: 22, height: 22)
                        Image(systemName: off ? "xmark" : "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(off ? T.bad : .white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food?.name ?? "(removed food)")
                            .font(.system(size: 14, weight: .medium))
                            .strikethrough(off)
                            .foregroundStyle(off ? T.mut : T.ink)
                            .lineLimit(2)
                        Text("\(Fmt.r0(m.kcal)) kcal · \(Fmt.r0(m.p))P · \(Fmt.r0(m.c))C · \(Fmt.r0(m.f))F"
                             + (changed ? "  ·  plan \(Fmt.trim(item.qty))\(suffix)" : ""))
                            .font(.system(size: 11)).foregroundStyle(changed ? T.accent : T.mut)
                            .monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 3) {
                NumberInput(value: amount, format: { Fmt.trim($0) }, width: 48) { v in
                    store.setQty(cursor, item.id, v)
                }
                Text(suffix)
                    .font(.system(size: 11)).foregroundStyle(T.mut)
                    .frame(width: 11, alignment: .leading)
            }
            .opacity(off ? 0.4 : 1)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
    }

    private var extrasCard: some View {
        Card(title: "Off plan") {
            if day.extras.isEmpty && !showExtra {
                EmptyNote(text: "Anything you ate that is not in the plan goes here.")
            }
            ForEach(Array(day.extras.enumerated()), id: \.element.id) { idx, x in
                HStack {
                    Text(x.name).font(.system(size: 14))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Fmt.r0(x.kcal)) kcal")
                        Text("\(Fmt.r0(x.p))P · \(Fmt.r0(x.c))C · \(Fmt.r0(x.f))F")
                    }
                    .font(.system(size: 11)).foregroundStyle(T.mut).monospacedDigit()
                    Button {
                        store.mutateDay(cursor) { dd in
                            if dd.extras.indices.contains(idx) { dd.extras.remove(at: idx) }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(T.mut)
                    }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 0.5) }
            }

            if showExtra {
                VStack(spacing: 9) {
                    TextField("What was it", text: $xName)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .padding(10).background(T.sunken, in: RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 9) {
                        NumField(placeholder: "kcal", text: $xKcal)
                        NumField(placeholder: "protein", text: $xP)
                    }
                    HStack(spacing: 9) {
                        NumField(placeholder: "carbs", text: $xC)
                        NumField(placeholder: "fat", text: $xF)
                    }
                    Button {
                        let num: (String) -> Double = {
                            Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0
                        }
                        let k = num(xKcal)
                        guard k > 0 else { return }
                        store.mutateDay(cursor) { dd in
                            dd.logged = true
                            dd.extras.append(Extra(name: xName.isEmpty ? "Extra" : xName,
                                                   kcal: k, p: num(xP),
                                                   c: num(xC), f: num(xF)))
                        }
                        xName = ""; xKcal = ""; xP = ""; xC = ""; xF = ""
                        showExtra = false
                    } label: {
                        Text("Add it").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button { showExtra = true } label: {
                    Text("Add something off plan")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(T.sunken, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
