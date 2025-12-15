//
//  TranslationSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Translation settings tab
struct TranslationSettingsTab: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                Picker("Idioma origen:", selection: Binding(
                    get: { SupportedLanguage.from(code: settings.sourceLanguage) ?? .english },
                    set: { settings.sourceLanguage = $0.rawValue }
                )) {
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.fullDisplayName)
                            .tag(language)
                    }
                }
                
                Picker("Idioma destino:", selection: Binding(
                    get: { SupportedLanguage.from(code: settings.targetLanguage) ?? .spanish },
                    set: { settings.targetLanguage = $0.rawValue }
                )) {
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.fullDisplayName)
                            .tag(language)
                    }
                }
            } header: {
                Text("Configuración de Traducción")
            } footer: {
                Text("El texto capturado con el atajo de traducción se convertirá del idioma origen al idioma destino.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sobre la traducción")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("PeekOCR usa el framework de traducción de Apple, que procesa todo localmente sin enviar datos a internet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                SwapLanguagesButton(settings: settings)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Swap Languages Button

private struct SwapLanguagesButton: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Button {
            let temp = settings.sourceLanguage
            settings.sourceLanguage = settings.targetLanguage
            settings.targetLanguage = temp
        } label: {
            Label("Intercambiar idiomas", systemImage: "arrow.up.arrow.down")
        }
    }
}

// MARK: - Preview

#Preview {
    TranslationSettingsTab()
}
