import SwiftUI
import LocalAuthentication

@main
struct GymTrackerApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase
    @State private var unlocked = false
    @State private var authFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if store.data.profile.faceID && !unlocked {
                    LockScreen(failed: authFailed) { attemptUnlock() }
                } else {
                    RootView()
                        .environmentObject(store)
                }
            }
            .onAppear {
                if store.data.profile.faceID { attemptUnlock() } else { unlocked = true }
            }
            .onChange(of: phase) { _, new in
                switch new {
                case .background:
                    store.writeNow()
                    if store.data.profile.faceID { unlocked = false }
                case .active:
                    if store.data.profile.faceID && !unlocked { attemptUnlock() }
                default:
                    break
                }
            }
        }
    }

    private func attemptUnlock() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use passcode"
        var err: NSError?
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        ctx.evaluatePolicy(policy, localizedReason: "Unlock your log") { ok, _ in
            DispatchQueue.main.async {
                unlocked = ok
                authFailed = !ok
            }
        }
    }
}

/// Whatever the app is called on the home screen, so renaming it in
/// project.yml renames it everywhere.
var appDisplayName: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "Gym Tracker"
}

struct LockScreen: View {
    var failed: Bool
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 34)).foregroundStyle(T.mut)
            Text(appDisplayName).font(.system(size: 20, weight: .bold))
            Text(failed ? "Unlock to continue." : "Unlocking...")
                .font(.system(size: 13)).foregroundStyle(T.mut)
            if failed {
                Button(action: retry) {
                    Text("Try again").fontWeight(.semibold)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            DashboardView(tab: $tab)
                .tabItem { Label("Home", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)
            FoodView()
                .tabItem { Label("Food", systemImage: "fork.knife") }
                .tag(1)
            TrainView()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
                .tag(2)
            PhotosView()
                .tabItem { Label("Photos", systemImage: "photo.on.rectangle") }
                .tag(3)
            PlanView()
                .tabItem { Label("Plan", systemImage: "slider.horizontal.3") }
                .tag(4)
        }
        .tint(T.accent)
        .overlay(alignment: .top) {
            if let e = store.saveError {
                Text(e)
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(T.bad.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
        }
    }
}
