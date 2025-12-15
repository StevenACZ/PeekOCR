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
                
                Text("Versión 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text("Captura texto desde cualquier parte de tu pantalla con un atajo de teclado. Detecta automáticamente códigos QR y traduce texto al instante.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            
            // Features
            FeaturesList()
            
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
        VStack(alignment: .leading, spacing: 8) {
            FeatureRow(icon: "camera.viewfinder", text: "OCR preciso con Vision")
            FeatureRow(icon: "qrcode", text: "Detección de códigos QR")
            FeatureRow(icon: "globe", text: "Traducción offline")
            FeatureRow(icon: "keyboard", text: "Atajos personalizables")
        }
        .padding(.horizontal, 48)
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
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    AboutTab()
}
