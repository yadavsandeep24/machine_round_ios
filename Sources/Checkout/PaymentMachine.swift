/// Explicit payment state machine. The backend is the source of truth; the
/// client reflects what it knows. Key rule: a timeout is UNKNOWN, never
/// FAILED. Showing "failed" for a payment that went through makes users pay twice.
public enum PaymentMethod: String, CaseIterable, Sendable { case upi, card }

public enum PaymentState: Equatable, Sendable {
    case idle
    case initiating(key: String)
    case awaitingAuthorization(key: String, paymentId: String, url: String)
    case processing(key: String, paymentId: String)
    case succeeded(paymentId: String)
    case failed(reason: String)
    case unknown(key: String, paymentId: String)

    public var paymentId: String? {
        switch self {
        case .awaitingAuthorization(_, let id, _), .processing(_, let id), .succeeded(let id), .unknown(_, let id): id
        default: nil
        }
    }
}

public enum PaymentEvent: Sendable {
    case pay(key: String)
    case created(paymentId: String, authorizationURL: String?)
    case createFailed(reason: String)
    case returnedFromAuthorization
    case status(GatewayStatus)
    case timedOut
    case restored(key: String, paymentId: String)
    case reset
}

public enum GatewayStatus: Equatable, Sendable {
    case pending, succeeded, failed(reason: String)
}

public extension PaymentState {
    /// Pure transition function; illegal events leave the state unchanged.
    func reduce(_ event: PaymentEvent) -> PaymentState {
        if case .succeeded = self { return self } // nothing undoes a success
        switch (self, event) {
        case (.idle, .pay(let key)), (.failed, .pay(let key)):
            return .initiating(key: key)
        case (.initiating(let key), .created(let id, let url?)):
            return .awaitingAuthorization(key: key, paymentId: id, url: url)
        case (.initiating(let key), .created(let id, nil)):
            return .processing(key: key, paymentId: id)
        case (.initiating, .createFailed(let reason)):
            return .failed(reason: reason)
        case (.awaitingAuthorization(let key, let id, _), .returnedFromAuthorization):
            return .processing(key: key, paymentId: id)
        case (.awaitingAuthorization(_, let id, _), .status(.succeeded)),
             (.processing(_, let id), .status(.succeeded)),
             (.unknown(_, let id), .status(.succeeded)):
            return .succeeded(paymentId: id)
        case (.awaitingAuthorization, .status(.failed(let reason))),
             (.processing, .status(.failed(let reason))),
             (.unknown, .status(.failed(let reason))):
            return .failed(reason: reason)
        case (.awaitingAuthorization(let key, let id, _), .timedOut), (.processing(let key, let id), .timedOut):
            return .unknown(key: key, paymentId: id)
        case (.idle, .restored(let key, let id)):
            return .processing(key: key, paymentId: id)
        case (.failed, .reset):
            return .idle
        default:
            return self // e.g. a second .pay while initiating (double tap)
        }
    }
}
