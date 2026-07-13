//
//  ShipTripCloudSync.swift
//  ShipTrip
//

import CloudKit
import SwiftData

enum ShipTripCloudSync {
    static let containerIdentifier = "iCloud.com.andre.ShipTrip"

    static func persistentConfiguration(
        for schema: Schema,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ModelConfiguration {
        let isAutomatedTestStore = environment["XCTestConfigurationFilePath"] != nil
            || arguments.contains("-uiTestingResetAndLoadDemoData")
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            isAutomatedTestStore ? .none : .private(containerIdentifier)

        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )
    }

    static func accountStatus() async -> AccountStatus {
        do {
            switch try await CKContainer(identifier: containerIdentifier).accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .unknown
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            @unknown default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    enum AccountStatus: Equatable {
        case loading
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown

        var label: String {
            switch self {
            case .loading:
                String(localized: "Wird geprüft …")
            case .available:
                String(localized: "Angemeldet")
            case .noAccount:
                String(localized: "iCloud-Anmeldung nötig")
            case .restricted:
                String(localized: "Eingeschränkt")
            case .temporarilyUnavailable:
                String(localized: "Vorübergehend nicht verfügbar")
            case .unknown:
                String(localized: "Status nicht verfügbar")
            }
        }
    }
}
