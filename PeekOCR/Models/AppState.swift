//
//  AppState.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import Combine

/// Global app state observable object
final class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published var isCapturing: Bool = false
    @Published var lastCapturedText: String = ""
    @Published var showingSettings: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
}
