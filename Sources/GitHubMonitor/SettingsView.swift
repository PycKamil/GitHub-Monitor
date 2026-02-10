import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var repoStore: RepositoryStore
    @EnvironmentObject private var gitHub: GitHubService
    @State private var newRepoText = ""

    var body: some View {
        Form {
            Section("GitHub Authentication") {
                HStack(spacing: 10) {
                    Circle()
                        .fill(gitHub.isAuthenticated ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    if gitHub.isAuthenticated {
                        Text("Signed in as **\(gitHub.authUser)**")
                    } else {
                        Text("Not authenticated. Run `gh auth login` in Terminal.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task { await gitHub.checkAuth() }
                    }
                }
            }

            Section("Monitored Repositories") {
                HStack {
                    TextField("owner/repo", text: $newRepoText)
                        .onSubmit { addRepo() }
                    Button("Add") { addRepo() }
                        .disabled(newRepoText.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if repoStore.repositories.isEmpty {
                    Text("No repositories added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repoStore.repositories) { repo in
                        HStack {
                            Image(systemName: "book.closed")
                                .foregroundStyle(.secondary)
                            Text(repo.fullName)
                            Spacer()
                            Button(role: .destructive) {
                                repoStore.remove(repo)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 300)
    }

    private func addRepo() {
        let text = newRepoText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        repoStore.add(fullName: text)
        newRepoText = ""
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(RepositoryStore())
            .environmentObject(GitHubService())
    }
}
