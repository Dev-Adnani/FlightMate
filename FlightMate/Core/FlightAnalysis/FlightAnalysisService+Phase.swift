//
//  FlightAnalysisService+Phase.swift
//  FlightMate
//
//  The 9-phase deterministic flight-phase state machine, kept in its own
//  file (per the 300-line-per-file rule). Driven by ground speed, vertical
//  speed, distance to the nearest airport, the current FlightPerformanceProfile,
//  and the previous phase (for hysteresis, e.g. so ".landing" naturally
//  decays into ".taxi" without an extra timer).
//
//  This is disclosed explicitly as a heuristic, not a certainty: Aerofly's
//  UDP feed has no gear-squat/AGL signal, so "on ground" is inferred from
//  speed/altitude trend only -- the same approach real ADS-B-based phase
//  classifiers use.
//

import Foundation

extension FlightAnalysisService {
    /// Everything the phase state machine needs, pre-converted into the
    /// units it reasons in (knots, feet).
    struct PhaseInputs {
        let groundSpeedKts: Double?
        let altitudeFeet: Double?
        let isClimbing: Bool
        let isDescending: Bool
        let distanceToNearestAirportNauticalMiles: Double?
        let performanceProfile: FlightPerformanceProfile
        let previousPhase: FlightPhase
    }

    /// Returns the newly determined phase alongside the checkmark-style
    /// reasons that justify it -- see `FlightAnalysis.phaseReasons`.
    ///
    /// Checked in order: landing (hysteresis) -> parked -> taxi -> climb ->
    /// takeoff -> cruise -> descent/approach -> unchanged fallback. Climb
    /// and takeoff never compete (`isClimbing` implies not level, and vice
    /// versa). Takeoff is checked *before* cruise specifically because
    /// cruise's own "altitude unknown" escape hatch (needed for aircraft
    /// that never resolved) would otherwise swallow a fast, level ground
    /// roll before rotation; takeoff's own "not already airborne per the
    /// previous phase" guard is what then keeps an established, at-
    /// altitude cruise from ever being reclassified as a fresh takeoff.
    static func determinePhase(_ inputs: PhaseInputs) -> (phase: FlightPhase, reasons: [String]) {
        guard let groundSpeedKts = inputs.groundSpeedKts, let altitudeFeet = inputs.altitudeFeet else {
            return (.unknown, ["No telemetry received yet"])
        }

        let level = !inputs.isClimbing && !inputs.isDescending
        let wasDescendingOrOnApproach = inputs.previousPhase == .descent || inputs.previousPhase == .approach
        let withinApproachProximity = inputs.distanceToNearestAirportNauticalMiles
            .map { $0 <= FlightAnalysisConstants.approachProximityNm }

        // Landing: checked first since it's a more specific, hysteresis-
        // driven transition than the generic rules below. Without this,
        // a just-touched-down aircraft (level, decelerating, still above
        // taxi speed) would be reclassified as taxi or takeoff on the very
        // next sample. Naturally falls through to ".taxi" once ground
        // speed decays below `taxiUpperBoundKt` -- no extra timer needed.
        if inputs.previousPhase == .approach || inputs.previousPhase == .landing,
           groundSpeedKts < inputs.performanceProfile.approachAirspeedKts,
           groundSpeedKts > FlightAnalysisConstants.taxiUpperBoundKt {
            return (.landing, [
                "Previously on approach or landing",
                "Ground speed dropped below approach speed",
                "Ground speed still above taxi range"
            ])
        }

        if groundSpeedKts <= FlightAnalysisConstants.parkedSpeedKt, level,
           canTransitionToGroundPhase(from: inputs.previousPhase) {
            return (.parked, ["Ground speed near zero", "Not climbing or descending"])
        }

        if groundSpeedKts <= FlightAnalysisConstants.taxiUpperBoundKt, level,
           canTransitionToGroundPhase(from: inputs.previousPhase) {
            return (.taxi, ["Ground speed in taxi range", "Level with ground"])
        }

        if inputs.isClimbing, belowCruiseAltitudeOrUnknown(altitudeFeet: altitudeFeet, profile: inputs.performanceProfile) {
            return (.climb, [
                "Climbing",
                inputs.performanceProfile.cruiseAltitudeFt == nil
                    ? "Aircraft cruise altitude unknown"
                    : "Below cruise altitude threshold"
            ])
        }

        // Takeoff: level, faster than taxi range, and not already
        // airborne per the previous phase -- guards against an
        // established cruise (also level and fast) ever being
        // reclassified as a fresh takeoff. Checked before cruise so a
        // ground roll with an unresolved aircraft (whose cruise altitude
        // is unknown, and therefore can't gate cruise below) isn't
        // swallowed by cruise's own "altitude unknown" escape hatch.
        //
        // `previousPhase != .unknown` additionally requires that we've
        // actually *observed* the aircraft on the ground before calling
        // this a takeoff -- `.unknown` only ever means "no prior
        // analysis exists" (app just launched / just reconnected), not
        // "was on the ground." Without this, connecting to Aerofly while
        // already cruising or descending produces a false "Takeoff"
        // event on the very first sample (see the cold-start rule below
        // for what a genuine cold start falls back to instead).
        if level, groundSpeedKts > FlightAnalysisConstants.taxiUpperBoundKt,
           !inputs.previousPhase.isAirborne, inputs.previousPhase != .unknown {
            return (.takeoff, ["Ground speed above taxi range", "Not yet climbing", "Previously observed on the ground"])
        }

        if level, groundSpeedKts > FlightAnalysisConstants.taxiUpperBoundKt,
           atOrAboveCruiseAltitudeOrUnknown(altitudeFeet: altitudeFeet, profile: inputs.performanceProfile) {
            return (.cruise, [
                "Vertical speed within level-flight deadband",
                inputs.performanceProfile.cruiseAltitudeFt == nil
                    ? "Aircraft cruise altitude unknown"
                    : "At or above cruise altitude threshold",
                "Ground speed consistent with cruise"
            ])
        }

        // Cold start, still ambiguous: level and fast, but below the
        // cruise-altitude threshold, with no prior observation at all
        // (`previousPhase == .unknown`) to say whether this is a genuine
        // ground roll or level flight that simply never reaches this
        // aircraft's cruise altitude (pattern work, a GA aircraft's
        // low-altitude cruise, a step climb). A single sample cannot
        // disambiguate the two -- but assuming "already airborne" is the
        // safer default: a false "Takeoff" here can get permanently
        // stuck (nothing about continuing level flight below cruise
        // altitude would ever re-trigger this rule), whereas assuming
        // cruise self-corrects immediately via the climb/descent rules
        // the moment the aircraft's vertical speed actually changes.
        if inputs.previousPhase == .unknown, level, groundSpeedKts > FlightAnalysisConstants.taxiUpperBoundKt {
            return (.cruise, [
                "No prior observation to compare against",
                "Ground speed and level flight consistent with already being airborne"
            ])
        }

        if inputs.isDescending || wasDescendingOrOnApproach {
            let decelerating = groundSpeedKts
                <= inputs.performanceProfile.approachAirspeedKts * FlightAnalysisConstants.approachDecelerationToleranceFactor

            if withinApproachProximity == true, decelerating {
                return (.approach, [
                    "Within \(Int(FlightAnalysisConstants.approachProximityNm)) NM of nearest airport",
                    "Descending",
                    "Speed approaching approach speed"
                ])
            }
            if inputs.isDescending {
                return (.descent, [
                    "Descending",
                    withinApproachProximity == nil
                        ? "Nearest airport unknown"
                        : "Beyond approach proximity of nearest airport"
                ])
            }
        }

        // No rule matched cleanly for this sample (e.g. level flight with
        // an unresolved aircraft and ambiguous altitude/speed) -- retain
        // the previous phase rather than guessing a fictitious transition.
        return (inputs.previousPhase, ["No clear phase transition detected; retaining previous phase"])
    }

