//
//  CameraShakeFeel.swift
//  FlightMate
//
//  Kf/Df “feel” shortcuts from Mar17’s July 2026 forum guidance:
//  lower Kf → heavier / floating (good for widebodies); higher Df → less bounce.
//

import Foundation

/// Linear spring/damper feel for CameraPilot (Kt/Dt omitted — Mar17 reports no effect).
enum CameraShakeFeel: String, CaseIterable, Identifiable, Sendable {
    case softFloating
    case balanced
    case firm
    case stockLike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .softFloating: return "Soft / floating (widebody)"
        case .balanced: return "Balanced"
        case .firm: return "Firm / locked"
        case .stockLike: return "Near stock (stiff)"
        }
    }

    var detail: String {
        switch self {
        case .softFloating:
            return "Lower Kf for lag on touchdown; Df kept moderate so it isn’t springy."
        case .balanced:
            return "Mid Kf with solid damping — good airliner starting point."
        case .firm:
            return "Higher Kf, camera tracks the airframe more tightly."
        case .stockLike:
            return "Closer to default Aerofly rigidity (Kf≈40)."
        }
    }

    /// Suggested Kf / Df only (Kt/Dt unused in practice).
    var kfDf: (kf: Double, df: Double) {
        switch self {
        case .softFloating: return (0.75, 0.28)
        case .balanced: return (1.25, 0.32)
        case .firm: return (4.0, 0.5)
        case .stockLike: return (40.0, 1.0)
        }
    }
}
