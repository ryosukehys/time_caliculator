import CoreGraphics

/// お気に入りパネルを横スワイプで開閉するときの判定（画面から切り離してテストできるようにする）
enum DrawerSwipe {
    /// 横の動きが縦より十分大きいか。縦スクロールと取り違えないための判定
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 1.5
    }

    /// 右スワイプを離したときに開くか: パネル幅の 3 割以上動かすか、勢いよく払ったとき
    static func shouldOpen(translation: CGFloat, predicted: CGFloat, panelWidth: CGFloat) -> Bool {
        translation > panelWidth * 0.3 || predicted > panelWidth * 0.5
    }

    /// 左スワイプを離したときに閉じるか
    static func shouldClose(translation: CGFloat, predicted: CGFloat, panelWidth: CGFloat) -> Bool {
        -translation > panelWidth * 0.3 || -predicted > panelWidth * 0.5
    }

    /// パネルの開き具合（0 = 閉、1 = 全開）。指の位置に合わせて途中まで出す
    static func progress(isOpen: Bool, dragX: CGFloat, panelWidth: CGFloat) -> CGFloat {
        guard panelWidth > 0 else { return isOpen ? 1 : 0 }
        let raw = isOpen ? 1 + dragX / panelWidth : dragX / panelWidth
        return min(1, max(0, raw))
    }
}
