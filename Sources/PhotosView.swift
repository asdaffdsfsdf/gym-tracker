import SwiftUI
import PhotosUI

/// Four progress shots a day, front and back, relaxed and flexed. They live in
/// the app's own container with complete file protection, are excluded from
/// iCloud backup, and never enter the text backup.
struct PhotosView: View {
    @EnvironmentObject var store: Store
    @State private var cursor = DateKey.today()
    @State private var pickingSlot: PhotoSlot? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var confirmDelete: PhotoSlot? = nil
    @State private var filter: PhotoSlot? = nil
    @State private var viewing: Shot? = nil

    struct Shot: Identifiable {
        var date: String
        var slot: PhotoSlot
        var id: String { "\(date)__\(slot.rawValue)" }
    }

    private var entries: [(date: String, slot: PhotoSlot)] { store.photoEntries() }
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
        }
        .background(T.bg)
        .photosPicker(isPresented: Binding(
            get: { pickingSlot != nil },
            set: { if !$0 { pickingSlot = nil } }
        ), selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item, let slot = pickingSlot else { return }
            let date = cursor
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    store.savePhoto(img, for: date, slot: slot)
                }
                pickerItem = nil
                pickingSlot = nil
            }
        }
        .sheet(item: $viewing) { shot in
            PhotoDetail(date: shot.date, slot: shot.slot).environmentObject(store)
        }
    }

    // MARK: Today's four

    private var dayCard: some View {
        let taken = PhotoSlot.allCases.filter { store.hasPhoto(cursor, $0) }.count
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
                    slotCell(slot)
                }
            }

            Text("\(taken) of 4 taken." + (taken > 0 ? " Tap a photo to replace it." : " Tap a slot to add one."))
                .font(.system(size: 12.5)).foregroundStyle(T.mut)
                .frame(maxWidth: .infinity)
        }
    }

    private func slotCell(_ slot: PhotoSlot) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Button { pickingSlot = slot } label: {
                    if let img = store.loadPhoto(cursor, slot) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(T.sunken)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(T.mut)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(T.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                    }
                }
                .buttonStyle(.plain)

                if store.hasPhoto(cursor, slot) {
                    Button {
                        if confirmDelete == slot {
                            store.deletePhoto(cursor, slot); confirmDelete = nil
                        } else { confirmDelete = slot }
                    } label: {
                        Text(confirmDelete == slot ? "delete?" : "✕")
                            .font(.system(size: confirmDelete == slot ? 11 : 12, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(confirmDelete == slot ? T.bad : Color.black.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 6))
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
        Card(title: "All photos", meta: entries.isEmpty ? nil : "\(entries.count)") {
            Picker("", selection: $filter) {
                Text("All").tag(PhotoSlot?.none)
                ForEach(PhotoSlot.allCases) { s in
                    Text(s.short).tag(PhotoSlot?.some(s))
                }
            }
            .pickerStyle(.segmented)

            if entries.isEmpty {
                EmptyNote(text: "Photos you add show up here, newest first.")
            } else if let slot = filter {
                let hits = entries.filter { $0.slot == slot }
                if hits.isEmpty {
                    EmptyNote(text: "No \(slot.label.lowercased()) photos yet.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                        ForEach(hits, id: \.date) { e in
                            thumb(e.date, e.slot, caption: DateKey.dmy(e.date))
                        }
                    }
                    Text("\(hits.count) \(slot.label.lowercased()) photo\(hits.count == 1 ? "" : "s"), newest first.")
                        .font(.system(size: 12.5)).foregroundStyle(T.mut)
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                            ForEach(onDay, id: \.slot) { e in
                                thumb(e.date, e.slot, caption: e.slot.short)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func thumb(_ date: String, _ slot: PhotoSlot, caption: String) -> some View {
        Button { viewing = Shot(date: date, slot: slot) } label: {
            VStack(spacing: 4) {
                if let img = store.loadPhoto(date, slot) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(height: 118)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(caption).font(.system(size: 10.5)).foregroundStyle(T.mut)
            }
        }
        .buttonStyle(.plain)
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

/// One shot full size, with the weight from that morning.
struct PhotoDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var date: String
    var slot: PhotoSlot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let img = store.loadPhoto(date, slot) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        ShareLink(item: store.photoURL(date, slot)) {
                            Text("Share this photo")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(T.sunken, in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                    if let w = store.day(date).weight {
                        Text("\(Fmt.n2(w)) \(store.data.profile.unit) that morning")
                            .font(.system(size: 13)).foregroundStyle(T.mut)
                    }
                }
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle("\(slot.label), \(DateKey.dmy(date))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
