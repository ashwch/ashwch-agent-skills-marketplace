import CoreGraphics
import CoreImage
import Foundation
import Vision

struct ImageStats {
    let avgLuma: Double
    let contrast: Double
    let avgSaturation: Double
    let warmRatio: Double
    let greenRatio: Double
    let blueRatio: Double
    let edgeStrength: Double
    let shadowRatio: Double
    let highlightRatio: Double
    let avgRed: Double
    let avgGreen: Double
    let avgBlue: Double
}

func hsvSaturation(r: Double, g: Double, b: Double) -> Double {
    let maxValue = max(r, max(g, b))
    let minValue = min(r, min(g, b))
    if maxValue <= 0.0 {
        return 0.0
    }
    return (maxValue - minValue) / maxValue
}

func hsvHue(r: Double, g: Double, b: Double) -> Double {
    let maxValue = max(r, max(g, b))
    let minValue = min(r, min(g, b))
    let delta = maxValue - minValue
    if delta == 0.0 {
        return 0.0
    }

    let hue: Double
    if maxValue == r {
        hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
    } else if maxValue == g {
        hue = ((b - r) / delta) + 2.0
    } else {
        hue = ((r - g) / delta) + 4.0
    }

    let normalized = hue / 6.0
    return normalized < 0 ? normalized + 1.0 : normalized
}

func computeStats(from cgImage: CGImage) -> ImageStats {
    let targetMaxSide = 320
    let width = max(1, min(targetMaxSide, cgImage.width))
    let height = max(1, min(targetMaxSide, cgImage.height))
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        return ImageStats(
            avgLuma: 0.5,
            contrast: 0.15,
            avgSaturation: 0.15,
            warmRatio: 0.0,
            greenRatio: 0.0,
            blueRatio: 0.0,
            edgeStrength: 0.0,
            shadowRatio: 0.0,
            highlightRatio: 0.0,
            avgRed: 0.0,
            avgGreen: 0.0,
            avgBlue: 0.0
        )
    }

    var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return ImageStats(
            avgLuma: 0.5,
            contrast: 0.15,
            avgSaturation: 0.15,
            warmRatio: 0.0,
            greenRatio: 0.0,
            blueRatio: 0.0,
            edgeStrength: 0.0,
            shadowRatio: 0.0,
            highlightRatio: 0.0,
            avgRed: 0.0,
            avgGreen: 0.0,
            avgBlue: 0.0
        )
    }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var lumaGrid = [Double](repeating: 0.0, count: width * height)
    var sumLuma = 0.0
    var sumSqLuma = 0.0
    var sumSat = 0.0
    var sumRed = 0.0
    var sumGreen = 0.0
    var sumBlue = 0.0
    var warmCount = 0
    var greenCount = 0
    var blueCount = 0
    var shadowCount = 0
    var highlightCount = 0

    for y in 0 ..< height {
        for x in 0 ..< width {
            let i = y * bytesPerRow + x * bytesPerPixel
            let r = Double(pixelData[i]) / 255.0
            let g = Double(pixelData[i + 1]) / 255.0
            let b = Double(pixelData[i + 2]) / 255.0
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let sat = hsvSaturation(r: r, g: g, b: b)
            let hue = hsvHue(r: r, g: g, b: b)

            sumLuma += luma
            sumSqLuma += luma * luma
            sumSat += sat
            sumRed += r
            sumGreen += g
            sumBlue += b
            lumaGrid[y * width + x] = luma

            if hue >= 0.03, hue <= 0.16, sat >= 0.22, luma >= 0.18 {
                warmCount += 1
            }
            if g > r * 1.08, g > b * 1.08 {
                greenCount += 1
            }
            if b > r * 1.08, b > g * 1.03 {
                blueCount += 1
            }
            if luma < 0.18 {
                shadowCount += 1
            }
            if luma > 0.82 {
                highlightCount += 1
            }
        }
    }

    let pixelCount = Double(width * height)
    let avgLuma = sumLuma / pixelCount
    let variance = max(0.0, (sumSqLuma / pixelCount) - (avgLuma * avgLuma))

    var edgeAccum = 0.0
    var edgeSamples = 0
    if width > 1, height > 1 {
        for y in 1 ..< height {
            for x in 1 ..< width {
                let idx = y * width + x
                let luma = lumaGrid[idx]
                edgeAccum += abs(luma - lumaGrid[idx - 1]) + abs(luma - lumaGrid[idx - width])
                edgeSamples += 2
            }
        }
    }

    return ImageStats(
        avgLuma: avgLuma,
        contrast: sqrt(variance),
        avgSaturation: sumSat / pixelCount,
        warmRatio: Double(warmCount) / pixelCount,
        greenRatio: Double(greenCount) / pixelCount,
        blueRatio: Double(blueCount) / pixelCount,
        edgeStrength: edgeSamples > 0 ? edgeAccum / Double(edgeSamples) : 0.0,
        shadowRatio: Double(shadowCount) / pixelCount,
        highlightRatio: Double(highlightCount) / pixelCount,
        avgRed: sumRed / pixelCount,
        avgGreen: sumGreen / pixelCount,
        avgBlue: sumBlue / pixelCount
    )
}

