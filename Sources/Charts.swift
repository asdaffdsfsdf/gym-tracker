import SwiftUI
import Charts

/// Every chart here keeps a fixed-height row above the plot for the readout,
/// so selecting a point never pushes the rest of the screen around, and a
/// selection stays put until you pick another one or tap away.
private let readoutHeight: CGFloat = 19

private struct Readout<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .font(.system(size: 12.5))
            .lineLimit(1)
            .frame(height: readoutHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Horizontal scrolling, but only once there is more history than fits.
    @ViewBuilder
    func scrollingX(days: Int, from first: String?, to last: String?) -> some View {
        if let first, let last, DateKey.diff(first, last) > days,
           let edge = DateKey.date(DateKey.shift(last, -days)) {
            self.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: Double(days) * 86_400)
                .chartScrollPosition(initialX: edge)
        } else {
            self
        }
    }
}

/// Weight over time: every weigh-in as a point, the seven day average as the line.
struct WeightChart: View {
    var points: [Calc.WeighIn]
    var unit: String

    @State private var picked: Date? = nil

    private func domain(_ avg: [Calc.Trend]) -> ClosedRange<Double> {
        let vals = points.map { $0.w } + avg.map { $0.v }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        let pad = max(0.25, (hi - lo) * 0.15)
        if hi - lo < 0.6 { let m = (hi + lo) / 2; return (m - 0.4)...(m + 0.4) }
        return (lo - pad)...(hi + pad)
    }

