//
//  MapView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Location Manager für Standort-Berechtigung
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

/// Interaktive Weltkarte mit allen Kreuzfahrt-Routen
struct MapView: View {
    @Query(sort: \Cruise.startDate, order: .reverse) private var cruises: [Cruise]
    @StateObject private var locationManager = LocationManager()
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCruise: Cruise?
    @State private var hiddenCruiseIndices: Set<Int> = []
    @State private var showingLegend = true
    
    // Routenfarben aus zentraler Quelle (Color+Theme)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(Array(cruises.enumerated()), id: \.offset) { index, cruise in
                        if !hiddenCruiseIndices.contains(index) {
                            // Nur Häfen mit gültigen Koordinaten
                            let validPorts = cruise.route
                                .filter { $0.hasValidCoordinates }
                                .sorted(by: { $0.sortOrder < $1.sortOrder })
                            
                            // Route-Linie
                            if validPorts.count > 1 {
                                MapPolyline(coordinates: validPorts.map { $0.coordinate })
                                    .stroke(Color.routeColor(at: index), lineWidth: 3)
                            }
                            
                            // Hafen-Marker — Form/Icon nach Position (Farbe = Reise, Form = Rolle):
                            // Start: klassischer Pin · Zwischenhalt: kleiner Punkt · Endpunkt: Zielflagge
                            ForEach(Array(validPorts.enumerated()), id: \.offset) { portIndex, port in
                                Annotation(port.name, coordinate: port.coordinate) {
                                    VStack(spacing: 2) {
                                        if portIndex == 0 {
                                            // Starthafen
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.routeColor(at: index))
                                        } else if portIndex == validPorts.count - 1 {
                                            // Endhafen (nur wenn mehr als 1 Hafen)
                                            Image(systemName: "flag.checkered.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.routeColor(at: index))
                                        } else {
                                            // Zwischen-Häfen
                                            Image(systemName: "circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(Color.routeColor(at: index))
                                        }
                                        Text(port.name)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }
                
                // Legend Overlay
                if showingLegend && !cruises.isEmpty {
                    legendOverlay
                }
            }
            .navigationTitle("Karte")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showingLegend.toggle()
                        }
                    } label: {
                        Image(systemName: showingLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                    }
                }
            }
            .onAppear {
                // Request location permission if not determined
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestPermission()
                }
            }
        }
    }
    
    private var legendOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Routen")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(cruises.enumerated()), id: \.offset) { index, cruise in
                        HStack {
                            Circle()
                                .fill(Color.routeColor(at: index))
                                .frame(width: 12, height: 12)
                            
                            Text(cruise.title)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                toggleVisibility(at: index)
                            } label: {
                                Image(systemName: hiddenCruiseIndices.contains(index) ? "eye.slash" : "eye")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                zoomTo(cruise: cruise)
                            } label: {
                                Image(systemName: "scope")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
    
    private func toggleVisibility(at index: Int) {
        withAnimation {
            if hiddenCruiseIndices.contains(index) {
                hiddenCruiseIndices.remove(index)
            } else {
                hiddenCruiseIndices.insert(index)
            }
        }
    }
    
    private func zoomTo(cruise: Cruise) {
        // Nur Häfen mit gültigen Koordinaten verwenden
        let validPorts = cruise.route.filter { $0.hasValidCoordinates }
        guard !validPorts.isEmpty else { return }
        
        let coordinates = validPorts.map { $0.coordinate }
        let region = MKCoordinateRegion(coordinates: coordinates)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(region)
        }
    }
}

// MARK: - Helper Extension

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }
        
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Berechne Span mit Padding und Minimum
        var latDelta = (maxLat - minLat) * 1.5
        var lonDelta = (maxLon - minLon) * 1.5
        
        // Minimum Span für einzelne Punkte oder sehr kleine Regionen
        latDelta = max(latDelta, 2.0)
        lonDelta = max(lonDelta, 2.0)
        
        // Maximum begrenzen
        latDelta = min(latDelta, 50.0)
        lonDelta = min(lonDelta, 50.0)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
        
        self = MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    MapView()
        .modelContainer(for: [Cruise.self, Port.self], inMemory: true)
}
