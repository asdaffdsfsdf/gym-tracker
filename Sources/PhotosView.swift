import SwiftUI
import PhotosUI

/// Four progress shots a day, front and back, relaxed and flexed. They live in
/// the app's own container with complete file protection, are excluded from
/// iCloud backup, and never enter the text backup.
struct PhotosView: View {
    @EnvironmentObject var store: Store
    @State private var cursor = DateKey.today()
    @State private var showPicker = false
    /// Kept apart from the sheet's own state: dismissing the picker clears
    /// whatever drives its presentation, and the chosen image arrives after
    /// that, so the slot it was meant for has to survive the dismissal.
    @State private var target: Shot? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var saving = false
    @State private var confirmDelete: PhotoSlot? = nil
    @State private var filter: PhotoSlot? = nil
    @State private var viewing: Viewer? = nil

    struct Shot: Identifiable, Equatable, Hashable {
        var date: String
        var slot: PhotoSlot
        var id: String { "\(date)__\(slot.rawValue)" }
    }

    /// What the carousel opens with: the run of photos to swipe through, and
    /// which one to start on.
    struct Viewer: Identifiable {
        var id = UUID()
        var shots: [Shot]
        var start: String
    }

    private var entries: [Shot] {
        store.photoEntries().map { Shot(date: $0.date, slot: $0.slot) }
    }
    private var shown: [Shot] {
        guard let filter else { return entries }
        return entries.filter { $0.slot == filter }
    }
    private var isToday: Bool { cursor == DateKey.today() }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                dayCard
                galleryCard
                storageCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .tapToDismissKeyboard()
        }
        .background(T.bg)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item, let shot = target else { return }
            saving = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    store.savePhoto(img, for: shot.date, slot: shot.slot)
                }
                pickerItem = nil
                target = nil
                saving = false
            }
        }
        .sheet(item: $viewing) { v in
            PhotoCarousel(shots: v.shots, start: v.start, replace: { shot in
                // the picker cannot open while the sheet is on its way out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pick(shot) }
            })
            .environmentObject(store)
        }
    }

    private func pick(_ shot: Shot) {
        target = shot
        showPicker = true
    }

    private func open(_ shot: Shot, within list: [Shot]) {
        viewing = Viewer(shots: list, start: shot.id)
    }

    // MARK: Today's four

    private var dayCard: some View {
        let taken = PhotoSlot.allCases.filter { store.hasPhoto(cursor, $0) }
        let todays = taken.map { Shot(date: cursor, slot: $0) }
        return Card {
            HStack {
                Button { cursor = DateKey.shift(cursor, -1); confirmDelete = nil } label: {
                    Image(systemName: "chevron.left").padding(8)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(DateKey.pretty(cursor)).font(.system(size: 16, weight: .semibold))
                    if let w = store.day(cursor).weight {
                        Text("\(Fmt.n2(w)) \(store.data.profile.unit)")
                            .font(.system(size: 12)).foregroundStyle(T.mut).monospacedDigit()
                    } else {
                        Text(cursor).font(.system(size: 12)).foregroundStyle(T.mut).monospacedDigit()
                    }
                }
                Spacer()
                Button { cursor = DateKey.shift(cursor, 1); confirmDelete = nil } label: {
                    Image(systemName: "chevron.right").padding(8)
                }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PhotoSlot.allCases) { slot in
                    slotCell(slot, todays: todays)
                }
            }

            Text(saving ? "Saving that photo..."
                 : "\(taken.count) of 4 taken."
                   + (taken.isEmpty ? " Tap a slot to add one." : " Tap one to open it."))
                .font(.system(size: 12.5)).foregroundStyle(T.mut)
                .frame(maxWidth: .infinity)
        }
    }

    private func slotCell(_ slot: PhotoSlot, todays: [Shot]) -> some View {
        let has = store.hasPhoto(cursor, slot)
        let shot = Shot(date: cursor, slot: slot)
        return VStack(spacing: 5) {
            PhotoFrame(image: has ? store.thumbnail(cursor, slot) : nil)
                .onTapGesture {
                    if has { open(shot, within: todays) } else { pick(shot) }
                }
                .overlay(alignment: .topTrailing) {
                    if has {
                        Button {
                            if confirmDelete == slot {
                                store.deletePhoto(cursor, slot); confirmDelete = nil
                            } else { confirmDelete = slot }
                        } label: {
                            Text(confirmDelete == slot ? "delete?" : "remove")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(confirmDelete == slot ? T.bad : Color.black.opacity(0.55),
                                            in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                }
            Text(slot.label).font(.system(size: 11)).foregroundStyle(T.mut)
        }
    }

    // MARK: Everything, filterable by slot

    private var galleryCard: some View {
        Card(title: "All photos") {
            // plain buttons rather than a Picker inside the menu: a Picker here
            // can be left half presented by a quick double tap and then ignores
            // everything until something else forces a redraw
            Menu {
                Button { filter = nil } label: {
                    if filter == nil { Label("Every shot", systemImage: "checkmark") }
                    else { Text("Every shot") }
                }
                ForEach(PhotoSlot.allCases) { s in
                    Button { filter = s } label: {
                        if filter == s { Label(s.label, systemImage: "checkmark") }
                        else { Text(s.label) }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(filter?.label ?? "Every shot")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(T.accent)
                    Spacer(minLength: 6)
                    Text("\(shown.count) photo\(shown.count == 1 ? "" : "s")")
                        .font(.system(size: 11)).foregroundStyle(T.mut)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)

            if entries.isEmpty {
                EmptyNote(text: "Photos you add show up here, newest first.")
            } else if filter != nil {
                if shown.isEmpty {
                    EmptyNote(text: "None of those yet.")
                } else {
                    grid(shown) { DateKey.dmy($0.date) }
                }
            } else {
                ForEach(store.photoDates(), id: \.self) { date in
                    let onDay = entries.filter { $0.date == date }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(DateKey.dmy(date))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(T.ink2)
                            Spacer()
                            Text("\(onDay.count) of 4")
                                .font(.system(size: 11)).foregroundStyle(T.mut)
                        }
                        grid(onDay) { $0.slot.short }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func grid(_ list: [Shot], caption: @escaping (Shot) -> String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(list) { shot in
                VStack(spacing: 4) {
                    PhotoFrame(image: store.thumbnail(shot.date, shot.slot, max: 300), corner: 7)
                    Text(caption(shot)).font(.system(size: 10.5)).foregroundStyle(T.mut)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { open(shot, within: list) }
            }
        }
    }

    private var storageCard: some View {
        let bytes = store.photoBytes()
        let mb = Double(bytes) / 1_048_576
        return Card(title: "Storage") {
            Text("\(entries.count) photo\(entries.count == 1 ? "" : "s"), "
                 + (mb >= 1 ? "\(Fmt.n1(mb)) MB" : "\(Fmt.r0(Double(bytes) / 1024)) KB")
                 + " on this phone.")
                .font(.system(size: 13)).foregroundStyle(T.mut)
            Text("Photos stay out of the text backup and out of iCloud backups. They never leave this phone unless you share one.")
                .font(.system(size: 12.5)).foregroundStyle(T.mut)
        }
    }
}

/// A photo in a box of a fixed shape. The image fills the box and anything
/// over the edges is cut off there, so a portrait shot can never stretch the
/// card it sits in.
struct PhotoFrame: View {
    var image: UIImage?
    var ratio: CGFloat = 3.0 / 4.0
    var corner: CGFloat = 8

    var body: some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        T.sunken
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(T.mut)
                        RoundedRectangle(cornerRadius: corner)
                            .strokeBorder(T.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .contentShape(RoundedRectangle(cornerRadius: corner))
    }
}

/// Swipe through the run of photos you opened, rather than closing one to
/// reach the next.
struct PhotoCarousel: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var shots: [PhotosView.Shot]
    var start: String
    var replace: (PhotosView.Shot) -> Void

    @State private var current: String

    init(shots: [PhotosView.Shot], start: String,
         replace: @escaping (PhotosView.Shot) -> Void) {
        self.shots = shots
        self.start = start
        self.replace = replace
        _current = State(initialValue: start)
    }

    private var shot: PhotosView.Shot? { shots.first { $0.id == current } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $current) {
                    ForEach(shots) { s in
                        VStack(spacing: 10) {
                            if let img = store.loadPhoto(s.date, s.slot) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                EmptyNote(text: "That photo is no longer here.")
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .tag(s.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: shots.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                if let shot {
                    VStack(spacing: 10) {
                        HStack {
                            Text(shot.slot.label)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(store.day(shot.date).weight.map {
                                "\(Fmt.n2($0)) \(store.data.profile.unit) that morning"
                            } ?? DateKey.pretty(shot.date))
                                .font(.system(size: 12.5)).foregroundStyle(T.mut)
                        }
                        HStack(spacing: 9) {
                            ShareLink(item: store.photoURL(shot.date, shot.slot)) {
                                Text("Share")
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
                            }
                            Button {
                                let s = shot
                                dismiss()
                                replace(s)
                            } label: {
                                Text("Replace")
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .background(T.bg)
            .navigationTitle(shot.map { DateKey.dmy($0.date) } ?? "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