    private func hit(_ avg: [Calc.Trend]) -> (raw: Calc.WeighIn, avg: Calc.Trend?)? {
        guard let picked else { return nil }
        let key = DateKey.string(picked)
        guard let raw = points.min(by: {
            abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key))
        }) else { return nil }
        return (raw, avg.first { $0.date == raw.date })
    }

    var body: some View {
        // worked out once, rather than once for every mark the chart draws
        let avg = Calc.rolling(points, 7)
        let span = domain(avg)
        let sel = hit(avg)
        return VStack(alignment: .leading, spacing: 8) {
            Readout {
                if let sel {
                    HStack(spacing: 8) {
                        Text(DateKey.dmy(sel.raw.date)).foregroundStyle(T.mut)
                        Text("\(Fmt.n2(sel.raw.w)) \(unit)").fontWeight(.semibold).monospacedDigit()
                        if let a = sel.avg {
                            Text("avg \(Fmt.n2(a.v))").foregroundStyle(T.mut).monospacedDigit()
                        }
                    }
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
            }

            Chart {
                ForEach(avg, id: \.date) { a in
                    if let d = DateKey.date(a.date) {
                        AreaMark(x: .value("Day", d),
                                 yStart: .value("Floor", span.lowerBound),
                                 yEnd: .value("Average", a.v))
                            .foregroundStyle(.linearGradient(
                                colors: [T.accent.opacity(0.22), T.accent.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", d), y: .value("Average", a.v))
                            .foregroundStyle(T.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    }
                }
                ForEach(points, id: \.date) { p in
                    if let d = DateKey.date(p.date) {
                        PointMark(x: .value("Day", d), y: .value("Weight", p.w))
                            .foregroundStyle(T.mut.opacity(0.55))
                            .symbolSize(18)
                    }
                }
                if let sel, let d = DateKey.date(sel.raw.date) {
                    RuleMark(x: .value("Day", d))
                        .foregroundStyle(T.mut.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Day", d), y: .value("Weight", sel.raw.w))
                        .foregroundStyle(T.accent)
                        .symbolSize(90)
                }
            }
            .chartYScale(domain: span)
            .chartXSelection(value: $picked)
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(T.line)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(Fmt.n1(d)).font(.system(size: 9)).foregroundStyle(T.mut)
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
            .chartPlotStyle { $0.clipped() }
            .scrollingX(days: 56, from: points.first?.date, to: points.last?.date)
            .frame(height: 185)
        }
    }
}

/// Daily calories against the target line, for the last fortnight.
struct IntakeChart: View {
    struct Bar: Identifiable { var id: String { date }; var date: String; var kcal: Double }
    var bars: [Bar]
    var target: Double

    @State private var picked: Date? = nil

    private var hit: Bar? {
        guard let picked else { return nil }
        let key = DateKey.string(picked)
        return bars.min { abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key)) }
    }

    private func tint(_ v: Double) -> Color {
        if v <= 0 { return T.line }
        if v > target * 1.12 { return T.warn }
        if v < target * 0.92 { return T.accent.opacity(0.4) }
        return T.accent
    }

    var body: some View {
        let sel = hit
        return VStack(alignment: .leading, spacing: 8) {
            Readout {
                if let sel {
                    HStack(spacing: 8) {
                        Text(DateKey.dmy(sel.date)).foregroundStyle(T.mut)
                        Text(sel.kcal > 0 ? "\(Fmt.r0(sel.kcal)) kcal" : "not logged")
                            .fontWeight(.semibold).monospacedDigit()
                    }
                } else {
                    Text("Tap a bar for that day. The dashed line is your target.")
                        .font(.system(size: 11.5)).foregroundStyle(T.mut)
                }
            }
            Chart {
                ForEach(bars) { b in
                    if let d = DateKey.date(b.date) {
                        BarMark(x: .value("Day", d, unit: .day),
                                y: .value("kcal", max(b.kcal, 0)))
                            .foregroundStyle(tint(b.kcal))
                            .opacity(sel == nil || sel?.date == b.date ? 1 : 0.55)
                    }
                }
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(T.ink2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            .chartXSelection(value: $picked)
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
            .chartPlotStyle { $0.clipped() }
            .frame(height: 135)
        }
    }
}

/// Best set per session for one exercise.
struct StrengthChart: View {
    var points: [Calc.ExPoint]
    var mode: ExMode
    var unit: String

    @State private var picked: Date? = nil

    private var domain: ClosedRange<Double> {
        let vals = points.map { $0.best }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        if hi - lo < 0.001 { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.18
        return (max(0, lo - pad))...(hi + pad)
    }

    private var hit: Calc.ExPoint? {
        guard let picked else { return nil }
        let key = DateKey.string(picked)
        return points.min { abs(DateKey.diff($0.date, key)) < abs(DateKey.diff($1.date, key)) }
    }

    var body: some View {
        let span = domain
        let sel = hit
        return VStack(alignment: .leading, spacing: 8) {
            Readout {
                if let sel {
                    HStack(spacing: 8) {
                        Text(DateKey.dmy(sel.date)).foregroundStyle(T.mut)
                        Text(Fmt.metric(sel.best, mode, unit) + (mode == .weight ? " \(unit)" : ""))
                            .fontWeight(.semibold).monospacedDigit()
                        Text(Calc.setsLabel(sel.sets, mode)).foregroundStyle(T.mut)
                            .lineLimit(1).truncationMode(.tail)
                    }
                } else {
                    Text("Tap a point for the sets you did that day.")
                        .font(.system(size: 11.5)).foregroundStyle(T.mut)
                }
            }
            Chart {
                ForEach(points, id: \.date) { p in
                    if let d = DateKey.date(p.date) {
                        AreaMark(x: .value("Day", d),
                                 yStart: .value("Floor", span.lowerBound),
                                 yEnd: .value("Best", p.best))
                            .foregroundStyle(.linearGradient(
                                colors: [T.accent.opacity(0.18), T.accent.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", d), y: .value("Best", p.best))
                            .foregroundStyle(T.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Day", d), y: .value("Best", p.best))
                            .foregroundStyle(T.accent)
                            .symbolSize(26)
                    }
                }
                if let sel, let d = DateKey.date(sel.date) {
                    RuleMark(x: .value("Day", d))
                        .foregroundStyle(T.mut.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Day", d), y: .value("Best", sel.best))
                        .foregroundStyle(T.accent)
                        .symbolSize(90)
                }
            }
            .chartYScale(domain: span)
            .chartXSelection(value: $picked)
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
            .chartPlotStyle { $0.clipped() }
            .scrollingX(days: 84, from: points.first?.date, to: points.last?.date)
            .frame(height: 175)
        }
    }
}
