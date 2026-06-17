//
//  CruiseGeoFallbackView.swift
//  ShipTrip
//
//  Schematische Geo-Karte als Cover-Fallback wenn keine Fotos vorhanden sind.
//  Rein dekorativ — kein NavigationLink, kein Text-Overlay.
//

import SwiftUI

/// Größen-agnostische Canvas-Darstellung einer Routenlinie über einem Ozean-Farbverlauf.
/// Funktioniert sowohl als Hero (~190 pt) als auch als kleines Thumbnail.
struct CruiseGeoFallbackView: View {
    let ports: [Port]

    var body: some View {
        Canvas { context, size in
            // MARK: Hintergrund-Gradient
            let bgGradient = Gradient(colors: [Color.navyDark, Color.oceanBlue, Color.oceanLight])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    bgGradient,
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            // Gültige Punkte filtern, nach sortOrder geordnet
            let validPorts = ports
                .filter {
                    $0.hasValidCoordinates
                        && $0.latitude.isFinite
                        && $0.longitude.isFinite
                        && (-90...90).contains($0.latitude)
                        && (-180...180).contains($0.longitude)
                }
                .sorted { $0.sortOrder < $1.sortOrder }

            guard validPorts.count >= 2 else {
                // Weniger als 2 gültige Punkte — nur Ozean-Symbol
                let waveText = Text("🌊")
                    .font(.system(size: min(size.width, size.height) * 0.25))
                var waveCtx = context
                waveCtx.opacity = 0.4
                waveCtx.draw(
                    waveText,
                    at: CGPoint(x: size.width / 2, y: size.height / 2)
                )
                return
            }

            // MARK: Bounding Box berechnen
            var minLat = validPorts[0].latitude
            var maxLat = validPorts[0].latitude
            var minLon = validPorts[0].longitude
            var maxLon = validPorts[0].longitude
            for port in validPorts {
                minLat = Swift.min(minLat, port.latitude)
                maxLat = Swift.max(maxLat, port.latitude)
                minLon = Swift.min(minLon, port.longitude)
                maxLon = Swift.max(maxLon, port.longitude)
            }

            // Division-by-zero abfangen: Range = 0 → 0.5 Grad Padding
            let latRange = (maxLat - minLat) < 0.0001 ? 0.5 : maxLat - minLat
            let lonRange = (maxLon - minLon) < 0.0001 ? 0.5 : maxLon - minLon
            let effectiveMinLat = (maxLat - minLat) < 0.0001 ? minLat - 0.25 : minLat
            let effectiveMaxLat = (maxLat - minLat) < 0.0001 ? maxLat + 0.25 : maxLat
            let effectiveMinLon = (maxLon - minLon) < 0.0001 ? minLon - 0.25 : minLon

            let pad = min(size.width, size.height) * 0.12

            // Koordinate → Canvas-Punkt (Y invertiert: Canvas wächst nach unten)
            func point(lat: Double, lon: Double) -> CGPoint {
                CGPoint(
                    x: pad + CGFloat((lon - effectiveMinLon) / lonRange) * (size.width - 2 * pad),
                    y: pad + CGFloat((effectiveMaxLat - lat) / latRange) * (size.height - 2 * pad)
                )
            }

            // MARK: Dekorative Ringe (schematische Breiten-/Längengrade)
            let ringRadius = max(size.width, size.height) * 0.7
            var ring1 = Path()
            ring1.addArc(
                center: CGPoint(x: size.width * 0.2, y: size.height * 0.8),
                radius: ringRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            context.stroke(
                ring1,
                with: .color(.white.opacity(0.17)),
                style: StrokeStyle(lineWidth: 1.5)
            )

            var ring2 = Path()
            ring2.addArc(
                center: CGPoint(x: size.width * 0.85, y: size.height * 0.15),
                radius: ringRadius * 0.85,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            context.stroke(
                ring2,
                with: .color(.white.opacity(0.17)),
                style: StrokeStyle(lineWidth: 1.5)
            )

            // MARK: Gestrichelte Routenlinie
            let canvasPoints = validPorts.map { point(lat: $0.latitude, lon: $0.longitude) }
            var routePath = Path()
            routePath.move(to: canvasPoints[0])
            for pt in canvasPoints.dropFirst() {
                routePath.addLine(to: pt)
            }
            context.stroke(
                routePath,
                with: .color(.white.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])
            )

            // MARK: Hafen-Punkte
            let dotR: CGFloat = 3.5
            for pt in canvasPoints {
                let dotRect = CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.6)))
            }
        }
    }
}

// MARK: - Preview

#Preview("Mit Route") {
    let barcelona = Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.18)
    barcelona.sortOrder = 0
    let marseille = Port(name: "Marseille", country: "Frankreich", latitude: 43.30, longitude: 5.37)
    marseille.sortOrder = 1
    let genua = Port(name: "Genua", country: "Italien", latitude: 44.41, longitude: 8.93)
    genua.sortOrder = 2
    let civitavecchia = Port(name: "Civitavecchia", country: "Italien", latitude: 42.09, longitude: 11.79)
    civitavecchia.sortOrder = 3

    return CruiseGeoFallbackView(ports: [barcelona, marseille, genua, civitavecchia])
        .frame(width: 360, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 16))
}

#Preview("Keine Koordinaten") {
    let seaDay = Port(name: "Seetag", country: "", latitude: 0, longitude: 0)
    seaDay.isSeaDay = true

    return CruiseGeoFallbackView(ports: [seaDay])
        .frame(width: 360, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 16))
}
