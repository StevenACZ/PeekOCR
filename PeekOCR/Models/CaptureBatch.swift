import Foundation

struct CaptureBatch {
    static let groupingInterval: TimeInterval = 15

    private(set) var ids: [UUID] = []
    private(set) var lastCaptureAt: Date?
    private(set) var clipboardChangeCount: Int?
    private var consumed = false
    private var captureContinuesBatch = false

    mutating func beginCapture(at date: Date, clipboardChangeCount: Int) {
        captureContinuesBatch = canAppend(at: date, clipboardChangeCount: clipboardChangeCount)
    }

    mutating func append(_ id: UUID, at date: Date, clipboardChangeCount: Int) -> Bool {
        let continues =
            !consumed && ownsClipboard(clipboardChangeCount)
            && (captureContinuesBatch || canAppend(at: date, clipboardChangeCount: clipboardChangeCount))
        if !continues { ids.removeAll() }
        ids.append(id)
        lastCaptureAt = date
        captureContinuesBatch = false
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
        captureContinuesBatch = false
    }

    mutating func endCapture() {
        captureContinuesBatch = false
    }

    func ownsClipboard(_ changeCount: Int) -> Bool {
        clipboardChangeCount == nil || clipboardChangeCount == changeCount
    }

    func canAppend(at date: Date, clipboardChangeCount: Int) -> Bool {
        guard !consumed, !ids.isEmpty, let lastCaptureAt, ownsClipboard(clipboardChangeCount) else { return false }
        return date.timeIntervalSince(lastCaptureAt) <= Self.groupingInterval
    }

    func copiedIDs(grouped: Bool) -> [UUID] {
        grouped ? ids : Array(ids.suffix(1))
    }
}