func detectFaces(in cgImage: CGImage) -> Int {
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
        return request.results?.count ?? 0
    } catch {
        return 0
    }
}

func classifyLabels(in cgImage: CGImage, topK: Int = 6) -> [String] {
    if #available(macOS 10.15, *) {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.prefix(topK).map { $0.identifier.lowercased() } ?? []
        } catch {
            return []
        }
    }
    return []
}

func containsAnyLabel(_ labels: [String], terms: [String]) -> Bool {
    for label in labels {
        for term in terms where label.contains(term) {
            return true
        }
    }
    return false
}

func chooseTreatment(stats: ImageStats, faces: Int, labels: [String]) -> (String, [String]) {
    let portraitLike = faces > 0 || containsAnyLabel(labels, terms: ["person", "portrait", "face", "hand"])
    let landscapeLike = containsAnyLabel(labels, terms: ["landscape", "nature", "sky", "cloud", "tree", "mountain", "water"])
    let detailLike = containsAnyLabel(labels, terms: ["leaf", "plant", "flower", "object"])

    let coolCast = stats.blueRatio > stats.warmRatio + 0.08 || stats.avgBlue > stats.avgRed * 1.10
    let darkShadows = stats.avgLuma < 0.42 || stats.shadowRatio > 0.30
    let deepBlueRisk = stats.blueRatio > 0.24 && stats.avgSaturation > 0.20
    let flat = stats.contrast < 0.12
    let brightSky = stats.highlightRatio > 0.10 && stats.blueRatio > 0.20
    let woodedShadow = stats.shadowRatio > 0.34 && stats.greenRatio > 0.12
    let overcastGray = flat && coolCast && stats.avgSaturation < 0.20

    var notes: [String] = []
    if coolCast { notes.append("cool_cast") }
    if darkShadows { notes.append("shadow_heavy") }
    if deepBlueRisk { notes.append("blue_overemphasis") }
    if flat { notes.append("flat_tone") }
    if stats.highlightRatio > 0.10 { notes.append("highlight_risk") }
    if woodedShadow { notes.append("wooded_shadow") }
    if overcastGray { notes.append("overcast_gray") }
    if brightSky { notes.append("bright_sky") }

    if detailLike && coolCast && stats.highlightRatio < 0.18 {
        return ("detail_chroma_cleanup", notes)
    }
    if landscapeLike && brightSky && (coolCast || deepBlueRisk) {
        return ("bright_sky_rebalance", notes)
    }
    if woodedShadow {
        return ("forest_shadow_lift", notes)
    }
    if overcastGray {
        return ("overcast_gray_recovery", notes)
    }
    if landscapeLike && (coolCast || deepBlueRisk) {
        return ("landscape_rebalance", notes)
    }
    if portraitLike && coolCast {
        return ("portrait_warmth_cleanup", notes)
    }
    if darkShadows {
        return ("shadow_lift", notes)
    }
    return ("balanced", notes)
}

func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

let fileManager = FileManager.default
let inputPath = CommandLine.arguments.dropFirst().first ?? fileManager.currentDirectoryPath
let inputDir = URL(fileURLWithPath: inputPath, isDirectory: true)
let outputDir = inputDir.appendingPathComponent("profiling", isDirectory: true)
let reportURL = outputDir.appendingPathComponent("raw_profile.csv")
let summaryURL = outputDir.appendingPathComponent("raw_profile_summary.txt")

try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

let files = try fileManager.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "arw" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

