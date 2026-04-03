import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProfileRow {
    let file: String
    let treatment: String
    let avgLuma: Double
    let contrast: Double
    let shadowRatio: Double
    let highlightRatio: Double
    let avgSaturation: Double
    let warmRatio: Double
    let blueRatio: Double
    let labels: [String]
}

func applyFilter(name: String, to inputImage: CIImage, parameters: [String: Any]) -> CIImage {
    guard let filter = CIFilter(name: name) else {
        return inputImage
    }
    filter.setValue(inputImage, forKey: kCIInputImageKey)
    for (key, value) in parameters {
        filter.setValue(value, forKey: key)
    }
    return filter.outputImage ?? inputImage
}

func applyAutoEnhance(to image: CIImage) -> CIImage {
    let options: [CIImageAutoAdjustmentOption: Any] = [
        .enhance: true,
        .redEye: false,
        .crop: false,
        .level: true
    ]
    let filters = image.autoAdjustmentFilters(options: options)
    var adjusted = image
    for filter in filters {
        filter.setValue(adjusted, forKey: kCIInputImageKey)
        if let output = filter.outputImage {
            adjusted = output
        }
    }
    return adjusted
}

func applyWarmBalance(to image: CIImage, warmth: Double, blueReduction: Double, bias: Double) -> CIImage {
    applyFilter(
        name: "CIColorMatrix",
        to: image,
        parameters: [
            "inputRVector": CIVector(x: 1.0 + warmth, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1.0 + warmth * 0.30, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: max(0.76, 1.0 - blueReduction), w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias, y: bias * 0.40, z: -bias * 0.18, w: 0)
        ]
    )
}

func containsAnyLabel(_ labels: [String], _ terms: [String]) -> Bool {
    for label in labels {
        for term in terms where label.contains(term) {
            return true
        }
    }
    return false
}

func moodMode(for profile: ProfileRow, preset: String) -> String? {
    guard preset == "subtle" else {
        return nil
    }

    if ["bright_sky_rebalance", "landscape_rebalance", "forest_shadow_lift"].contains(profile.treatment) {
        return "atmospheric"
    }

    if profile.treatment == "balanced",
       profile.avgLuma >= 0.50,
       profile.avgLuma <= 0.66,
       profile.highlightRatio <= 0.12,
       profile.contrast <= 0.18,
       profile.warmRatio >= profile.blueRatio + 0.08,
       containsAnyLabel(profile.labels, ["forest", "foliage", "vegetation", "wood_natural", "branch", "path", "trail", "plant"]) {
        return "forest_trail"
    }

    return nil
}

func applyMoodLayer(to image: CIImage, profile: ProfileRow, mode: String) -> CIImage {
    var out = image

    let highlightWeight = min(1.0, profile.highlightRatio / 0.22)
    let lumaWeight = min(1.0, max(0.0, profile.avgLuma - 0.42) / 0.22)

    if mode == "forest_trail" {
        let exposurePull = min(0.20, 0.10 + (lumaWeight * 0.05) + (highlightWeight * 0.03))
        let contrastBoost = 1.03 + (highlightWeight * 0.01)
        let saturationTrim = 0.95

        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": -exposurePull])
        out = applyFilter(name: "CIGammaAdjust", to: out, parameters: ["inputPower": 1.07])
        out = applyFilter(
            name: "CIColorControls",
            to: out,
            parameters: [
                "inputSaturation": saturationTrim,
                "inputBrightness": -0.004,
                "inputContrast": contrastBoost
            ]
        )
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.20, "inputRadius": 0.9])
        return out
    }

    let exposurePull = min(0.18, 0.07 + (highlightWeight * 0.05) + (lumaWeight * 0.04))
    let contrastBoost = 1.02 + (highlightWeight * 0.02)
    let saturationTrim = max(0.90, 0.97 - (highlightWeight * 0.03))

    out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": -exposurePull])
    out = applyFilter(
        name: "CIHighlightShadowAdjust",
        to: out,
        parameters: [
            "inputShadowAmount": 0.02,
            "inputHighlightAmount": 1.0
        ]
    )
    out = applyFilter(
        name: "CIColorControls",
        to: out,
        parameters: [
            "inputSaturation": saturationTrim,
            "inputBrightness": -0.002,
            "inputContrast": contrastBoost
        ]
    )

    return out
}

func sourceMetadata(for url: URL) -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let rawProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        return [:]
    }
    return rawProps
}

func writeJPEG(cgImage: CGImage, to url: URL, quality: CGFloat, metadata: [CFString: Any]) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        return false
    }

    var properties = metadata
    properties[kCGImageDestinationLossyCompressionQuality] = quality
    properties[kCGImagePropertyOrientation] = 1
    properties[kCGImagePropertyJFIFIsProgressive] = true

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    return CGImageDestinationFinalize(destination)
}

