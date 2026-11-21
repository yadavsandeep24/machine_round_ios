/// One enum for screen state, instead of `isLoading` + `error` + `items`
/// booleans that can contradict each other. `previous` keeps old data on screen
/// while reloading or after an error.
public enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading(previous: Value?)
    case loaded(Value)
    case failed(AppError, previous: Value?)

    public var value: Value? {
        switch self {
        case .idle: nil
        case .loading(let previous), .failed(_, let previous): previous
        case .loaded(let value): value
        }
    }

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    public var error: AppError? {
        if case .failed(let error, _) = self { error } else { nil }
    }
}

extension Loadable: Equatable where Value: Equatable {}
