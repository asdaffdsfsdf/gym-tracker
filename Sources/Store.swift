import Foundation
import SwiftUI
import UIKit

/// Everything lives in the app's own container, written with complete file
/// protection so it is unreadable while the phone is locked. Nothing leaves
/// the device: there is no networking anywhere in this app.
@MainActor
final class Store: ObservableObject {
    @Published var data: AppData
    @Published var saveError: String? = nil

    private let fm = FileManager.default
    private var saveWork: DispatchWorkItem?

    // MARK: Locations

    private var root: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GymTracker", isDirectory: true)
        if !fm.fileExists(atPath: base.path) {
            try? fm.createDirectory(at: base, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.complete])
        }
        return base
    }
    private var dataURL: URL { root.appendingPathComponent("data.json") }
    var photosDir: URL {
        var d = root.appendingPathComponent("photos", isDirectory: true)
        if !fm.fileExists(atPath: d.path) {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.complete])
            // keep progress photos out of iCloud backups entirely
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? d.setResourceValues(values)
        }
        return d
    }

    // MARK: Lifecycle

    init() {
        if let bytes = try? Data(contentsOf: dataURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: bytes) {
            data = decoded
        } else {
            data = AppData.seed()
        }
    }

    /// Coalesces rapid edits into one write. Any edit of your own marks the
    /// app as touched, so loading the demo is never treated as harmless.
    func save() {
        if !data.demo { data.touched = true }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in Task { @MainActor in self?.writeNow() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func writeNow() {
        saveWork?.cancel()
        do {
            let enc = JSONEncoder()
            let bytes = try enc.encode(data)
            try bytes.write(to: dataURL, options: [.atomic, .completeFileProtection])
            saveError = nil
        } catch {
            saveError = "Could not save to this device."
        }
    }

    // MARK: Day log

    func day(_ key: String) -> DayLog { data.log[key] ?? DayLog(date: key) }

    func mutateDay(_ key: String, _ change: (inout DayLog) -> Void) {
        var d = data.log[key] ?? DayLog(date: key)
        change(&d)
        d.date = key
        data.log[key] = d
        save()
    }

    func setWeight(_ key: String, _ text: String) {
        let v = Double(text.replacingOccurrences(of: ",", with: "."))
        mutateDay(key) { d in
            if let v, v > 0, v < 700 { d.weight = v } else if text.isEmpty { d.weight = nil }
        }
    }

    func toggleItem(_ key: String, _ itemId: String) {
        mutateDay(key) { d in
            d.logged = true
            if let i = d.missed.firstIndex(of: itemId) { d.missed.remove(at: i) }
            else { d.missed.append(itemId) }
        }
    }

    func ateFullPlan(_ key: String) {
        mutateDay(key) { d in d.logged = true; d.missed = [] }
    }

    func resetDay(_ key: String) {
        mutateDay(key) { d in d.logged = false; d.missed = [] }
    }

    // MARK: Sessions

    func session(on key: String) -> Session? { data.sessions.first { $0.date == key } }

    func sessionIndex(on key: String) -> Int? { data.sessions.firstIndex { $0.date == key } }

    func startSession(day: ProgramDay, on key: String) {
        guard session(on: key) == nil else { return }
        let entries = day.exercises.map { ex -> SessionEntry in
            var w = ""
            if ex.mode == .weight {
                if let last = Calc.history(ex.name, data.sessions).last {
                    w = Fmt.trim(last.bestSet.w.value)
                }
                if let s = Calc.suggestion(ex, before: nil, sessions: data.sessions,
                                           unit: data.profile.unit), let sw = s.weight {
                    w = Fmt.trim(sw)
                }
            }
            let sets = (0..<max(1, ex.sets)).map { _ in SetEntry(w: w) }
            return SessionEntry(name: ex.name, mode: ex.mode,
                                target: SessionTarget(sets: ex.sets, lo: ex.lo, hi: ex.hi),
                                sets: sets)
        }
        data.sessions.insert(Session(date: key, dayId: day.id, dayName: day.name,
                                     locked: false, entries: entries), at: 0)
        save()
    }

    func startBlankSession(name: String, on key: String) {
        guard session(on: key) == nil else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        data.sessions.insert(Session(date: key, dayId: nil,
                                     dayName: title.isEmpty ? "Other" : title,
                                     locked: false, entries: []), at: 0)
        save()
    }

    /// Drops half-filled rows, then locks. An empty session is discarded instead.
    @discardableResult
    func finishSession(on key: String) -> Bool {
        guard let i = sessionIndex(on: key) else { return false }
        for e in data.sessions[i].entries.indices {
            let mode = data.sessions[i].entries[e].mode
            data.sessions[i].entries[e].sets = data.sessions[i].entries[e].sets.filter { $0.filled(mode) }
        }
        if data.sessions[i].entries.allSatisfy({ $0.sets.isEmpty }) {
            data.sessions.remove(at: i)
            save()
            return false
        }
        data.sessions[i].locked = true
        save()
        return true
    }

    func unlockSession(on key: String) {
        guard let i = sessionIndex(on: key) else { return }
        data.sessions[i].locked = false
        save()
    }

    func addSetRow(on key: String, entry: Int) {
        guard let i = sessionIndex(on: key), data.sessions[i].entries.indices.contains(entry) else { return }
        let prev = data.sessions[i].entries[entry].sets.last
        data.sessions[i].entries[entry].sets.append(SetEntry(w: prev?.w.text ?? ""))
        save()
    }

    func removeEntry(on key: String, entry: Int) {
        guard let i = sessionIndex(on: key), data.sessions[i].entries.indices.contains(entry) else { return }
        data.sessions[i].entries.remove(at: entry)
        save()
    }

    func addEntry(on key: String, name: String, mode: ExMode) {
        guard let i = sessionIndex(on: key) else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        data.sessions[i].entries.append(SessionEntry(name: n, mode: mode, sets: [SetEntry()]))
        save()
    }

    /// Setup cues follow the exercise, read live from the program.
    func cue(for name: String) -> String {
        for d in data.program.days {
            for ex in d.exercises where ex.name == name && !ex.note.isEmpty { return ex.note }
        }
        return ""
    }

    func trainingDay(on key: String) -> ProgramDay? {
        data.program.day(forWeekdayIndex: DateKey.weekdayIndex(key))
    }

    // MARK: Photos

    func photoURL(_ date: String, _ slot: PhotoSlot) -> URL {
        photosDir.appendingPathComponent("\(date)__\(slot.rawValue).jpg")
    }

    func hasPhoto(_ date: String, _ slot: PhotoSlot) -> Bool {
        fm.fileExists(atPath: photoURL(date, slot).path)
    }

    /// Every stored shot as a date and slot pair, newest first.
    func photoEntries() -> [(date: String, slot: PhotoSlot)] {
        migrateLegacyPhotos()
        let names = (try? fm.contentsOfDirectory(atPath: photosDir.path)) ?? []
        return names.filter { $0.hasSuffix(".jpg") }
            .compactMap { name -> (String, PhotoSlot)? in
                let stem = String(name.dropLast(4))
                let parts = stem.components(separatedBy: "__")
                guard parts.count == 2, let slot = PhotoSlot(rawValue: parts[1]) else { return nil }
                return (parts[0], slot)
            }
            .sorted { a, b in
                if a.0 != b.0 { return DateKey.diff(b.0, a.0) > 0 }
                return (PhotoSlot.allCases.firstIndex(of: a.1) ?? 0)
                     < (PhotoSlot.allCases.firstIndex(of: b.1) ?? 0)
            }
            .map { (date: $0.0, slot: $0.1) }
    }

    func photoDates() -> [String] {
        var seen: [String] = []
        for e in photoEntries() where !seen.contains(e.date) { seen.append(e.date) }
        return seen
    }

    /// Shots taken before slots existed were one a day; they become the front shot.
    private func migrateLegacyPhotos() {
        let names = (try? fm.contentsOfDirectory(atPath: photosDir.path)) ?? []
        for name in names where name.hasSuffix(".jpg") && !name.contains("__") {
            let date = String(name.dropLast(4))
            let from = photosDir.appendingPathComponent(name)
            let to = photoURL(date, .front)
            if !fm.fileExists(atPath: to.path) { try? fm.moveItem(at: from, to: to) }
        }
    }

    func loadPhoto(_ date: String, _ slot: PhotoSlot) -> UIImage? {
        guard let d = try? Data(contentsOf: photoURL(date, slot)) else { return nil }
        return UIImage(data: d)
    }

    /// Downscaled and recompressed before it ever touches disk.
    func savePhoto(_ image: UIImage, for date: String, slot: PhotoSlot) {
        let maxEdge: CGFloat = 1400
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let shrunk = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        guard let jpeg = shrunk.jpegData(compressionQuality: 0.8) else { return }
        try? jpeg.write(to: photoURL(date, slot), options: [.atomic, .completeFileProtection])
        objectWillChange.send()
    }

    func deletePhoto(_ date: String, _ slot: PhotoSlot) {
        try? fm.removeItem(at: photoURL(date, slot))
        objectWillChange.send()
    }

    func photoBytes() -> Int64 {
        let names = (try? fm.contentsOfDirectory(atPath: photosDir.path)) ?? []
        return names.reduce(Int64(0)) { acc, n in
            let p = photosDir.appendingPathComponent(n).path
            let attrs = try? fm.attributesOfItem(atPath: p)
            return acc + ((attrs?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    // MARK: Backup

    func backupJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = []
        guard let d = try? enc.encode(data), let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }

    enum ImportResult { case ok(Bool), bad }

    /// Accepts a backup from this app or from the web version, old versions included.
    func importBackup(_ text: String) -> ImportResult {
        guard let bytes = text.data(using: .utf8) else { return .bad }
        guard let obj = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              obj["profile"] != nil else { return .bad }
        guard let decoded = try? JSONDecoder().decode(AppData.self, from: bytes) else { return .bad }
        let wasOlder = (obj["v"] as? Int ?? 1) < SCHEMA
        data = decoded
        writeNow()
        return .ok(wasOlder)
    }

    func markBackedUp() {
        data.lastBackup = DateKey.today()
        save()
    }

    func csv() -> String {
        var out: [String] = ["DAYS", "date,weight,logged,kcal,protein,carbs,fat,missed"]
        for key in data.log.keys.sorted() {
            let d = data.log[key]!
            let t = Calc.dayTotals(d, data.meals, data.foods)
            let names = d.missed.compactMap { id -> String? in
                for m in data.meals { for it in m.items where it.id == id {
                    return data.foods.first { $0.id == it.foodId }?.name ?? id } }
                return nil
            }.joined(separator: "; ")
            out.append([key,
                        d.weight.map { Fmt.n2($0) } ?? "",
                        d.logged ? "yes" : "no",
                        d.logged ? Fmt.r0(t.kcal) : "",
                        d.logged ? Fmt.r0(t.p) : "",
                        d.logged ? Fmt.r0(t.c) : "",
                        d.logged ? Fmt.r0(t.f) : "",
                        "\"\(names.replacingOccurrences(of: "\"", with: "\"\""))\""]
                        .joined(separator: ","))
        }
        out.append("")
        out.append("SESSIONS")
        out.append("date,workout,exercise,sets")
        for s in data.sessions.sorted(by: { DateKey.diff($1.date, $0.date) > 0 }) {
            for en in s.entries {
                let done = en.doneSets
                guard !done.isEmpty else { continue }
                let q: (String) -> String = { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                out.append([s.date, q(s.dayName), q(en.name),
                            q(Calc.setsLabel(done, en.mode))].joined(separator: ","))
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: Reset

    func wipe() {
        for e in photoEntries() { deletePhoto(e.date, e.slot) }
        data = AppData.seed()
        writeNow()
    }

    func loadDemo() {
        data = Demo.build()
        writeNow()
    }

    func clearDemo() {
        data = AppData.seed()
        writeNow()
    }
}
