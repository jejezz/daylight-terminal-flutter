import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Impeller is off by default (startup is ~3x slower with it). Set
    // DAYLIGHT_IMPELLER=1/true/on/yes to enable.
    let value = ProcessInfo.processInfo.environment["DAYLIGHT_IMPELLER"]?.lowercased() ?? ""
    let impeller = ["1", "true", "on", "yes"].contains(value)
    // The engine reads switches from FLUTTER_ENGINE_SWITCHES (set before the engine is created).
    setenv("FLUTTER_ENGINE_SWITCHES", "1", 1)
    setenv("FLUTTER_ENGINE_SWITCH_1", "enable-impeller=\(impeller)", 1)
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
