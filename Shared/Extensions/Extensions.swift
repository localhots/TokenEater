import SwiftUI

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    /// Returns a lighter version of this color by the given factor (0.0 – 1.0).
    func lighter(by amount: Double = 0.15) -> Color {
        let nsColor = NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        converted.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(
            hue: Double(h),
            saturation: Double(max(s - CGFloat(amount) * 0.3, 0)),
            brightness: Double(min(b + CGFloat(amount), 1.0)),
            opacity: Double(a)
        )
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Date Relative Format

extension Optional where Wrapped == Date {
    var widgetResetTimeFormatted: String {
        guard let date = self else { return "" }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return String(localized: "widget.soon") }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))" : "\(minutes) min"
    }

    var widgetResetDateFormatted: String {
        guard let date = self else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var msFormatted: String {
        let elapsed = Date().timeIntervalSince(self)
        if elapsed < 1 {
            return "\(Int(elapsed * 1000))ms"
        } else if elapsed < 60 {
            return String(format: "%.1fs", elapsed)
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: self, relativeTo: Date())
        }
    }
}
