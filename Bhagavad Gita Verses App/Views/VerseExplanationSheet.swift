import SwiftUI

/// Streams an on-device "why does this apply to me?" explanation for the current verse,
/// with an optional field for the reader's own situation. Backed by `VerseExplainer`
/// (Apple Foundation Models on iOS 26+, graceful stub otherwise).
@MainActor
@Observable
final class VerseExplanationViewModel {
    enum Phase: Equatable {
        case idle
        case streaming
        case done
        case failed(String)
    }

    private(set) var text: String = ""
    private(set) var phase: Phase = .idle
    /// Set when the backend is the graceful fallback (no on-device model here). Generation
    /// still works — the fallback *streams the mapped lesson* — this note only explains the
    /// shorter output. It must never block `generate()` (that was the bug that rendered an
    /// empty sheet on non-AI devices).
    private(set) var fallbackNote: String?

    private let explainer: VerseExplainer
    private let context: VerseSceneContext
    private var task: Task<Void, Never>?

    init(chapter: Int, verse: Int, verseText: String, lesson: String?,
         explainer: VerseExplainer = VerseExplainerFactory.make()) {
        self.explainer = explainer
        self.context = GitaSceneProvider.context(chapter: chapter, verse: verse,
                                                 verseText: verseText, lesson: lesson)
        if case .fallback(let reason) = explainer.availability {
            fallbackNote = reason
        }
    }

    var canGenerate: Bool {
        if case .streaming = phase { return false }
        return true
    }

    func generate(situation: String?) {
        guard canGenerate else { return }
        task?.cancel()
        text = ""
        phase = .streaming
        task = Task { [explainer, context] in
            do {
                for try await snapshot in explainer.explain(context, userSituation: situation) {
                    if Task.isCancelled { return }
                    self.text = snapshot
                }
                self.phase = .done
            } catch is CancellationError {
                // user dismissed / regenerated — leave state as-is
            } catch {
                self.phase = .failed("Couldn't generate an explanation right now.")
            }
        }
    }

    func cancel() { task?.cancel() }
}

struct VerseExplanationSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var model: VerseExplanationViewModel
    @State private var situation: String = ""
    @FocusState private var situationFocused: Bool

    let reference: String

    init(chapter: Int, verse: Int, verseText: String, lesson: String?) {
        self.reference = "\(chapter):\(verse)"
        self._model = State(initialValue: VerseExplanationViewModel(
            chapter: chapter, verse: verse, verseText: verseText, lesson: lesson))
    }

    private var accent: Color { colorScheme == .light ? AppColors.vividPurple : AppColors.lavender }
    private var ink: Color { colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Why this speaks to you", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(reference)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(22)
        .foregroundStyle(ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Fallback backend (no on-device model): the stream is the mapped lesson and is
            // instant — show it immediately rather than making the user tap a button.
            if model.fallbackNote != nil { model.generate(situation: nil) }
        }
        .onDisappear { model.cancel() }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Optional: what's on your mind?", text: $situation, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
                .focused($situationFocused)
                .submitLabel(.go)
                .onSubmit { situationFocused = false; model.generate(situation: situation) }

            Group {
                if model.text.isEmpty && model.phase == .streaming {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Thinking…").foregroundStyle(.secondary)
                    }
                } else if !model.text.isEmpty {
                    ScrollView {
                        Text(model.text)
                            .font(.system(.body, design: .serif))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                } else if case .failed(let msg) = model.phase {
                    Text(msg).foregroundStyle(.secondary)
                } else {
                    Text("Get a short, grounded take on how this verse applies to your day — generated privately on your device.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let note = model.fallbackNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Button {
                situationFocused = false
                model.generate(situation: situation)
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(accent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock)
            .disabled(!model.canGenerate)
            .opacity(model.canGenerate ? 1 : 0.6)
        }
    }

    private var buttonTitle: String {
        switch model.phase {
        case .streaming: return "Generating…"
        case .done, .failed: return "Try again"
        default: return "Explain this for me"
        }
    }
}
