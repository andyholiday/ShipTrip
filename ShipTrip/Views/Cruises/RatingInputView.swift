//
//  RatingInputView.swift
//  ShipTrip
//
//  Welle D2: aus `CruiseFormView` herausgelöst, Verhalten unverändert.
//

import SwiftUI

// MARK: - Rating Input

struct RatingInputView: View {
    @Binding var rating: Double

    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        rating = Double(star)
                    }
                } label: {
                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(star <= Int(rating) ? .yellow : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            if rating > 0 {
                Text(String(format: "%.0f/5", rating))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}
