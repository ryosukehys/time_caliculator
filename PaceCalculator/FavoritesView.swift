import SwiftUI

struct FavoritesView: View {
    @Binding var favorites: [Favorite]
    let onSelect: (Favorite) -> Void
    let onClose: () -> Void

    @State private var renamingID: Favorite.ID?
    @State private var renameText = ""
    @State private var editMode: EditMode = .inactive

    init(favorites: Binding<[Favorite]>, onSelect: @escaping (Favorite) -> Void, onClose: @escaping () -> Void) {
        _favorites = favorites
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "お気に入りはまだありません",
                        systemImage: "star",
                        description: Text("計算結果の「☆ お気に入りに追加」をタップすると、自己ベストや目標タイムをここに保存できます")
                    )
                } else {
                    List {
                        ForEach(favorites) { favorite in
                            Button {
                                onSelect(favorite)
                            } label: {
                                FavoriteRow(favorite: favorite)
                            }
                            // 左スワイプは一覧を閉じる操作に使うので、行の操作は右スワイプにまとめる
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("削除", role: .destructive) {
                                    favorites.removeAll { $0.id == favorite.id }
                                }
                                Button("名前変更") {
                                    renameText = favorite.name
                                    renamingID = favorite.id
                                }
                                .tint(.orange)
                            }
                        }
                        .onDelete(perform: deleteInEditMode)
                        .onMove { favorites.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("お気に入り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !favorites.isEmpty {
                        Button(editMode.isEditing ? "完了" : "編集") {
                            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onClose)
                }
            }
            .alert("名前を変更", isPresented: isRenaming) {
                TextField("名前", text: $renameText)
                Button("保存", action: rename)
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    /// 削除は編集モードのときだけ（通常時に左スワイプで削除が出ると、一覧を閉じるスワイプとぶつかるため）
    private var deleteInEditMode: ((IndexSet) -> Void)? {
        guard editMode.isEditing else { return nil }
        return { favorites.remove(atOffsets: $0) }
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

/// お気に入りの追加・削除をしたときに画面下に出す通知
enum FavoriteToast: Equatable {
    case added(Favorite)
    case removed(Favorite, index: Int)

    var message: String {
        switch self {
        case .added(let favorite): "「\(favorite.name)」をお気に入りに追加しました"
        case .removed(let favorite, _): "「\(favorite.name)」をお気に入りから外しました"
        }
    }

    var actionTitle: String {
        switch self {
        case .added: "名前を付ける"
        case .removed: "元に戻す"
        }
    }

    var systemImage: String {
        switch self {
        case .added: "star.fill"
        case .removed: "star.slash"
        }
    }
}

struct ToastView: View {
    let toast: FavoriteToast
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.systemImage)
                .foregroundStyle(Color.accentColor)
            Text(toast.message)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(toast.actionTitle, action: action)
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
