import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Impeller is off by default (startup is ~3x slower with it). Set
    // DAYLIGHT_IMPELLER=1/true/on/yes to enable.
    let value = ProcessInfo.processInfo.environment["DAYLIGHT_IMPELLER"]?.lowercased() ?? ""
    let impeller = ["1", "true", "on", "yes"].contains(value)
    let project = FlutterDartProject()
    project.engineSwitches = ["enable-impeller=\(impeller)"]
    let flutterViewController = FlutterViewController(project: project)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
