//
//  AboutTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// About tab showing app info
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon and Name
            VStack(spacing: 12) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("PeekOCR")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Versión \(Constants.App.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text("Captura texto desde cualquier parte de tu pantalla con un atajo de teclado. Detecta automáticamente códigos QR.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            
            // Features - Centered
            FeaturesList()
                .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Footer
            VStack(spacing: 4) {
                Text("Desarrollado con ❤️ por StevenACZ")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Link("github.com/StevenACZ/PeekOCR", destination: URL(string: "https://github.com/StevenACZ/PeekOCR")!)
                    .font(.caption)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Features List

private struct FeaturesList: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            FeatureRow(icon: "doc.text.viewfinder", text: "OCR preciso con Vision")
            FeatureRow(icon: "qrcode", text: "Detección de códigos QR")
            FeatureRow(icon: "camera.viewfinder", text: "Captura de pantalla")
            FeatureRow(icon: "keyboard", text: "Atajos personalizables")
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    AboutTab()
}
