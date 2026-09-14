//
//  ShareViewController.swift
//  ShipTripShare
//
//  Die Share-Extension nimmt genau eine `.shiptrip`-Datei aus dem Teilen-Sheet
//  entgegen und legt sie im Uebergabeordner der App Group ab (ADR-010, H4/H5).
//  Sie importiert nichts und zeigt keine Vorschau — das macht die App beim
//  naechsten Vordergrund-Scan. Bewusst UIKit ohne Storyboard: der Bildschirm ist
//  ein Statustext mit Schliessen-Knopf.
//

import UIKit
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Ergebnis der Uebergabe

/// Ausgang des Kopiervorgangs. Bestimmt Text und Abschlussart (`complete` vs.
/// `cancel`) — mehr Zustaende braucht die Extension nicht.
private enum HandoffOutcome: Sendable {
    case success
    case tooLarge
    case failed
}

// MARK: - Ablage im App-Group-Container

/// Typbezeichner der geteilten Kreuzfahrt. Die App deklariert ihn exportiert,
/// die Extension importiert ihn (H4).
private let cruiseTypeIdentifier = "com.andre.shiptrip.cruise"

/// Kopiert die gelieferte Repraesentation nach `<AppGroup>/ShareInbox/<UUID>.shiptrip`.
///
/// Bewusst eine freie Funktion und nicht Teil des View-Controllers: sie laeuft
/// **synchron im Completion-Handler** von `loadFileRepresentation`, weil das
/// Loeschverhalten der Temp-Datei danach nicht zugesichert ist (ADR-010, H4).
/// Reihenfolge nach H2: Ordner anlegen, abgelaufene Dateien raeumen, in eine
/// `.tmp` kopieren, dann atomar auf den Zielnamen verschieben.
private func storeHandoff(from source: URL) -> HandoffOutcome {
    guard let inbox = ShareHandoffStore.inboxURL() else { return .failed }
    guard let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
        return .failed
    }
    guard size <= ShareArchiveLimits.maxArchiveFileSize else { return .tooLarge }

    let manager = FileManager.default
    guard (try? manager.createDirectory(at: inbox, withIntermediateDirectories: true)) != nil else {
        return .failed
    }
    ShareHandoffStore.removeStaleFiles(in: inbox)

    let name = UUID().uuidString
    let temporary = inbox.appendingPathComponent("\(name).tmp", isDirectory: false)
    let destination = inbox.appendingPathComponent(
        "\(name).\(ShareHandoffStore.fileExtension)",
        isDirectory: false
    )
    do {
        try manager.copyItem(at: source, to: temporary)
        try manager.moveItem(at: temporary, to: destination)
        return .success
    } catch {
        try? manager.removeItem(at: temporary)
        return .failed
    }
}

// MARK: - Extension-Bildschirm

/// Principal Class der Extension (`NSExtensionPrincipalClass`, siehe `Info.plist`).
final class ShareViewController: UIViewController {

    private let statusLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    /// Steht fest, sobald der Kopiervorgang durch ist; steuert den Knopfdruck.
    private var outcome: HandoffOutcome?

    // MARK: Lebenszyklus

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()
        loadAttachment()
    }

    // MARK: Aufbau

    private func setUpLayout() {
        view.backgroundColor = .systemBackground

        statusLabel.text = String(localized: "handoff.progress")
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        closeButton.setTitle(String(localized: "handoff.close"), for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        closeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        closeButton.isHidden = true
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, closeButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    // MARK: Anhang laden

    /// Waehlt den passenden Anhang ueber den Typbezeichner (nie ueber den Index)
    /// und laedt ihn als Datei-Repraesentation.
    private func loadAttachment() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(cruiseTypeIdentifier)
              }),
              let contentType = UTType(cruiseTypeIdentifier) else {
            show(.failed)
            return
        }

        _ = provider.loadFileRepresentation(for: contentType, openInPlace: false) { url, _, _ in
            let outcome = url.map(storeHandoff(from:)) ?? .failed
            Task { @MainActor in self.show(outcome) }
        }
    }

    // MARK: Abschluss

    /// Zeigt das Ergebnis an und plant bei Erfolg die lokale Mitteilung (H5).
    private func show(_ outcome: HandoffOutcome) {
        self.outcome = outcome
        statusLabel.text = switch outcome {
        case .success: String(localized: "handoff.done")
        case .tooLarge: String(localized: "handoff.tooLarge")
        case .failed: String(localized: "handoff.failed")
        }
        closeButton.isHidden = false

        guard outcome == .success else { return }
        Task { await Self.scheduleHandoffNotification() }
    }

    @objc private func closeTapped() {
        guard let context = extensionContext else { return }
        if outcome == .success {
            context.completeRequest(returningItems: nil)
        } else {
            context.cancelRequest(withError: CocoaError(.fileWriteUnknown))
        }
    }

    /// Best-effort-Hinweis, dass eine Reise wartet. Nur bei bereits erteilter
    /// Berechtigung — die Extension fragt selbst keine an. Fester Identifier:
    /// eine zweite Uebergabe ersetzt die Mitteilung, statt sie zu stapeln; das
    /// Praefix ist bewusst nicht `reminder.`, damit der `NotificationReconciler`
    /// der App sie nie anfasst.
    private static func scheduleHandoffNotification() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "handoff.notification.title")
        content.body = String(localized: "handoff.notification.body")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "share.handoff",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
