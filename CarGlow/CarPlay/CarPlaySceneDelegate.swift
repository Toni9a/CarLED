import CarPlay
import UIKit

/// CarPlay "Driving Task" UI. Only runs once Apple grants the
/// com.apple.developer.carplay-driving-task entitlement (works in the CarPlay Simulator now).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var led: LEDController { LEDController.shared }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let tabs = CPTabBarTemplate(templates: [controlsTemplate(), effectsTemplate()])
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    // MARK: Templates

    private func controlsTemplate() -> CPListTemplate {
        let power = CPListSection(items: [
            item("Lights On", symbol: "lightbulb.fill") { $0.setPower(true) },
            item("Lights Off", symbol: "lightbulb.slash") { $0.setPower(false) },
        ], header: "Power", sectionIndexTitle: nil)

        let colours = CPListSection(items: LightColour.allCases.map { c in
            item(c.title, image: Self.swatch(c.rgb.uiColor)) { $0.setColour(c.rgb, throttle: false) }
        }, header: "Colour", sectionIndexTitle: nil)

        let brightness = CPListSection(items: [25, 50, 75, 100].map { pct in
            item("\(pct)%", symbol: "sun.max.fill") { led in
                if !led.isOn { led.setPower(true) }
                led.setBrightness(Double(pct))
            }
        }, header: "Brightness", sectionIndexTitle: nil)

        let t = CPListTemplate(title: "Lights", sections: [power, colours, brightness])
        t.tabTitle = "Lights"
        t.tabImage = UIImage(systemName: "lightbulb.led.wide.fill")
        return t
    }

    private func effectsTemplate() -> CPListTemplate {
        let sections = EffectGroup.allCases.map { group in
            CPListSection(items: LightEffect.allCases.filter { $0.group == group }.map { e in
                item(e.name, image: Self.swatch(UIColor(e.swatches.first ?? .white))) { $0.setEffect(e) }
            }, header: group.rawValue, sectionIndexTitle: nil)
        }
        let t = CPListTemplate(title: "Effects", sections: sections)
        t.tabTitle = "Effects"
        t.tabImage = UIImage(systemName: "sparkles")
        return t
    }

    // MARK: Helpers

    private func item(_ title: String, symbol: String, action: @escaping @MainActor (LEDController) -> Void) -> CPListItem {
        item(title, image: UIImage(systemName: symbol), action: action)
    }

    private func item(_ title: String, image: UIImage?, action: @escaping @MainActor (LEDController) -> Void) -> CPListItem {
        let i = CPListItem(text: title, detailText: nil, image: image)
        i.handler = { [weak self] _, completion in
            Task { @MainActor in
                do {
                    try await LEDController.shared.perform(timeout: 6, action)
                } catch {
                    self?.showError(error)
                }
                completion()
            }
        }
        return i
    }

    @MainActor
    private func showError(_ error: Error) {
        let alert = CPAlertTemplate(titleVariants: [error.localizedDescription, "Couldn't reach lights"],
                                    actions: [CPAlertAction(title: "OK", style: .cancel) { [weak self] _ in
                                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                                    }])
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    private static func swatch(_ colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { _ in
            colour.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 36, height: 36)).fill()
        }
    }
}
