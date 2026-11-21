import SwiftUI

public struct ChallengesView: View {
    public init() {}

    public var body: some View {
        List(challenges) { c in
            NavigationLink {
                ChallengeDetailView(challenge: c)
            } label: {
                HStack(alignment: .top) {
                    Text("\(c.id)").bold().foregroundStyle(.tint).frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(c.title).font(.headline)
                        Text(c.symptom).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Text(c.kind.rawValue).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(c.kind == .bug ? Color.red.opacity(0.12) : Color.green.opacity(0.12), in: Capsule())
                }
            }
        }
        .navigationTitle("Bugs & optimisation: top 10")
    }
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @State private var showAnswer = false
    @State private var result: (buggy: String, fixed: String)?
    @State private var running = false

    var body: some View {
        Form {
            Section("Symptom") { Text(challenge.symptom) }
            Section {
                Button(running ? "Running…" : "Run buggy vs fixed") {
                    running = true
                    Task {
                        result = await challenge.demo()
                        running = false
                    }
                }
                .disabled(running)
                if let result {
                    LabeledContent("Buggy", value: result.buggy)
                    LabeledContent("Fixed", value: result.fixed)
                }
            }
            Section {
                Toggle("Show answer", isOn: $showAnswer)
                if showAnswer {
                    LabeledContent("Root cause") { Text(challenge.cause) }
                    LabeledContent("Fix") { Text(challenge.fix) }
                    LabeledContent("Code", value: "Sources/Challenges/\(challenge.file)")
                }
            }
        }
        .navigationTitle("\(challenge.id). \(challenge.title)")
    }
}
