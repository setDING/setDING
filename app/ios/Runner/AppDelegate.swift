import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The folder of the automatic backup (ADR-0054).
  private var backupFolder: BackupFolderChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupFolderChannel") {
      backupFolder = BackupFolderChannel(messenger: registrar.messenger())
    }
  }
}

/// The folder of the automatic backup (ADR-0054): a folder of the Files app
/// (iCloud Drive and other providers), chosen with the document picker and
/// kept with a security-scoped bookmark. The location is the bookmark in
/// Base64. Errors: `permission` when the bookmark no longer resolves,
/// `unavailable` when the folder cannot be reached, `failed` otherwise.
class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  private let queue = DispatchQueue(label: "app.setding.backup_folder")

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "app.setding/backup_folder", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private struct FolderError: Error {
    let code: String
    let message: String
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pick":
      pick(result: result)
    case "deviceName":
      result(UIDevice.current.name)
    case "list":
      background(result) {
        try self.withFolder(args) { folder in
          try FileManager.default.contentsOfDirectory(atPath: folder.path).filter {
            var dir: ObjCBool = false
            FileManager.default.fileExists(
              atPath: folder.appendingPathComponent($0).path, isDirectory: &dir)
            return !dir.boolValue
          }
        }
      }
    case "write":
      background(result) {
        guard let name = args["name"] as? String, let part = args["part"] as? String,
          let bytes = args["bytes"] as? FlutterStandardTypedData
        else { throw FolderError(code: "failed", message: "Bad arguments") }
        try self.withFolder(args) { folder in
          var failure: Error?
          var coordinatorError: NSError?
          NSFileCoordinator().coordinate(
            writingItemAt: folder, options: .forMerging, error: &coordinatorError
          ) { dir in
            let temp = dir.appendingPathComponent(part)
            let target = dir.appendingPathComponent(name)
            do {
              try bytes.data.write(to: temp)
              if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
              }
              try FileManager.default.moveItem(at: temp, to: target)
            } catch {
              failure = error
            }
          }
          if let error = coordinatorError ?? failure { throw error }
          return nil as Any?
        }
      }
    case "delete":
      background(result) {
        guard let name = args["name"] as? String else {
          throw FolderError(code: "failed", message: "Bad arguments")
        }
        try self.withFolder(args) { folder in
          let file = folder.appendingPathComponent(name)
          if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
          }
          return nil as Any?
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func background(_ result: @escaping FlutterResult, _ run: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try run()
        DispatchQueue.main.async { result(value) }
      } catch let error as FolderError {
        DispatchQueue.main.async {
          result(FlutterError(code: error.code, message: error.message, details: nil))
        }
      } catch {
        let code = (error as NSError).code == NSFileReadNoPermissionError
          || (error as NSError).code == NSFileWriteNoPermissionError ? "permission" : "failed"
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// Resolves the bookmark of [args] and runs [body] with access to it.
  private func withFolder<T>(_ args: [String: Any], _ body: (URL) throws -> T) throws -> T {
    guard let location = args["location"] as? String,
      let bookmark = Data(base64Encoded: location)
    else { throw FolderError(code: "failed", message: "Bad location") }
    var stale = false
    let folder: URL
    do {
      folder = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
    } catch {
      throw FolderError(code: "permission", message: error.localizedDescription)
    }
    guard folder.startAccessingSecurityScopedResource() else {
      throw FolderError(code: "permission", message: "No access to \(folder.lastPathComponent)")
    }
    defer { folder.stopAccessingSecurityScopedResource() }
    var dir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &dir), dir.boolValue
    else { throw FolderError(code: "unavailable", message: folder.lastPathComponent) }
    return try body(folder)
  }

  private func pick(result: @escaping FlutterResult) {
    pending?(nil)
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    guard let root = Self.topViewController() else {
      pending = nil
      result(FlutterError(code: "unavailable", message: "No view controller", details: nil))
      return
    }
    root.present(picker, animated: true)
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }
      .first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(
        options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["location": bookmark.base64EncodedString(), "name": url.lastPathComponent])
    } catch {
      result(FlutterError(code: "permission", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }
}
