import SwiftUI

extension Color {
    // Matrix v1 theme colors
    static let matrixBackground = Color(red: 8/255, green: 4/255, blue: 172/255) // #0804ac (deep blue)
    static let matrixPrimaryText = Color.white // #FFFFFF
    static let matrixSecondaryText = Color(red: 147/255, green: 197/255, blue: 253/255) // #93C5FD (blue-300)
    static let matrixAccent = Color(red: 253/255, green: 224/255, blue: 71/255) // #FDE047 (yellow-300)
    static let matrixSuccess = Color(red: 110/255, green: 231/255, blue: 183/255) // #6EE7B7 (emerald-300)
    static let matrixError = Color(red: 253/255, green: 164/255, blue: 175/255) // #FDA4AF (rose-300)
    
    // Legacy mappings for compatibility
    static let matrixCardBackground = Color.white.opacity(0.05)
    static let matrixTextPrimary = matrixPrimaryText
    static let matrixTextSecondary = matrixSecondaryText
    static let matrixOrange = matrixAccent
    static let matrixDanger = matrixError
    static let matrixWarning = matrixAccent
    
    // Additional v1 specific colors
    static let matrixBorder = matrixSecondaryText.opacity(0.4)
    static let matrixDotHollow = matrixSecondaryText.opacity(0.6)
    static let matrixCentralCircle = Color.white.opacity(0.8)
}