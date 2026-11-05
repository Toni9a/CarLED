import Foundation

/// Command builder for ELK-BLEDOM / ELK-BLEDDM style LED controllers.
/// Every packet is 9 bytes: 0x7E, 7 payload bytes, 0xEF.
enum ELKProtocol {
    private static func frame(_ payload: [UInt8]) -> Data {
        precondition(payload.count == 7)
        return Data([0x7E] + payload + [0xEF])
    }

    static let powerOn  = frame([0x00, 0x04, 0xF0, 0x00, 0x01, 0xFF, 0x00])
    static let powerOff = frame([0x00, 0x04, 0x00, 0x00, 0x00, 0xFF, 0x00])

    static func colour(_ c: RGB) -> Data {
        frame([0x00, 0x05, 0x03, c.r, c.g, c.b, 0x00])
    }

    /// 0...100
    static func brightness(_ percent: Int) -> Data {
        frame([0x00, 0x01, UInt8(clamping: max(0, min(100, percent))), 0x00, 0x00, 0x00, 0x00])
    }

    /// 0...100 (higher = faster)
    static func speed(_ percent: Int) -> Data {
        frame([0x00, 0x02, UInt8(clamping: max(0, min(100, percent))), 0x00, 0x00, 0x00, 0x00])
    }

    static func effect(_ effect: LightEffect) -> Data {
        frame([0x00, 0x03, effect.rawValue, 0x03, 0x00, 0x00, 0x00])
    }
}
