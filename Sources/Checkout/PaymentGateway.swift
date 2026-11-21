import Core
import Foundation

public struct CreatePaymentRequest: Sendable, Equatable {
    public let orderId: String
    public let amount: Money
    public let method: PaymentMethod
    public init(orderId: String, amount: Money, method: PaymentMethod) {
        self.orderId = orderId
        self.amount = amount
        self.method = method
    }
}

public struct CreatedPayment: Sendable, Equatable {
    public let paymentId: String
    /// UPI intent / 3-D Secure URL the user must approve in, if any.
    public let authorizationURL: String?
    public init(paymentId: String, authorizationURL: String?) {
        self.paymentId = paymentId
        self.authorizationURL = authorizationURL
    }
}

public protocol PaymentGateway: Sendable {
    /// Idempotent: the same key returns the same payment, never a second charge.
    func create(_ request: CreatePaymentRequest, idempotencyKey: String) async throws -> CreatedPayment
    func status(paymentId: String) async throws -> GatewayStatus
}

/// The in-flight payment survives an app kill so it can be re-checked at launch.
public struct PendingPayment: Codable, Sendable, Equatable {
    public let key: String
    public let paymentId: String
}

/// Demo gateway: UPI asks for approval, then succeeds after a few polls.
public actor DemoGateway: PaymentGateway {
    private var byKey: [String: CreatedPayment] = [:]
    private var polls: [String: Int] = [:]
    public init() {}

    public func create(_ request: CreatePaymentRequest, idempotencyKey: String) async throws -> CreatedPayment {
        try await Task.sleep(for: .milliseconds(400))
        if let existing = byKey[idempotencyKey] { return existing }
        let id = "pay_\(byKey.count + 1)"
        let created = CreatedPayment(
            paymentId: id,
            authorizationURL: request.method == .upi ? "upi://pay?pa=merchant@bank&am=\(request.amount.decimal)&tr=\(id)" : nil
        )
        byKey[idempotencyKey] = created
        return created
    }

    public func status(paymentId: String) async throws -> GatewayStatus {
        polls[paymentId, default: 0] += 1
        return polls[paymentId]! >= 3 ? .succeeded : .pending
    }
}
