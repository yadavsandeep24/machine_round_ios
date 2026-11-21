import Foundation

/// Every failure the UI can see. The data layer maps URLError / HTTP status /
/// decoding errors into one of these, so views never switch on URLError.
public enum AppError: Error, Equatable, Sendable {
    case noInternet
    case timeout
    case unauthorized
    case notFound
    case server(status: Int)
    case decoding(String)
    case cancelled
    case unknown(String)

    public var userMessage: String {
        switch self {
        case .noInternet: "No internet connection. Check your network and try again."
        case .timeout: "The request timed out. Please try again."
        case .unauthorized: "Your session has expired. Please sign in again."
        case .notFound: "We could not find what you were looking for."
        case .server(let status): "Something went wrong on our side (\(status)). Please try again."
        case .decoding: "We received unexpected data. Please try again later."
        case .cancelled: "The request was cancelled."
        case .unknown: "Something went wrong. Please try again."
        }
    }

    /// Cancellation is a normal outcome (the user left, or typed again), not an error to show.
    public var isCancellation: Bool { self == .cancelled }

    public static func map(_ error: any Error) -> AppError {
        switch error {
        case let e as AppError: return e
        case is CancellationError: return .cancelled
        case let e as URLError:
            switch e.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dataNotAllowed, .internationalRoamingOff:
                return .noInternet
            default: return .unknown(e.localizedDescription)
            }
        case let e as DecodingError: return .decoding(String(describing: e))
        default: return .unknown(String(describing: error))
        }
    }

    public static func fromStatus(_ status: Int) -> AppError? {
        switch status {
        case 200..<300: nil
        case 401, 403: .unauthorized
        case 404: .notFound
        default: .server(status: status)
        }
    }
}
