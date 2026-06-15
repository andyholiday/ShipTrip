//
//  ThumbnailBackfill.swift
//  ShipTrip
//

import SwiftData
import Foundation

/// Befüllt `thumbnailData` für Fotos, die noch kein Vorschaubild haben (Altdaten).
///
/// Aufruf: `.task { await ThumbnailBackfill.run(context: modelContext) }` in der
/// ersten sichtbaren View (CruiseListView). Die Funktion ist idempotent – sie
/// berührt nur Fotos mit `thumbnailData == nil` und verarbeitet sie in kleinen
/// Batches, um Speicherspitzen und einen langen Hänger beim App-Start zu vermeiden.
/// Zwischen den Batches wird auf Task-Abbruch geprüft, sodass ein Dismiss der
/// CruiseListView den Backfill sofort stoppt.
enum ThumbnailBackfill {

    /// Maximale Anzahl Fotos pro Batch-Durchlauf.
    private static let batchSize = 20

    /// Verarbeitet alle Fotos ohne Thumbnail in Batches von `batchSize`.
    /// Pro Batch: Fetch → Downsampling (off-main) → Write → Save → Abbruchprüfung.
    /// - Parameter context: Der ModelContext der aufrufenden View (MainActor).
    @MainActor
    static func run(context: ModelContext) async {
        while true {
            // Abbruchprüfung vor jedem Batch (z.B. View wurde dismissed)
            guard !Task.isCancelled else { return }

            // Einen Batch Fotos ohne Thumbnail laden; fetchLimit begrenzt den
            // Speicherbedarf auf ~20 × Full-Res-Data statt die gesamte Bibliothek.
            var descriptor = FetchDescriptor<Photo>(
                predicate: #Predicate { $0.thumbnailData == nil }
            )
            descriptor.fetchLimit = batchSize

            guard let batch = try? context.fetch(descriptor), !batch.isEmpty else {
                // Keine weiteren Fotos ohne Thumbnail – fertig
                return
            }

            // Downsampling der Bilddaten eines Fotos auf einem Hintergrund-Thread.
            // ModelContext und @Model-Instanzen verbleiben auf dem MainActor;
            // nur das reine Data-Value wird übergeben und zurückgegeben.
            for photo in batch {
                guard !Task.isCancelled else { return }

                let fullData = photo.imageData
                let thumb = await Task.detached(priority: .utility) {
                    ImageDownsampler.thumbnail(from: fullData)
                }.value
                photo.thumbnailData = thumb
            }

            // Einmal pro Batch speichern – nicht in der inneren Schleife
            try? context.save()
        }
    }
}
