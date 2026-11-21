import Core
import SwiftUI

public struct TransactionsView: View {
    @State private var model: TransactionsViewModel

    public init(model: TransactionsViewModel) { _model = State(initialValue: model) }

    public var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Picker("Type", selection: $model.kind) {
                Text("All").tag(Transaction.Kind?.none)
                Text("Received").tag(Transaction.Kind?.some(.credit))
                Text("Paid").tag(Transaction.Kind?.some(.debit))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            content
        }
        .navigationTitle("Transactions")
        .searchable(text: $model.searchText, prompt: "Search name or note")
        .toolbar {
            Menu {
                Picker("Status", selection: $model.status) {
                    Text("Any status").tag(Transaction.Status?.none)
                    Text("Pending").tag(Transaction.Status?.some(.pending))
                    Text("Failed").tag(Transaction.Status?.some(.failed))
                }
            } label: { Label("Status", systemImage: "line.3.horizontal.decrease.circle") }
        }
        .task(id: model.searchText) { await model.debounceSearch() }
        .task(id: model.filter) { await model.reload() }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            LoadingView()
        case .failed(let error):
            ErrorView(message: error.userMessage) { Task { await model.reload() } }
        case .ready:
            if model.items.isEmpty {
                EmptyStateView("No transactions match these filters", systemImage: "line.3.horizontal.decrease")
            } else {
                List {
                    ForEach(model.sections) { section in
                        Section {
                            ForEach(section.items) { TransactionRow(t: $0) }
                        } header: {
                            HStack { Text(section.title); Spacer(); Text(section.netText).monospacedDigit() }
                        }
                    }
                    if model.hasMore {
                        LoadMoreFooter(isLoading: model.isLoadingMore,
                                       errorMessage: model.loadMoreFailed ? "Could not load more." : nil,
                                       retry: { Task { await model.loadMore(isRetry: true) } })
                            .task { await model.loadMore() } // footer appearing = near the end
                    }
                }
                .listStyle(.plain)
                .refreshable { await model.reload() }
            }
        }
    }
}

struct TransactionRow: View {
    let t: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(t.counterparty).font(.body.weight(.semibold))
                Text([t.createdAt.formatted(date: .omitted, time: .shortened), t.note].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(t.signedAmount)
                    .monospacedDigit().bold()
                    .foregroundStyle(t.status == .failed ? Color.secondary : t.kind == .credit ? Color.green : Color.primary)
                    .strikethrough(t.status == .failed)
                if t.status != .success {
                    Text(t.status == .failed ? "Failed" : "Pending").font(.caption2)
                        .foregroundStyle(t.status == .failed ? .red : .orange)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t.kind == .credit ? "Received from" : "Paid to") \(t.counterparty), \(t.signedAmount)\(t.status == .success ? "" : ", \(t.status.rawValue)")")
    }
}
