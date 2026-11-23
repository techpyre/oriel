import Foundation
import AppKit
import SwiftUI
import CoreImage

// MARK: - Color Tokens

public enum OrielColors {
    public static let accent = Color(red: 0.1765, green: 0.8314, blue: 0.7490) // #2DD4BF
    public static let charging = Color(red: 0.5529, green: 0.9216, blue: 0.5725) // #8CEB92
    public static let lowBattery = Color(red: 0.9804, green: 0.3882, blue: 0.4588) // #FA6375

    public static let amber = Color(red: 0.9608, green: 0.6196, blue: 0.0431)
    public static let amberBright = Color(red: 0.9843, green: 0.7647, blue: 0.2157)
    public static let amberBrighter = Color(red: 0.9882, green: 0.8275, blue: 0.3020)
    public static let apricot = Color(red: 0.8784, green: 0.6118, blue: 0.4235)
    public static let coral = Color(red: 0.9490, green: 0.5490, blue: 0.3804)
    public static let emerald = Color(red: 0.0627, green: 0.7255, blue: 0.5059)
    public static let fuchsia = Color(red: 0.8510, green: 0.2745, blue: 0.9373)
    public static let fuchsiaBright = Color(red: 0.9412, green: 0.6706, blue: 0.9882)
    public static let green = Color(red: 0.2902, green: 0.8706, blue: 0.5020)
    public static let indigo = Color(red: 0.3882, green: 0.4000, blue: 0.9451)
    public static let orange = Color(red: 0.9843, green: 0.5725, blue: 0.2353)
    public static let orangeBright = Color(red: 1.0000, green: 0.9294, blue: 0.8353)
    public static let orangeDark = Color(red: 0.2627, green: 0.0784, blue: 0.0275)
    public static let pink = Color(red: 0.7961, green: 0.4000, blue: 0.8510)
    public static let purple = Color(red: 0.6588, green: 0.3333, blue: 0.9686)
    public static let rose = Color(red: 0.9569, green: 0.2471, blue: 0.3686)
    public static let roseBright = Color(red: 0.9843, green: 0.4431, blue: 0.5216)
    public static let sky = Color(red: 0.0549, green: 0.6471, blue: 0.9137)
    public static let skyBright = Color(red: 0.4902, green: 0.8275, blue: 0.9882)
    public static let skyDark = Color(red: 0.1451, green: 0.3882, blue: 0.9216)
    public static let slate = Color(red: 0.3922, green: 0.4549, blue: 0.5451)
    public static let teal = Color(red: 0.0784, green: 0.7216, blue: 0.6510)
    public static let violet = Color(red: 0.5451, green: 0.3608, blue: 0.9647)

    // Adaptive surface tokens
    public static func containerBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.075) : Color.black.opacity(0.025)
    }

    public static func containerLightBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025)
    }

    public static func containerInnerBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.clear
    }

    public static func containerOuterBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.08)
    }

    public static func borderedButtonBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }

    public static func borderedButtonFocusBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    public static func borderedButtonInnerBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    public static func segmentedButtonBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    public static func segmentedButtonFocusBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    public static func color(fromHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return accent
    }

    public static func hexString(from nsColor: NSColor) -> String {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }

    public static func tintColor(named name: String) -> Color {
        switch name.lowercased() {
        case "systemindigo", "systemindigocolor", "indigo": return indigo
        case "systempurple", "systempurplecolor", "purple": return purple
        case "systemblue", "systembluecolor", "blue": return sky
        case "systemteal", "systemtealcolor", "teal": return teal
        case "systemgreen", "systemgreencolor", "green": return green
        case "systemorange", "systemorangecolor", "orange": return orange
        case "systemyellow", "systemyellowcolor", "yellow": return amber
        case "systempink", "systempinkcolor", "pink": return rose
        case "systemred", "systemredcolor", "red": return lowBattery
        case "systembrown", "systembrowncolor", "brown": return apricot
        default: return indigo
        }
    }
}

// MARK: - Dominant Color Extractor (k-means & brightness boost)