    // MARK: - Ground-phase reachability

    /// Whether `previousPhase` is a plausible predecessor for `.parked`/
    /// `.taxi`. Deliberately excludes `.cruise`, `.climb`, and `.descent`:
    /// an aircraft that was genuinely at cruise, climbing, or descending
    /// a moment ago cannot plausibly be on the ground the very next
    /// sample, so a near-zero ground-speed reading in that situation is
    /// far more likely a bad or frozen telemetry sample than an actual
    /// landing. Misclassifying it as `.parked` would prematurely end the
    /// flight (`FlightEventDetectionService.detectFlightCompleted` fires
    /// on any transition into `.parked` after having been airborne) and
    /// silently drop every event for the rest of the real flight. Falling
    /// through to the "retain previous phase" fallback below is the
    /// correct, conservative response to what is almost certainly noise.
    /// `.approach` and `.landing` remain valid predecessors since
    /// decelerating through those phases is the normal path to actually
    /// reaching the ground.
    private static func canTransitionToGroundPhase(from previousPhase: FlightPhase) -> Bool {
        switch previousPhase {
        case .cruise, .climb, .descent:
            return false
        case .unknown, .parked, .taxi, .takeoff, .approach, .landing:
            return true
        }
    }

    // MARK: - Cruise altitude helpers

    /// `true` whenever `profile.cruiseAltitudeFt` is unknown (the "or
    /// aircraft/altitude unknown" escape hatch applies to both this and
    /// `atOrAboveCruiseAltitudeOrUnknown` independently -- which one
    /// actually fires depends on `isClimbing` vs. level flight, not on
    /// this check).
    private static func belowCruiseAltitudeOrUnknown(altitudeFeet: Double, profile: FlightPerformanceProfile) -> Bool {
        guard let cruiseAltitudeFt = profile.cruiseAltitudeFt else { return true }
        return altitudeFeet < cruiseAltitudeFt * FlightAnalysisConstants.cruiseAltitudeFraction
    }

    private static func atOrAboveCruiseAltitudeOrUnknown(altitudeFeet: Double, profile: FlightPerformanceProfile) -> Bool {
        guard let cruiseAltitudeFt = profile.cruiseAltitudeFt else { return true }
        return altitudeFeet >= cruiseAltitudeFt * FlightAnalysisConstants.cruiseAltitudeFraction
    }
}
