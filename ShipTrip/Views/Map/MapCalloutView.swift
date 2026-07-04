//
//  MapCalloutView.swift
//  ShipTrip
//

import SwiftUI

/// Tap-Callout für einen Hafen-Pin/-Badge: Name + optionales Hafenfoto-Thumbnail statt
/// eines permanenten Kartenlabels (Polarsteps-Prinzip, B4.3b).
struct MapCalloutView: View {
    let port: Port

    var body: some View {
        HStack(spacing: 8) {
            if let imageData = port.imageData {
                AsyncPhotoView(imageData: imageData, maxPixelSize: 64)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text(port.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.navyDark.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    MapCalloutView(port: Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.17))
        .padding()
        .background(Color.gray.opacity(0.2))
}
