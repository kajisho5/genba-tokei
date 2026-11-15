import SwiftUI

/// 設計書 5 章の配色
enum Palette {
    static let background = Color(red: 0x0B / 255, green: 0x0D / 255, blue: 0x10 / 255)
    static let text = Color(red: 0xF5 / 255, green: 0xF7 / 255, blue: 0xFA / 255)
    static let subText = Color(red: 0x8A / 255, green: 0x91 / 255, blue: 0x9C / 255)
    static let accent = Color(red: 0xFF / 255, green: 0xB0 / 255, blue: 0x20 / 255)
    static let ok = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let okText = Color(red: 0x7F / 255, green: 0xD4 / 255, blue: 0x9A / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
}

extension Palette {
    static let surface = Color(red: 0x16 / 255, green: 0x19 / 255, blue: 0x1E / 255)
    static let border = Color(red: 0x26 / 255, green: 0x2A / 255, blue: 0x31 / 255)
    static let warning = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x0A / 255)
}

extension Palette {
    static let okBackground = Color(red: 0x0F / 255, green: 0x24 / 255, blue: 0x17 / 255)
}

extension Palette {
    static let faint = Color(red: 0x5A / 255, green: 0x62 / 255, blue: 0x70 / 255)
}