public enum DominantColorExtractor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public static func extractColors(from imageData: Data, count: Int = 2) -> [Color] {
        guard let nsImage = NSImage(data: imageData) else { return [OrielColors.accent, .white] }
        return extractColors(from: nsImage, count: count)
    }

    public static func extractColors(from image: NSImage, count: Int = 2) -> [Color] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return [OrielColors.accent, .white]
        }
        return extractColors(from: cgImage, count: count)
    }

    public static func extractColors(from cgImage: CGImage, count: Int = 2) -> [Color] {
        let size = 24
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return [OrielColors.accent, .white]
        }

        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let rawPtr = ctx.data else { return [OrielColors.accent, .white] }
        let pixels = rawPtr.bindMemory(to: UInt8.self, capacity: size * size * 4)

        struct RGBSample {
            var r: Double
            var g: Double
            var b: Double
            var saturation: Double
        }

        var samples: [RGBSample] = []
        samples.reserveCapacity(size * size)
        for i in 0..<(size * size) {
            let idx = i * 4
            let a = Double(pixels[idx + 3]) / 255.0
            if a < 0.25 { continue }
            let r = Double(pixels[idx]) / 255.0
            let g = Double(pixels[idx + 1]) / 255.0
            let b = Double(pixels[idx + 2]) / 255.0
            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let sat = maxC > 0 ? (maxC - minC) / maxC : 0
            // Filter extreme near-black / near-white unless nothing else exists
            if maxC > 0.12 && minC < 0.92 {
                samples.append(RGBSample(r: r, g: g, b: b, saturation: sat))
            }
        }

        if samples.isEmpty {
            return [.white, OrielColors.accent]
        }

        let k = min(max(1, count), samples.count)
        // Initialize centroids spread across sorted-by-saturation samples
        let sorted = samples.sorted { $0.saturation > $1.saturation }
        var centroids: [(Double, Double, Double)] = (0..<k).map { idx in
            let s = sorted[(idx * sorted.count) / k]
            return (s.r, s.g, s.b)
        }

        var assignments = [Int](repeating: 0, count: samples.count)
        for _ in 0..<6 {
            for i in 0..<samples.count {
                let s = samples[i]
                var bestIdx = 0
                var bestDist = Double.greatestFiniteMagnitude
                for cIdx in 0..<k {
                    let c = centroids[cIdx]
                    let dr = s.r - c.0
                    let dg = s.g - c.1
                    let db = s.b - c.2
                    let d = dr * dr + dg * dg + db * db
                    if d < bestDist {
                        bestDist = d
                        bestIdx = cIdx
                    }
                }
                assignments[i] = bestIdx
            }

            var sums = [(Double, Double, Double, Int)](repeating: (0, 0, 0, 0), count: k)
            for i in 0..<samples.count {
                let c = assignments[i]
                sums[c].0 += samples[i].r
                sums[c].1 += samples[i].g
                sums[c].2 += samples[i].b
                sums[c].3 += 1
            }
            for cIdx in 0..<k where sums[cIdx].3 > 0 {
                let n = Double(sums[cIdx].3)
                centroids[cIdx] = (sums[cIdx].0 / n, sums[cIdx].1 / n, sums[cIdx].2 / n)
            }
        }

        // Boost luminance for dark colors so waveforms stay visible against matte black notch
        let boosted: [Color] = centroids.map { (r, g, b) in
            let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let boost = lum < 0.35 ? (0.35 - lum) * 0.85 : 0.0
            return Color(
                red: min(1.0, r + boost),
                green: min(1.0, g + boost),
                blue: min(1.0, b + boost)
            )
        }
        return boosted
    }

    public static func brightenDarkPixelsFilterKernel() -> CIColorKernel? {
        let source = """
        kernel vec4 brightenDarkPixels(__sample s, float threshold, float boost) {
            float luminance = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
            if (luminance < threshold) {
                vec3 brighter = s.rgb + vec3(boost);
                return vec4(min(brighter, 1.0), s.a);
            }
            return s;
        }
        """
        return CIColorKernel(source: source)
    }
}
