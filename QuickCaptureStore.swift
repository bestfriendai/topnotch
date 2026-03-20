import AppKit
import Combine
import Foundation

struct CaptureNote: Identifiable, Codable {
    let id: UUID
    var text: String
    let timestamp: Date
    
    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
    }
}

@MainActor
final class QuickCaptureStore: ObservableObject {
    static let shared = QuickCaptureStore()
    
    @Published var notes: [CaptureNote] = []
    @Published var draftText: String = ""
    
    private static let key = "quickCaptureNotes_v1"
    
    private init() {
        load()
    }
    
    func saveNote() {
        let trimmed = draftText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let note = CaptureNote(text: trimmed)
        notes.insert(note, at: 0)
        draftText = ""
        persist()
    }
    
    func deleteNote(_ note: CaptureNote) {
        notes.removeAll { $0.id == note.id }
        persist()
    }
    
    func copyNote(_ note: CaptureNote) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }
    
    func clearAll() {
        notes = []
        persist()
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode([CaptureNote].self, from: data) else { return }
        notes = saved
    }
}
