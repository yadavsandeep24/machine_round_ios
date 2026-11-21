import Core
import SwiftUI

/// Auth flow: the root swaps on session status, so signing out (or an expired
/// refresh token) replaces the whole tree and back can't reach a protected screen.
public struct AuthRootView: View {
    @State private var session: SessionModel

    public init(session: SessionModel) { _session = State(initialValue: session) }

    public var body: some View {
        Group {
            switch session.status {
            case .restoring: LoadingView()
            case .signedOut: LoginView()
            case .signedIn: NavigationStack { ProfileView() }
            }
        }
        .environment(session)
        .task { session.restore() }
        .task { await session.observeExpiry() }
    }
}

struct LoginView: View {
    @Environment(SessionModel.self) private var session
    @State private var username = ""
    @State private var password = ""
    @State private var submitting = false
    @State private var error: String?
    @FocusState private var focus: Field?
    enum Field { case username, password }

    private var formValid: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6 }

    var body: some View {
        Form {
            if session.expired { Text("Your session expired. Please sign in again.").foregroundStyle(.secondary) }
            TextField("Username", text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }
            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .onSubmit { Task { await submit() } }
            if let error { Text(error).foregroundStyle(.red) }
            Button {
                Task { await submit() }
            } label: {
                if submitting { ProgressView() } else { Text("Sign in").frame(maxWidth: .infinity) }
            }
            .disabled(!formValid || submitting)
        }
        .navigationTitle("Sign in")
    }

    private func submit() async {
        guard formValid, !submitting else { return } // double submit
        submitting = true
        defer { submitting = false }
        do {
            try await session.signIn(username: username.trimmingCharacters(in: .whitespaces), password: password)
        } catch .server(status: 400), .unauthorized {
            error = "Wrong username or password" // never say which one
        } catch {
            self.error = error.userMessage
        }
    }
}

struct ProfileView: View {
    @Environment(SessionModel.self) private var session
    @State private var profile: Loadable<Profile> = .idle

    var body: some View {
        Group {
            switch profile {
            case .idle, .loading: LoadingView()
            case .failed(let error, _): ErrorView(message: error.userMessage)
            case .loaded(let p):
                List {
                    LabeledContent("Name", value: p.firstName)
                    LabeledContent("Username", value: "@\(p.username)")
                    LabeledContent("Email", value: p.email)
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar { Button("Log out", action: session.signOut) }
        .task {
            do { profile = .loaded(try await session.profile()) } catch { profile = .failed(AppError.map(error), previous: nil) }
        }
    }
}
