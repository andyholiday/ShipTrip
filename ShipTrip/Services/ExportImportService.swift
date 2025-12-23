//
//  ExportImportService.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Compression

// MARK: - Export/Import Data Structures

/// Exportierbare Kreuzfahrt-Daten (kompatibel mit Web-App)
struct ExportCruise: Codable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let shippingLine: String
    let ship: String
    let cabinType: String?
    let cabinNumber: String?
    let bookingNumber: String?
    let notes: String?
    let rating: Int
    let route: [ExportPort]
    let photos: [String]
    let expenses: [ExportExpense]
}

struct ExportPort: Codable {
    let id: String
    let name: String
    let country: String?
    let lat: String?
    let lng: String?
    let arrival: String
    let departure: String
    let imageUrl: String?
    let excursions: [String]
}

struct ExportExpense: Codable {
    let id: String
    let cruiseId: String
    let category: String
    let description: String?
    let amount: Double
    let expenseDate: String?
    let createdAt: String
}

// MARK: - Export/Import Service

class ExportImportService {
    static let shared = ExportImportService()
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    private let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df
    }()
    
    private let isoFormatter: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return df
    }()
    
    // MARK: - Export (JSON)
    
    /// Exportiert alle Kreuzfahrten als JSON-Datei
    func exportToJSON(cruises: [Cruise]) throws -> URL {
        var exportCruises: [ExportCruise] = []
        
        for cruise in cruises {
            // Sortierte Route
            let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
            
            let exportPorts = sortedRoute.map { port in
                ExportPort(
                    id: "port-\(UUID().uuidString)",
                    name: port.isSeaDay ? "Seetag" : port.name,
                    country: port.isSeaDay ? nil : port.country,
                    lat: port.isSeaDay ? nil : String(format: "%.8f", port.latitude),
                    lng: port.isSeaDay ? nil : String(format: "%.8f", port.longitude),
                    arrival: dateTimeFormatter.string(from: port.arrival),
                    departure: dateTimeFormatter.string(from: port.departure),
                    imageUrl: nil,
                    excursions: port.excursions
                )
            }
            
            let exportExpenses = cruise.expenses.map { expense in
                ExportExpense(
                    id: UUID().uuidString,
                    cruiseId: "cruise_\(UUID().uuidString)",
                    category: expense.category.rawValue.lowercased(),
                    description: expense.descriptionText,
                    amount: expense.amount,
                    expenseDate: expense.expenseDate != nil ? dateFormatter.string(from: expense.expenseDate!) : nil,
                    createdAt: isoFormatter.string(from: expense.createdAt)
                )
            }
            
            // Sortierte Fotos
            let sortedPhotos = cruise.photos.sorted { $0.sortOrder < $1.sortOrder }
            
            // Base64 encode photos for JSON export
            var photoBase64: [String] = []
            for photo in sortedPhotos {
                let base64 = photo.imageData.base64EncodedString()
                photoBase64.append("data:image/png;base64,\(base64)")
            }
            
            let exportCruise = ExportCruise(
                id: "cruise_\(UUID().uuidString)",
                title: cruise.title,
                startDate: dateFormatter.string(from: cruise.startDate),
                endDate: dateFormatter.string(from: cruise.endDate),
                shippingLine: cruise.shippingLine,
                ship: cruise.ship,
                cabinType: cruise.cabinType.isEmpty ? nil : cruise.cabinType,
                cabinNumber: cruise.cabinNumber.isEmpty ? nil : cruise.cabinNumber,
                bookingNumber: cruise.bookingNumber.isEmpty ? nil : cruise.bookingNumber,
                notes: cruise.notes.isEmpty ? nil : cruise.notes,
                rating: Int(cruise.rating),
                route: exportPorts,
                photos: photoBase64,
                expenses: exportExpenses
            )
            exportCruises.append(exportCruise)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportCruises)
        
        let jsonPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export.json")
        try jsonData.write(to: jsonPath)
        
        return jsonPath
    }
    
    // MARK: - Import
    
    /// Importiert Kreuzfahrten aus einer ZIP-Datei (Web-App Format)
    func importFromZip(url: URL, modelContext: ModelContext) throws -> Int {
        // Kopiere die Datei in ein temporäres Verzeichnis
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shiptrip-import-\(UUID().uuidString)")
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Entpacken
        try unzipFile(at: url, to: tempDir)
        
        // data.json suchen (im Root oder in einem Unterordner)
        var dataJsonPath = tempDir.appendingPathComponent("data.json")
        var imagesDir = tempDir
        
        if !FileManager.default.fileExists(atPath: dataJsonPath.path) {
            // Suche in Unterordnern
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in contents {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let nestedPath = item.appendingPathComponent("data.json")
                    if FileManager.default.fileExists(atPath: nestedPath.path) {
                        dataJsonPath = nestedPath
                        imagesDir = item
                        break
                    }
                }
            }
        }
        
        guard FileManager.default.fileExists(atPath: dataJsonPath.path) else {
            throw ImportError.noDataFile
        }
        
        let jsonData = try Data(contentsOf: dataJsonPath)
        return try importFromJSONData(data: jsonData, imagesDir: imagesDir, modelContext: modelContext)
    }
    
    /// Importiert Kreuzfahrten aus einer JSON-Datei
    func importFromJSON(url: URL, modelContext: ModelContext) throws -> Int {
        let jsonData = try Data(contentsOf: url)
        return try importFromJSONData(data: jsonData, imagesDir: nil, modelContext: modelContext)
    }
    
    private func importFromJSONData(data: Data, imagesDir: URL?, modelContext: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        let exportCruises = try decoder.decode([ExportCruise].self, from: data)
        
        // Hole existierende Kreuzfahrten für Duplikat-Check
        let descriptor = FetchDescriptor<Cruise>()
        let existingCruises = (try? modelContext.fetch(descriptor)) ?? []
        
        var importedCount = 0
        var skippedCount = 0
        
        for exportCruise in exportCruises {
            // Parse dates
            guard let startDate = dateFormatter.date(from: exportCruise.startDate),
                  let endDate = dateFormatter.date(from: exportCruise.endDate) else {
                continue
            }
            
            // Duplikat-Check: Prüfe ob Kreuzfahrt mit gleichem Titel, Startdatum und Schiff existiert
            let isDuplicate = existingCruises.contains { existing in
                existing.title == exportCruise.title &&
                Calendar.current.isDate(existing.startDate, inSameDayAs: startDate) &&
                existing.ship.lowercased() == exportCruise.ship.lowercased()
            }
            
            if isDuplicate {
                skippedCount += 1
                continue
            }
            
            // Create cruise
            let cruise = Cruise(
                title: exportCruise.title,
                startDate: startDate,
                endDate: endDate,
                shippingLine: exportCruise.shippingLine,
                ship: exportCruise.ship
            )
            cruise.cabinType = exportCruise.cabinType ?? ""
            cruise.cabinNumber = exportCruise.cabinNumber ?? ""
            cruise.bookingNumber = exportCruise.bookingNumber ?? ""
            cruise.notes = exportCruise.notes ?? ""
            cruise.rating = Double(exportCruise.rating)
            
            modelContext.insert(cruise)
            
            // Import ports
            for (index, exportPort) in exportCruise.route.enumerated() {
                let isSeaDay = exportPort.name.lowercased() == "seetag" || 
                               exportPort.name.lowercased() == "sea day" ||
                               exportPort.lat == nil
                
                let lat = Double(exportPort.lat ?? "0") ?? 0
                let lng = Double(exportPort.lng ?? "0") ?? 0
                
                let port = Port(
                    name: exportPort.name,
                    country: exportPort.country ?? "",
                    latitude: lat,
                    longitude: lng
                )
                
                // Try datetime format first, fallback to date-only
                if let arrivalDate = dateTimeFormatter.date(from: exportPort.arrival) ?? dateFormatter.date(from: exportPort.arrival) {
                    port.arrival = arrivalDate
                }
                if let departureDate = dateTimeFormatter.date(from: exportPort.departure) ?? dateFormatter.date(from: exportPort.departure) {
                    port.departure = departureDate
                }
                
                port.sortOrder = index
                port.isSeaDay = isSeaDay
                port.excursions = exportPort.excursions
                
                // Import port image
                if let imagesDir = imagesDir, let imageUrlString = exportPort.imageUrl {
                    let imagePath = imagesDir.appendingPathComponent(imageUrlString)
                    if let imageData = try? Data(contentsOf: imagePath) {
                        port.imageData = imageData
                    }
                }
                
                port.cruise = cruise
                modelContext.insert(port)
            }
            
            // Import photos
            for (index, photoRef) in exportCruise.photos.enumerated() {
                // Handle both file references and base64
                if photoRef.hasPrefix("data:image") {
                    // Base64 encoded
                    if let base64Data = photoRef.components(separatedBy: ",").last,
                       let imageData = Data(base64Encoded: base64Data) {
                        let photo = Photo(imageData: imageData, sortOrder: index)
                        photo.cruise = cruise
                        modelContext.insert(photo)
                    }
                } else if let imagesDir = imagesDir {
                    // File reference
                    let imagePath = imagesDir.appendingPathComponent(photoRef)
                    if let imageData = try? Data(contentsOf: imagePath) {
                        let photo = Photo(imageData: imageData, sortOrder: index)
                        photo.cruise = cruise
                        modelContext.insert(photo)
                    }
                }
            }
            
            // Import expenses
            for exportExpense in exportCruise.expenses {
                let category = mapCategory(exportExpense.category)
                let expense = Expense(
                    category: category,
                    amount: exportExpense.amount,
                    description: exportExpense.description ?? ""
                )
                if let dateString = exportExpense.expenseDate,
                   let date = dateFormatter.date(from: dateString) {
                    expense.expenseDate = date
                }
                expense.cruise = cruise
                modelContext.insert(expense)
            }
            
            importedCount += 1
        }
        
        try modelContext.save()
        return importedCount
    }
    
    private func mapCategory(_ rawCategory: String) -> ExpenseCategory {
        switch rawCategory.lowercased() {
        case "excursion", "ausflug": return .excursion
        case "cruise", "kreuzfahrt": return .cruise
        case "flight", "flug": return .flight
        case "hotel": return .hotel
        case "onboard", "an bord": return .onboard
        default: return .other
        }
    }
    
    // MARK: - ZIP Extraction (iOS compatible using shell)
    
    private func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        // Lese ZIP-Datei
        let zipData = try Data(contentsOf: sourceURL)
        let tempZipPath = destinationURL.appendingPathComponent("temp.zip")
        try zipData.write(to: tempZipPath)
        
        // Parse ZIP manuell
        try parseAndExtractZip(from: tempZipPath, to: destinationURL)
        
        // Lösche temp zip
        try? FileManager.default.removeItem(at: tempZipPath)
    }
    
    private func parseAndExtractZip(from zipURL: URL, to destURL: URL) throws {
        guard let data = try? Data(contentsOf: zipURL) else {
            throw ImportError.invalidFormat
        }
        
        // Finde End of Central Directory (EOCD)
        guard data.count > 22 else { throw ImportError.invalidFormat }
        
        var eocdOffset: Int?
        for i in stride(from: data.count - 22, through: Swift.max(0, data.count - 65557), by: -1) {
            if data[i] == 0x50 && data[i+1] == 0x4B && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        guard let eocd = eocdOffset else { throw ImportError.invalidFormat }
        
        // Lese Central Directory Offset
        let cdOffset = Int(data[eocd + 16]) | (Int(data[eocd + 17]) << 8) | (Int(data[eocd + 18]) << 16) | (Int(data[eocd + 19]) << 24)
        let numEntries = Int(data[eocd + 10]) | (Int(data[eocd + 11]) << 8)
        
        // Parse Central Directory
        var offset = cdOffset
        for _ in 0..<numEntries {
            guard offset + 46 <= data.count else { break }
            
            // Prüfe Signatur
            guard data[offset] == 0x50 && data[offset+1] == 0x4B && data[offset+2] == 0x01 && data[offset+3] == 0x02 else { break }
            
            let compressionMethod = Int(data[offset + 10]) | (Int(data[offset + 11]) << 8)
            let compressedSize = Int(data[offset + 20]) | (Int(data[offset + 21]) << 8) | (Int(data[offset + 22]) << 16) | (Int(data[offset + 23]) << 24)
            let uncompressedSize = Int(data[offset + 24]) | (Int(data[offset + 25]) << 8) | (Int(data[offset + 26]) << 16) | (Int(data[offset + 27]) << 24)
            let nameLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
            let extraLength = Int(data[offset + 30]) | (Int(data[offset + 31]) << 8)
            let commentLength = Int(data[offset + 32]) | (Int(data[offset + 33]) << 8)
            let localHeaderOffset = Int(data[offset + 42]) | (Int(data[offset + 43]) << 8) | (Int(data[offset + 44]) << 16) | (Int(data[offset + 45]) << 24)
            
            guard offset + 46 + nameLength <= data.count else { break }
            
            let nameData = data[offset + 46 ..< offset + 46 + nameLength]
            let name = String(data: nameData, encoding: .utf8) ?? ""
            
            let isDirectory = name.hasSuffix("/")
            let destinationPath = destURL.appendingPathComponent(name)
            
            if isDirectory {
                try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
            } else {
                // Erstelle übergeordnete Verzeichnisse
                try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Lese Datei-Daten aus Local File Header
                guard localHeaderOffset + 30 <= data.count else { continue }
                let localNameLength = Int(data[localHeaderOffset + 26]) | (Int(data[localHeaderOffset + 27]) << 8)
                let localExtraLength = Int(data[localHeaderOffset + 28]) | (Int(data[localHeaderOffset + 29]) << 8)
                
                let dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength
                
                if dataOffset + compressedSize <= data.count {
                    let compressedData = Data(data[dataOffset ..< dataOffset + compressedSize])
                    
                    var fileData: Data?
                    if compressionMethod == 0 {
                        // Stored (no compression)
                        fileData = compressedData
                    } else if compressionMethod == 8 {
                        // Deflate
                        fileData = decompressDeflate(compressedData, uncompressedSize: uncompressedSize)
                    }
                    
                    if let fileData = fileData {
                        try fileData.write(to: destinationPath)
                    }
                }
            }
            
            offset += 46 + nameLength + extraLength + commentLength
        }
    }
    
    private func decompressDeflate(_ data: Data, uncompressedSize: Int) -> Data? {
        // Verwende Compression Framework
        let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destBuffer.deallocate() }
        
        let decodedSize = data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = srcPtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                destBuffer,
                uncompressedSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard decodedSize > 0 else { return nil }
        return Data(bytes: destBuffer, count: decodedSize)
    }
    
    enum ImportError: LocalizedError {
        case noDataFile
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .noDataFile:
                return "Keine data.json in der ZIP-Datei gefunden"
            case .invalidFormat:
                return "Ungültiges Dateiformat"
            }
        }
    }
}
