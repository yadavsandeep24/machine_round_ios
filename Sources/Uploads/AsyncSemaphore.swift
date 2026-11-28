/// Limits how many tasks run a section at once (for example: at most 2 uploads on mobile data).
///
/// It is an actor, so `release()` is actor-isolated and must be awaited from outside.
/// Before Swift 6.4 that meant you could not call it from `defer`.
public actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(permits: Int) {
        precondition(permits > 0, "permits must be positive")
        self.permits = permits
    }

    public var availablePermits: Int { permits }
    public var waitingCount: Int { waiters.count }

    public func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        // FIFO hand-off: release() resumes the oldest waiter and passes the permit directly.
        await withCheckedContinuation { waiters.append($0) }
    }

    public func release() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