func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    var index = line.startIndex

    while index < line.endIndex {
        let char = line[index]
        if char == "\"" {
            let next = line.index(after: index)
            if inQuotes, next < line.endIndex, line[next] == "\"" {
                current.append("\"")
                index = line.index(after: next)
                continue
            }
            inQuotes.toggle()
            index = next
            continue
        }

        if char == ",", !inQuotes {
            fields.append(current)
            current = ""
            index = line.index(after: index)
            continue
        }

        current.append(char)
        index = line.index(after: index)
    }

    fields.append(current)
    return fields
}

func loadProfiles(from url: URL) throws -> [String: ProfileRow] {
    let text = try String(contentsOf: url, encoding: .utf8)
    var rows: [String: ProfileRow] = [:]
    for line in text.split(separator: "\n").dropFirst() {
        let parts = parseCSVLine(String(line))
        if parts.count < 15 {
            continue
        }
        let file = parts[0]
        rows[file] = ProfileRow(
            file: file,
            treatment: parts[1],
            avgLuma: Double(parts[3]) ?? 0.5,
            contrast: Double(parts[4]) ?? 0.15,
            shadowRatio: Double(parts[5]) ?? 0.0,
            highlightRatio: Double(parts[6]) ?? 0.0,
            avgSaturation: Double(parts[7]) ?? 0.15,
            warmRatio: Double(parts[8]) ?? 0.0,
            blueRatio: Double(parts[9]) ?? 0.0,
            labels: parts[13].split(separator: "|").map(String.init)
        )
    }
    return rows
}

func applyTreatment(_ profile: ProfileRow, to image: CIImage, moodPreset: String) -> CIImage {
    var out = applyAutoEnhance(to: image)
    let coolExcess = max(0.0, profile.blueRatio - profile.warmRatio)
    let lumaDeficit = max(0.0, 0.44 - profile.avgLuma)

    switch profile.treatment {
    case "shadow_lift":
        let exposure = min(0.42, 0.12 + (lumaDeficit * 0.85))
        let shadow = min(0.82, 0.46 + (profile.shadowRatio * 0.30))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.96])
        out = applyWarmBalance(to: out, warmth: 0.03, blueReduction: 0.04 + (coolExcess * 0.06), bias: 0.004 + (lumaDeficit * 0.010))
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.00, "inputBrightness": 0.0, "inputContrast": 1.01])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.035, "inputSharpness": 0.24])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.20, "inputRadius": 0.9])

    case "forest_shadow_lift":
        let exposure = min(0.36, 0.14 + (lumaDeficit * 0.70))
        let shadow = min(0.84, 0.54 + (profile.shadowRatio * 0.28))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.95])
        out = applyWarmBalance(to: out, warmth: 0.05, blueReduction: 0.06, bias: 0.006)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.03, "inputBrightness": 0.0, "inputContrast": 1.02])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.030, "inputSharpness": 0.24])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.22, "inputRadius": 0.9])

    case "bright_sky_rebalance":
        let exposure = min(0.20, 0.03 + (profile.shadowRatio * 0.34))
        let shadow = min(0.66, 0.28 + (profile.shadowRatio * 0.44))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.98])
        out = applyWarmBalance(to: out, warmth: 0.05, blueReduction: 0.10 + (coolExcess * 0.18), bias: 0.004)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 0.95, "inputBrightness": 0.0, "inputContrast": 1.03])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.018, "inputSharpness": 0.30])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.28, "inputRadius": 1.0])

    case "landscape_rebalance":
        let exposure = 0.08 + (lumaDeficit * 0.28)
        let shadow = 0.30 + (profile.shadowRatio * 0.30)
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.98])
        out = applyWarmBalance(to: out, warmth: 0.07, blueReduction: 0.14 + (coolExcess * 0.22), bias: 0.004)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 0.93, "inputBrightness": 0.0, "inputContrast": 1.03])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.016, "inputSharpness": 0.30])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.26, "inputRadius": 1.0])

    case "detail_chroma_cleanup":
        let exposure = min(0.26, 0.08 + (lumaDeficit * 0.40))
        let shadow = min(0.52, 0.22 + (profile.shadowRatio * 0.24))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.97])
        out = applyWarmBalance(to: out, warmth: 0.08, blueReduction: 0.18 + (coolExcess * 0.24), bias: 0.006)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 0.92, "inputBrightness": 0.0, "inputContrast": 1.02])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.055, "inputSharpness": 0.18])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.16, "inputRadius": 0.8])

    case "overcast_gray_recovery":
        let exposure = min(0.22, 0.08 + (lumaDeficit * 0.45))
        let shadow = min(0.54, 0.22 + (profile.shadowRatio * 0.26))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.96])
        out = applyWarmBalance(to: out, warmth: 0.04, blueReduction: 0.06 + (coolExcess * 0.08), bias: 0.004)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.02, "inputBrightness": 0.0, "inputContrast": 1.04])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.18, "inputRadius": 0.9])

    case "portrait_warmth_cleanup":
        let exposure = min(0.18, 0.04 + (lumaDeficit * 0.28))
        let shadow = min(0.48, 0.20 + (profile.shadowRatio * 0.22))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.95])
        out = applyWarmBalance(to: out, warmth: 0.06, blueReduction: 0.08 + (coolExcess * 0.10), bias: 0.004)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 0.98, "inputBrightness": 0.0, "inputContrast": 1.02])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.025, "inputSharpness": 0.24])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.20, "inputRadius": 0.8])

    default:
        let exposure = max(0.0, (0.42 - profile.avgLuma) * 0.18)
        let shadow = min(0.34, 0.16 + (profile.shadowRatio * 0.18))
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": exposure])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": shadow, "inputHighlightAmount": 0.95])
        out = applyWarmBalance(to: out, warmth: 0.015, blueReduction: min(0.04, coolExcess * 0.05), bias: 0.002)
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.00, "inputBrightness": 0.0, "inputContrast": 1.01])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.18, "inputRadius": 0.9])
    }

    if let mode = moodMode(for: profile, preset: moodPreset) {
        out = applyMoodLayer(to: out, profile: profile, mode: mode)
    }

    return out
}

