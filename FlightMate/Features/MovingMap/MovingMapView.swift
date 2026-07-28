//
//  MovingMapView.swift
//  FlightMate
//
//  FlightMate's Moving Map: a lightweight situational-awareness map, not
//  a navigation chart. Shows the current aircraft, departure/destination/
//  nearest airports, a simple route line, and an optional breadcrumb
//  trail -- built entirely on Apple's native MapKit, no third-party map
//  SDK.
//

import MapKit
import SwiftUI

/// Root view for the Moving Map feature.
///
/// All business logic (position/heading, resolved airports, route line,
/// trail) lives in `MovingMapViewModel` -- this view only lays things
/// out and owns purely-visual camera state (`MapCameraPosition` is a
/// MapKit UI concept, not domain data, so it stays here rather than in
/// the view model).
struct MovingMapView: View {
    @StateObject private var viewModel: MovingMapViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnAircraft = false

    /// - Parameters:
    ///   - flightContextEngine: Source of live aircraft position/heading.
    ///   - flightAnalysisEngine: Source of resolved departure/
    ///     destination/nearest airports.
    ///   - mapTrailService: Source of the current flight's breadcrumb
    ///     trail.
    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        mapTrailService: MapTrailService
    ) {
        _viewModel = StateObject(
            wrappedValue: MovingMapViewModel(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                mapTrailService: mapTrailService
            )
        )
    }

    var body: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            if let routeCoordinates = viewModel.routeCoordinates {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }

            if viewModel.trailCoordinates.count > 1 {
                MapPolyline(coordinates: viewModel.trailCoordinates)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            ForEach(viewModel.airportAnnotations) { annotation in
                Annotation(annotation.airport.icaoCode, coordinate: annotation.coordinate) {
                    MovingMapAirportMarkerView(
                        role: annotation.role,
                        isSelected: viewModel.selectedAirport == annotation.airport
                    )
                    .onTapGesture {
                        viewModel.selectAirport(annotation.airport)
                    }
                }
                .annotationTitles(.hidden)
            }

            if let aircraftCoordinate = viewModel.aircraftCoordinate {
                Annotation("Aircraft", coordinate: aircraftCoordinate.clLocationCoordinate) {
                    MovingMapAircraftMarkerView(headingDegrees: viewModel.aircraftHeadingDegrees ?? 0)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapZoomStepper()
        }
        .overlay(alignment: .topTrailing) {
            resetToAircraftButton
                .padding()
        }
        .overlay(alignment: .bottomLeading) {
            if let selectedAirport = viewModel.selectedAirport {
                MovingMapAirportInfoCard(airport: selectedAirport, onDismiss: viewModel.clearSelection)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedAirport)
        .onChange(of: viewModel.aircraftCoordinate) { _, newCoordinate in
            // Frame the aircraft automatically exactly once, the first
            // time its position becomes known -- after that, the map
            // respects the user's own pan/zoom until they explicitly
            // tap "Reset to Aircraft". This app deliberately never
            // fights the user's camera on every telemetry update.
            guard !hasCenteredOnAircraft, let newCoordinate else { return }
            hasCenteredOnAircraft = true
            recenter(on: newCoordinate)
        }
        .navigationTitle("Moving Map")
    }

    private var resetToAircraftButton: some View {
        Button {
            if let aircraftCoordinate = viewModel.aircraftCoordinate {
                recenter(on: aircraftCoordinate)
            }
        } label: {
            Label("Reset to Aircraft", systemImage: "location.fill")
                .labelStyle(.iconOnly)
                .padding(6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.aircraftCoordinate == nil)
        .help("Reset to Aircraft")
    }

    private func recenter(on coordinate: GeoCoordinate) {
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate.clLocationCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
                )
            )
        }
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    let flightHistoryEngine = FlightHistoryEngine(flightEventEngine: flightEventEngine)
    MovingMapView(
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        mapTrailService: MapTrailService(
            flightContextEngine: flightContextEngine,
            flightHistoryEngine: flightHistoryEngine
        )
    )
}