if files.isEmpty {
    fputs("ERROR: No .ARW files found in \(inputDir.path)\n", stderr)
    exit(1)
}

let context = CIContext(options: [
    .cacheIntermediates: false,
    .priorityRequestLow: true
])

var rows: [String] = []
rows.append("file,treatment,faces,avg_luma,contrast,shadow_ratio,highlight_ratio,avg_saturation,warm_ratio,blue_ratio,avg_red,avg_green,avg_blue,labels,notes")

var treatmentCounts: [String: Int] = [:]
var flaggedCool = 0
var flaggedDark = 0
var flaggedBlue = 0
var profileFailureCount = 0
var profileFailureMessages: [String] = []

for fileURL in files {
    autoreleasepool {
        guard var image = CIImage(contentsOf: fileURL, options: [.applyOrientationProperty: true]) else {
            let message = "\(fileURL.lastPathComponent): unable to read RAW image"
            profileFailureCount += 1
            profileFailureMessages.append(message)
            fputs("ERROR: \(message)\n", stderr)
            return
        }

        image = image.clampedToExtent().cropped(to: image.extent)
        let sampleScale = min(1.0, 900.0 / max(image.extent.width, image.extent.height))
        let sampleImage = image.transformed(by: CGAffineTransform(scaleX: sampleScale, y: sampleScale))

        guard let sampleCG = context.createCGImage(sampleImage, from: sampleImage.extent) else {
            let message = "\(fileURL.lastPathComponent): unable to rasterize sample image"
            profileFailureCount += 1
            profileFailureMessages.append(message)
            fputs("ERROR: \(message)\n", stderr)
            return
        }

        let stats = computeStats(from: sampleCG)
        let faces = detectFaces(in: sampleCG)
        let labels = classifyLabels(in: sampleCG)
        let result = chooseTreatment(stats: stats, faces: faces, labels: labels)
        let treatment = result.0
        let notes = result.1

        if notes.contains("cool_cast") { flaggedCool += 1 }
        if notes.contains("shadow_heavy") { flaggedDark += 1 }
        if notes.contains("blue_overemphasis") { flaggedBlue += 1 }
        treatmentCounts[treatment, default: 0] += 1

        let row = [
            fileURL.lastPathComponent,
            treatment,
            String(faces),
            String(format: "%.4f", stats.avgLuma),
            String(format: "%.4f", stats.contrast),
            String(format: "%.4f", stats.shadowRatio),
            String(format: "%.4f", stats.highlightRatio),
            String(format: "%.4f", stats.avgSaturation),
            String(format: "%.4f", stats.warmRatio),
            String(format: "%.4f", stats.blueRatio),
            String(format: "%.4f", stats.avgRed),
            String(format: "%.4f", stats.avgGreen),
            String(format: "%.4f", stats.avgBlue),
            labels.joined(separator: "|"),
            notes.joined(separator: "|")
        ].map(csvEscape).joined(separator: ",")

        rows.append(row)
        print("\(fileURL.lastPathComponent): \(treatment)")
    }
}

try rows.joined(separator: "\n").appending("\n").write(to: reportURL, atomically: true, encoding: .utf8)

var summary: [String] = []
summary.append("RAW profile summary")
summary.append("Input dir: \(inputDir.path)")
summary.append("Files profiled: \(files.count)")
summary.append("Cool-cast flags: \(flaggedCool)")
summary.append("Shadow-heavy flags: \(flaggedDark)")
summary.append("Blue-overemphasis flags: \(flaggedBlue)")
summary.append("Profile failures: \(profileFailureCount)")
if !profileFailureMessages.isEmpty {
    summary.append("")
    summary.append("Profile failures detail:")
    for message in profileFailureMessages {
        summary.append("  \(message)")
    }
}
summary.append("")
summary.append("Treatment groups:")
for key in treatmentCounts.keys.sorted() {
    summary.append("  \(key): \(treatmentCounts[key, default: 0])")
}

try summary.joined(separator: "\n").appending("\n").write(to: summaryURL, atomically: true, encoding: .utf8)

print("Profile CSV: \(reportURL.path)")
print("Summary: \(summaryURL.path)")

if profileFailureCount > 0 {
    fputs("ERROR: profiling failed for \(profileFailureCount) file(s). See \(summaryURL.path)\n", stderr)
    exit(2)
}
