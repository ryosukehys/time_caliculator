import SwiftUI

struct FavoritesView: View {
    @Binding var favorites: [Favorite]
    let onSelect: (Favorite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var renamingID: Favorite.ID?
    @State private var renameText = ""

    init(favorites: Binding<[Favorite]>, onSelect: @escaping (Favorite) -> Void) {
        _favorites = favorites
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "お気に入りはまだありません",
                        systemImage: "star",
                        description: Text("計算結果の「お気に入りに保存」から、自己ベストや目標タイムを保存できます")
                    )
                } else {
                    List {
                        ForEach(favorites) { favorite in
                            Button {
                                onSelect(favorite)
                                dismiss()
                            } label: {
                                FavoriteRow(favorite: favorite)
                            }
                            .swipeActions(edge: .leading) {
                                Button("名前変更") {
                                    renameText = favorite.name
                                    renamingID = favorite.id
                                }
                                .tint(.orange)
                            }
                        }
                        .onDelete { favorites.remove(atOffsets: $0) }
                        .onMove { favorites.move(fromOffsets: $0, toOffset: $1) }
                    }
                }
            }
            .navigationTitle("お気に入り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !favorites.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("名前を変更", isPresented: isRenaming) {
                TextField("名前", text: $renameText)
                Button("保存", action: rename)
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private func rename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = renamingID, !name.isEmpty,
              let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].name = name
    }
}

struct FavoriteRow: View {
    let favorite: Favorite

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(favorite.input.summary)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let resultText = favorite.input.resultText {
                Text(resultText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
