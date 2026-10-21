import Foundation

struct CaptureBatch {
    private(set) var ids: [UUID] = []
    private(set) var clipboardChangeCount: Int?
    private var consumed = false

    mutating func append(_ id: UUID, clipboardChangeCount: Int) -> Bool {
        let continues = !consumed && !ids.isEmpty && ownsClipboard(clipboardChangeCount)
        if !continues { ids.removeAll() }
        ids.append(id)
        consumed = false
        return continues
    }

    mutating func remove(_ id: UUID) {
        ids.removeAll { $0 == id }
    }

    mutating func didCopy(changeCount: Int) {
        clipboardChangeCount = changeCount
    }

    mutating func didPaste() {
        consumed = true
    }

    func ownsClipboard(_ changeCount: Int) -> Bool {
        clipboardChangeCount == nil || clipboardChangeCount == changeCount
    }

    func copiedIDs(grouped: Bool) -> [UUID] {
        grouped ? ids : Array(ids.suffix(1))
    }
}
