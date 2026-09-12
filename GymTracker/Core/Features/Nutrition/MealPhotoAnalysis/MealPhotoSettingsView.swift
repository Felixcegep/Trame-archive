import SwiftUI

struct MealPhotoSettingsView: View {
    @AppStorage(DefaultsKey.mealPhotoConsent) private var consentRaw: String = MealPhotoConsent.default.rawValue
    @State private var keyDraft = ""
    @State private var hasStoredKey = GeminiAPIKeyStore.shared.hasKey
    @State private var showsSaveError = false
    @State private var showsRemoveConfirmation = false

    var body: some View {
        Form {
            Section {
                if hasStoredKey {
                    Text("Key saved on this iPhone")
                        .foregroundStyle(Color.trameText)
                        .accessibilityIdentifier("photo-estimate-key-saved")
                    Button("Remove key", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .accessibilityIdentifier("photo-estimate-remove-key")
                } else {
                    SecureField("Gemini key", text: $keyDraft)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("photo-estimate-key-field")
                    Button("Save key") {
                        do {
                            try GeminiAPIKeyStore.shared.save(keyDraft)
                            keyDraft = ""
                            hasStoredKey = true
                        } catch {
                            showsSaveError = true
                        }
                    }
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("photo-estimate-save-key")
                }
            } header: {
                Text("Your key")
            } footer: {
                Text("Paste your own Gemini key. Trame never ships or syncs a key. The stored value is never shown again.")
            }

            Section {
                Picker("When to send a photo", selection: consentBinding) {
                    ForEach(MealPhotoConsent.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .accessibilityIdentifier("photo-estimate-consent-picker")
            } header: {
                Text("Sending")
            } footer: {
                Text("A chosen photo is compressed and stripped of location data first. Only that image is sent — never your food library or meal history. Nothing is logged until you review the estimate and tap Add.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .tint(Color.trameAction)
        .navigationTitle("Photo estimates")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Key wasn’t saved", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter a key, then save it.")
        }
        .confirmationDialog("Remove the saved Gemini key?", isPresented: $showsRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                GeminiAPIKeyStore.shared.delete()
                hasStoredKey = false
                keyDraft = ""
            }
            .accessibilityIdentifier("confirm-remove-photo-estimate-key")
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { hasStoredKey = GeminiAPIKeyStore.shared.hasKey }
    }

    private var consentBinding: Binding<MealPhotoConsent> {
        Binding(
            get: { MealPhotoConsent(rawValue: consentRaw) ?? .default },
            set: { consentRaw = $0.rawValue }
        )
    }
}