func processFile(inputURL: URL, outputURL: URL, profile: ProfileRow, context: CIContext, moodPreset: String) -> (Bool, String?) {
    guard var image = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true]) else {
        return (false, "Unable to read RAW image")
    }

    if image.extent.isEmpty {
        return (false, "RAW decode produced empty image")
    }

    image = image.clampedToExtent().cropped(to: image.extent)
    let styled = applyTreatment(profile, to: image, moodPreset: moodPreset)

    guard let finalCG = context.createCGImage(styled, from: styled.extent) else {
        return (false, "Unable to rasterize styled image")
    }

    let metadata = sourceMetadata(for: inputURL)
    if !writeJPEG(cgImage: finalCG, to: outputURL, quality: 1.0, metadata: metadata) {
        return (false, "Failed writing JPEG")
    }

    return (true, nil)
}

let fileManager = FileManager.default
let args = CommandLine.arguments.dropFirst()
let inputDir = URL(fileURLWithPath: args.first ?? fileManager.currentDirectoryPath, isDirectory: true)
let outputDir = URL(
    fileURLWithPath: args.dropFirst().first ?? inputDir.appendingPathComponent("output", isDirectory: true).path,
    isDirectory: true
)
let moodPreset = args.dropFirst(2).first ?? "none"
if moodPreset != "none", moodPreset != "subtle" {
    fputs("ERROR: mood preset must be 'none' or 'subtle'\n", stderr)
    exit(2)
}

let profileURL = inputDir.appendingPathComponent("profiling/raw_profile.csv")
let profiles = try loadProfiles(from: profileURL)
let context = CIContext(options: [
    .cacheIntermediates: false,
    .priorityRequestLow: true
])

try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

let files = try fileManager.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "arw" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

let reportURL = outputDir.appendingPathComponent("profiled_style_report.csv")
try "file,treatment,mood_mode,status,error\n".write(to: reportURL, atomically: true, encoding: .utf8)

var success = 0
var failure = 0

for (index, inputURL) in files.enumerated() {
    autoreleasepool {
        guard let profile = profiles[inputURL.lastPathComponent] else {
            failure += 1
            let line = "\(inputURL.lastPathComponent),,none,failed,missing profile\n"
            if let handle = try? FileHandle(forWritingTo: reportURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            }
            print("[\(index + 1)/\(files.count)] \(inputURL.lastPathComponent) FAILED: missing profile")
            return
        }

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = outputDir.appendingPathComponent("\(baseName).jpg")
        let moodModeValue = moodMode(for: profile, preset: moodPreset) ?? "none"
        let result = processFile(
            inputURL: inputURL,
            outputURL: outputURL,
            profile: profile,
            context: context,
            moodPreset: moodPreset
        )
        if result.0 {
            success += 1
            let line = "\(inputURL.lastPathComponent),\(profile.treatment),\(moodModeValue),ok,\n"
            if let handle = try? FileHandle(forWritingTo: reportURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            }
            let moodTag = moodModeValue == "none" ? "" : " + \(moodModeValue)"
            print("[\(index + 1)/\(files.count)] \(inputURL.lastPathComponent) -> \(outputURL.lastPathComponent) (\(profile.treatment)\(moodTag))")
        } else {
            failure += 1
            let error = result.1 ?? "unknown error"
            let line = "\(inputURL.lastPathComponent),\(profile.treatment),\(moodModeValue),failed,\(error.replacingOccurrences(of: ",", with: ";"))\n"
            if let handle = try? FileHandle(forWritingTo: reportURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            }
            print("[\(index + 1)/\(files.count)] \(inputURL.lastPathComponent) FAILED: \(error)")
        }
    }
}

print("Completed: \(success) succeeded, \(failure) failed")
print("Report: \(reportURL.path)")

if failure > 0 {
    exit(2)
}
