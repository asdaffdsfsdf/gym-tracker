import SwiftUI
import Charts

/// Weight over time: every weigh-in as a point, the seven day average as the line.
/// Dragging across it gives the reading for that day.
struct WeightChart: View {
    var points: [Calc.WeighIn]
    var unit: String

    @State private var selected: String? = nil

    private var avg: [Calc.Trend] { Calc.rolling(points, 7) }

    private var domain: ClosedRange<Double> {
        let vals = points.map { $0.w } + avg.map { $0.v }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        let pad = max(0.25, (hi - lo) * 0.15)
        if hi - lo < 0.6 { let m = (hi + lo) / 2; return (m - 0.4)...(m + 0.4) }
        return (lo - pad)...(hi + pad)
    }

    private func nearest(_ key: String) -> (raw: Calc.WeighIn, avg: Calc.Trend?)? {
        guard let raw = points.min(by: {
            abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key))
        }) else { return nil }
        let a = avg.first { $0.date == raw.date }
        return (raw, a)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sel = selected, let hit = nearest(sel) {
                HStack(spacing: 8) {
                    Text(DateKey.dmy(hit.raw.date)).foregroundStyle(T.mut)
                    Text("\(Fmt.n2(hit.raw.w)) \(unit)").fontWeight(.semibold).monospacedDigit()
                    if let a = hit.avg {
                        Text("avg \(Fmt.n2(a.v))").foregroundStyle(T.mut).monospacedDigit()
                    }
                }
                .font(.system(size: 12.5))
            } else {
                HStack(spacing: 14) {
                    Label { Text("each weigh-in") } icon: {
                        Circle().fill(T.mut).frame(width: 6, height: 6)
                    }
                    Label { Text("7-day average") } icon: {
                        Capsule().fill(T.accent).frame(width: 14, height: 2.5)
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(T.mut)
            }

            Chart {
                ForEach(points, id: \.date) { p in
                    if let d = DateKey.date(p.date) {
                        PointMark(x: .value("Day", d), y: .value("Weight", p.w))
                            .foregroundStyle(T.mut.opacity(0.55))
                            .symbolSize(18)
                    }
                }
                ForEach(avg, id: \.date) { a in
                    if let d = DateKey.date(a.date) {
                        LineMark(x: .value("Day", d), y: .value("Average", a.v))
                            .foregroundStyle(T.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        AreaMark(x: .value("Day", d), y: .value("Average", a.v))
                            .foregroundStyle(.linearGradient(
                                colors: [T.accent.opacity(0.22), T.accent.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                    }
                }
                if let sel = selected, let hit = nearest(sel), let d = DateKey.date(hit.raw.date) {
                    RuleMark(x: .value("Day", d))
                        .foregroundStyle(T.mut.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Day", d), y: .value("Weight", hit.raw.w))
                        .foregroundStyle(T.accent)
                        .symbolSize(90)
                }
            }
            .chartYScale(domain: domain)
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(T.line)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(Fmt.n2(d)).font(.system(size: 9)).foregroundStyle(T.mut)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisTick().foregroundStyle(T.mut)
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(DateKey.dm(DateKey.string(d)))
                                .font(.system(size: 9)).foregroundStyle(T.mut)
                        }
                    }
                }
            }
            .frame(height: 185)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    guard let plot = proxy.plotFrame else { return }
                                    let x = g.location.x - geo[plot].origin.x
                                    if let d: Date = proxy.value(atX: x) {
                                        selected = DateKey.string(d)
                                    }
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        selected = nil
                                    }
                                }
                        )
                }
            }
        }
    }
}

/// Daily calories against the target line, for the last fortnight.
struct IntakeChart: View {
    struct Bar: Identifiable { var id: String { date }; var date: String; var kcal: Double }
    var bars: [Bar]
    var target: Double

    @State private var selected: String? = nil

    private func tint(_ v: Double) -> Color {
        if v <= 0 { return T.line }
        if v > target * 1.12 { return T.warn }
        if v < target * 0.92 { return T.accent.opacity(0.4) }
        return T.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sel = selected, let hit = bars.first(where: { $0.date == sel }) {
                HStack(spacing: 8) {
                    Text(DateKey.dmy(hit.date)).foregroundStyle(T.mut)
                    Text(hit.kcal > 0 ? "\(Fmt.r0(hit.kcal)) kcal" : "not logged")
                        .fontWeight(.semibold).monospacedDigit()
                }
                .font(.system(size: 12.5))
            }
            Chart {
                ForEach(bars) { b in
                    if let d = DateKey.date(b.date) {
                        BarMark(x: .value("Day", d, unit: .day),
                                y: .value("kcal", max(b.kcal, 0)))
                            .foregroundStyle(tint(b.kcal))
                            .opacity(selected == nil || selected == b.date ? 1 : 0.55)
                    }
                }
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(T.ink2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(DateKey.dm(DateKey.string(d)))
                                .font(.system(size: 9)).foregroundStyle(T.mut)
                        }
                    }
                }
            }
            .frame(height: 135)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    guard let plot = proxy.plotFrame else { return }
                                    let x = g.location.x - geo[plot].origin.x
                                    if let d: Date = proxy.value(atX: x) {
                                        let key = DateKey.string(d)
                                        selected = bars.min {
                                            abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key))
                                        }?.date
                                    }
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        selected = nil
                                    }
                                }
                        )
                }
            }
        }
    }
}

/// Best set per session for one exercise.
struct StrengthChart: View {
    var points: [Calc.ExPoint]
    var mode: ExMode
    var unit: String

    @State private var selected: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sel = selected, let hit = points.first(where: { $0.date == sel }) {
                HStack(spacing: 8) {
                    Text(DateKey.dmy(hit.date)).foregroundStyle(T.mut)
                    Text(Fmt.metric(hit.best, mode, unit) + (mode == .weight ? " \(unit)" : ""))
                        .fontWeight(.semibold).monospacedDigit()
                    Text(Calc.setsLabel(hit.sets, mode)).foregroundStyle(T.mut)
                        .lineLimit(1).truncationMode(.tail)
                }
                .font(.system(size: 12.5))
            }
            Chart {
                ForEach(points, id: \.date) { p in
                    if let d = DateKey.date(p.date) {
                        LineMark(x: .value("Day", d), y: .value("Best", p.best))
                            .foregroundStyle(T.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Day", d), y: .value("Best", p.best))
                            .foregroundStyle(T.accent)
                            .symbolSize(26)
                        AreaMark(x: .value("Day", d), y: .value("Best", p.best))
                            .foregroundStyle(.linearGradient(
                                colors: [T.accent.opacity(0.18), T.accent.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                    }
                }
                if let sel = selected, let hit = points.first(where: { $0.date == sel }),
                   let d = DateKey.date(hit.date) {
                    RuleMark(x: .value("Day", d))
                        .foregroundStyle(T.mut.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(T.line)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(mode == .weight ? Fmt.n1(d) : Fmt.r0(d))
                                .font(.system(size: 9)).foregroundStyle(T.mut)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisTick().foregroundStyle(T.mut)
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(DateKey.dm(DateKey.string(d)))
                                .font(.system(size: 9)).foregroundStyle(T.mut)
                        }
                    }
                }
            }
            .frame(height: 175)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    guard let plot = proxy.plotFrame else { return }
                                    let x = g.location.x - geo[plot].origin.x
                                    if let d: Date = proxy.value(atX: x) {
                                        let key = DateKey.string(d)
                                        selected = points.min {
                                            abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key))
                                        }?.date
                                    }
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        selected = nil
                                    }
                                }
                        )
                }
            }
        }
    }
}
