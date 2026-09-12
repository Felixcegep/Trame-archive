import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Two-step export: choose domains, then confirm and write the file.
///
/// Restore still replaces everything on the destination iPhone. The wizard
/// only decides what this file carries; omitted categories restore empty.
struct BackupExportWizardView: View {
    let inventory: BackupExportInventory
    let isPreparing: Bool
    let onCancel: () -> Void
    let onConfirm: (BackupExportSelection) -> Void

    @State private var selection = BackupExportSelection.everything
    @State private var step: Step = .choose

    private enum Step {
        case choose
        case review
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose:
                    chooseStep
                case .review:
                    reviewStep
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle(step == .choose
                ? String(localized: "Export backup")
                : String(localized: "Review backup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isPreparing)
                    .accessibilityIdentifier("backup-export-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .choose {
                        Button("Continue") {
                            step = .review
                        }
                        .disabled(selection.isEmpty)
                        .accessibilityIdentifier("backup-export-continue")
                    }
                }
            }
        }
        .accessibilityIdentifier("backup-export-wizard")
        .interactiveDismissDisabled(isPreparing)
    }

    private var chooseStep: some View {
        Form {
            Section {
                Toggle(isOn: everythingBinding) {
                    Label(
                        String(localized: "Everything on this iPhone"),
                        systemImage: AppIcon.backup
                    )
                }
                .accessibilityIdentifier("backup-export-everything")
            } footer: {
                Text("A backup is a file you keep. Restoring one later replaces what is on that iPhone.")
            }

            Section("Include") {
                ForEach(BackupExportCategory.allCases) { category in
                    Toggle(isOn: binding(for: category)) {
                        LabeledContent {
                            if let count = inventory.count(for: category) {
                                Text("\(count)")
                                    .font(AppFont.metadata)
                                    .foregroundStyle(Color.trameSubdued)
                                    .monospacedDigit()
                            }
                        } label: {
                            Label(category.title, systemImage: category.icon)
                        }
                    }
                    .accessibilityIdentifier("backup-export-category-\(category.rawValue)")
                }
            }
        }
    }

    private var reviewStep: some View {
        Form {
            Section {
                ForEach(BackupExportCategory.allCases.filter { selection.contains($0) }) { category in
                    LabeledContent {
                        if let count = inventory.count(for: category) {
                            Text("\(count)")
                                .monospacedDigit()
                        }
                    } label: {
                        Label(category.title, systemImage: category.icon)
                    }
                    .accessibilityIdentifier("backup-export-review-\(category.rawValue)")
                }
            } header: {
                Text("This file")
            } footer: {
                Text(restoreWarning)
            }

            Section {
                Button {
                    onConfirm(selection)
                } label: {
                    if isPreparing {
                        Label(
                            String(localized: "Preparing export"),
                            systemImage: AppIcon.export
                        )
                    } else {
                        Label(
                            String(localized: "Create backup"),
                            systemImage: AppIcon.save
                        )
                    }
                }
                .disabled(isPreparing || selection.isEmpty)
                .accessibilityIdentifier("backup-export-create")

                Button("Back") {
                    step = .choose
                }
                .disabled(isPreparing)
                .accessibilityIdentifier("backup-export-back")
            }
        }
    }

    private var restoreWarning: String {
        if selection.includesEverything {
            String(localized: "Restoring this file replaces all data on the destination iPhone.")
        } else {
            String(localized: "Restoring this file replaces all data on the destination iPhone. Categories you leave off will be empty.")
        }
    }

    private var everythingBinding: Binding<Bool> {
        Binding(
            get: { selection.includesEverything },
            set: { included in
                selection = included ? .everything : BackupExportSelection(categories: [])
            }
        )
    }

    private func binding(for category: BackupExportCategory) -> Binding<Bool> {
        Binding(
            get: { selection.contains(category) },
            set: { included in
                selection.set(category, included: included)
            }
        )
    }
}

/// JSON backup written through the system Files picker so the copy lives on
/// this iPhone rather than only in a share sheet.
struct TrameBackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
