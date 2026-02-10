import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/*
 Sony RAW -> Styled JPEG converter (deterministic pipeline)

 First-principles flow:
 1) Decode RAW correctly at full resolution.
 2) Measure scene features from a sampled raster (brightness, contrast, color bias, detail).
 3) Add semantic cues (faces + labels) to improve style selection.
 4) Apply a style-specific filter chain.
 5) Export high-quality JPEG with source metadata preserved.

 ASCII overview:
 +-------+   +------------+   +--------------+   +------------+   +------------+
 | ARW   |-> | RAW decode |-> | Scene stats  |-> | Style pick |-> | JPEG + EXIF|
 +-------+   +------------+   +--------------+   +------------+   +------------+
                                   + Vision cues +
 */

/// The fixed style buckets used by this pipeline.
enum StyleProfile: String {
    case portrait
    case landscape
    case lowLight
    case urban
    case balanced
}

/// Numeric scene descriptors used by the style classifier.
struct ImageStats {
    let avgLuma: Double
    let contrast: Double
    let avgSaturation: Double
    let warmRatio: Double
    let greenRatio: Double
    let blueRatio: Double
    let edgeStrength: Double
}

/// HSV saturation computed from normalized RGB components.
func hsvSaturation(r: Double, g: Double, b: Double) -> Double {
    let maxValue = max(r, max(g, b))
    let minValue = min(r, min(g, b))
    if maxValue <= 0.0 {
        return 0.0
    }
    return (maxValue - minValue) / maxValue
}

/// Hue in [0, 1) from normalized RGB; robust for threshold-based color tagging.
func hsvHue(r: Double, g: Double, b: Double) -> Double {
    let maxValue = max(r, max(g, b))
    let minValue = min(r, min(g, b))
    let delta = maxValue - minValue
    if delta == 0 {
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

/// Downsample and compute scene statistics for style selection.
func computeStats(from cgImage: CGImage) -> ImageStats {
    let targetMaxSide = 240
    let width = max(1, min(targetMaxSide, cgImage.width))
    let height = max(1, min(targetMaxSide, cgImage.height))
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        return ImageStats(avgLuma: 0.5, contrast: 0.15, avgSaturation: 0.15, warmRatio: 0.0, greenRatio: 0.0, blueRatio: 0.0, edgeStrength: 0.0)
    }

    var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return ImageStats(avgLuma: 0.5, contrast: 0.15, avgSaturation: 0.15, warmRatio: 0.0, greenRatio: 0.0, blueRatio: 0.0, edgeStrength: 0.0)
    }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var lumaGrid = [Double](repeating: 0.0, count: width * height)
    var sumLuma = 0.0
    var sumSqLuma = 0.0
    var sumSat = 0.0
    var warmCount = 0
    var greenCount = 0
    var blueCount = 0

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
        }
    }

    let pixelCount = Double(width * height)
    let avgLuma = sumLuma / pixelCount
    let variance = max(0.0, (sumSqLuma / pixelCount) - (avgLuma * avgLuma))
    let contrast = sqrt(variance)
    let avgSaturation = sumSat / pixelCount
    let warmRatio = Double(warmCount) / pixelCount
    let greenRatio = Double(greenCount) / pixelCount
    let blueRatio = Double(blueCount) / pixelCount

    var edgeAccum = 0.0
    var edgeSamples = 0
    if width > 1, height > 1 {
        for y in 1 ..< height {
            for x in 1 ..< width {
                let idx = y * width + x
                let l = lumaGrid[idx]
                let left = lumaGrid[idx - 1]
                let up = lumaGrid[idx - width]
                edgeAccum += abs(l - left) + abs(l - up)
                edgeSamples += 2
            }
        }
    }
    let edgeStrength = edgeSamples > 0 ? edgeAccum / Double(edgeSamples) : 0.0

    return ImageStats(
        avgLuma: avgLuma,
        contrast: contrast,
        avgSaturation: avgSaturation,
        warmRatio: warmRatio,
        greenRatio: greenRatio,
        blueRatio: blueRatio,
        edgeStrength: edgeStrength
    )
}

/// Apply one CoreImage filter and return original image if filter is unavailable.
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

/// Baseline auto corrections before style-specific grading.
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

/// Face count is a strong portrait prior.
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

/// Top-k semantic labels from Vision classifier (best-effort).
func classifyLabels(in cgImage: CGImage, topK: Int = 6) -> [String] {
    if #available(macOS 10.15, *) {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let labels = request.results?.prefix(topK).map(\.identifier) ?? []
            return labels.map { $0.lowercased() }
        } catch {
            return []
        }
    }
    return []
}

/// Helper for label keyword matching.
func containsAnyLabel(_ labels: [String], terms: [String]) -> Bool {
    for label in labels {
        for term in terms where label.contains(term) {
            return true
        }
    }
    return false
}

/// Rule-based style classifier.
/// Ordering is intentional: low-light first, portrait second, then landscape/urban fallback.
func chooseStyle(stats: ImageStats, faceCount: Int, labels: [String]) -> StyleProfile {
    let looksLandscape = containsAnyLabel(labels, terms: [
        "landscape", "mountain", "forest", "nature", "lake", "river", "waterfall", "beach",
        "sunrise", "sunset", "sky", "sea", "valley", "desert", "field", "hill"
    ])
    let looksUrban = containsAnyLabel(labels, terms: [
        "building", "city", "street", "architecture", "skyscraper", "bridge", "road", "tower"
    ])
    let looksPortrait = containsAnyLabel(labels, terms: [
        "person", "portrait", "selfie", "face", "child", "woman", "man", "people"
    ])

    if stats.avgLuma < 0.28 || (stats.avgLuma < 0.35 && stats.contrast < 0.11) {
        return .lowLight
    }

    if faceCount > 0 || looksPortrait || (stats.warmRatio > 0.11 && stats.avgLuma > 0.35 && stats.avgSaturation < 0.42) {
        return .portrait
    }

    if looksLandscape || ((stats.greenRatio + stats.blueRatio) > 0.50 && stats.edgeStrength > 0.055) {
        return .landscape
    }

    if looksUrban || (stats.contrast > 0.20 && stats.avgSaturation < 0.22) {
        return .urban
    }

    return .balanced
}

/// Fixed style recipes tuned for this project; keep unchanged for reproducibility.
func applyStyle(_ style: StyleProfile, to image: CIImage) -> CIImage {
    var out = image
    out = applyAutoEnhance(to: out)

    switch style {
    case .portrait:
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": 0.12])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": 0.38, "inputHighlightAmount": 0.93])
        out = applyFilter(name: "CIVibrance", to: out, parameters: ["inputAmount": 0.18])
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.06, "inputBrightness": 0.0, "inputContrast": 1.06])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.02, "inputSharpness": 0.35])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.34, "inputRadius": 0.8])

    case .landscape:
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": 0.08])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": 0.42, "inputHighlightAmount": 0.90])
        out = applyFilter(name: "CIVibrance", to: out, parameters: ["inputAmount": 0.36])
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.13, "inputBrightness": 0.0, "inputContrast": 1.10])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.48, "inputRadius": 1.0])

    case .lowLight:
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": 0.28])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": 0.62, "inputHighlightAmount": 0.95])
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.08, "inputBrightness": 0.0, "inputContrast": 1.03])
        out = applyFilter(name: "CINoiseReduction", to: out, parameters: ["inputNoiseLevel": 0.045, "inputSharpness": 0.30])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.24, "inputRadius": 0.9])

    case .urban:
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": 0.05])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": 0.32, "inputHighlightAmount": 0.88])
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.03, "inputBrightness": 0.0, "inputContrast": 1.14])
        out = applyFilter(name: "CIUnsharpMask", to: out, parameters: ["inputRadius": 1.8, "inputIntensity": 0.62])

    case .balanced:
        out = applyFilter(name: "CIExposureAdjust", to: out, parameters: ["inputEV": 0.08])
        out = applyFilter(name: "CIHighlightShadowAdjust", to: out, parameters: ["inputShadowAmount": 0.34, "inputHighlightAmount": 0.92])
        out = applyFilter(name: "CIVibrance", to: out, parameters: ["inputAmount": 0.22])
        out = applyFilter(name: "CIColorControls", to: out, parameters: ["inputSaturation": 1.08, "inputBrightness": 0.0, "inputContrast": 1.08])
        out = applyFilter(name: "CISharpenLuminance", to: out, parameters: ["inputSharpness": 0.35, "inputRadius": 0.9])
    }

    return out
}

/// Export JPEG with explicit quality and metadata payload.
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

/// Extract metadata dictionary from source image.
func sourceMetadata(for url: URL) -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let rawProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        return [:]
    }
    return rawProps
}

/// Convert one ARW file:
/// decode -> sample/analyze -> classify -> stylize -> write JPEG with metadata.
func processFile(
    inputURL: URL,
    outputURL: URL,
    context: CIContext
) -> (style: StyleProfile?, error: String?) {
    let options: [CIImageOption: Any] = [.applyOrientationProperty: true]
    guard var image = CIImage(contentsOf: inputURL, options: options) else {
        return (nil, "Unable to read RAW image")
    }

    if image.extent.isEmpty {
        return (nil, "RAW decode produced empty image")
    }

    // Stabilize edges and sampling footprint.
    image = image.clampedToExtent().cropped(to: image.extent)
    let sampleScale = min(1.0, 800.0 / max(image.extent.width, image.extent.height))
    let sampleImage = image.transformed(by: CGAffineTransform(scaleX: sampleScale, y: sampleScale))

    guard let sampleCG = context.createCGImage(sampleImage, from: sampleImage.extent) else {
        return (nil, "Unable to rasterize sample image")
    }

    let stats = computeStats(from: sampleCG)
    let faces = detectFaces(in: sampleCG)
    let labels = classifyLabels(in: sampleCG)
    let style = chooseStyle(stats: stats, faceCount: faces, labels: labels)
    let styledImage = applyStyle(style, to: image)

    guard let finalCG = context.createCGImage(styledImage, from: styledImage.extent) else {
        return (nil, "Unable to rasterize styled image")
    }

    let metadata = sourceMetadata(for: inputURL)
    let wrote = writeJPEG(cgImage: finalCG, to: outputURL, quality: 1.0, metadata: metadata)
    if !wrote {
        return (nil, "Failed writing JPEG")
    }

    return (style, nil)
}

/// Batch entry point for folder conversion.
func run() {
    let fileManager = FileManager.default
    let args = CommandLine.arguments

    let inputDir: URL
    if args.count >= 2 {
        inputDir = URL(fileURLWithPath: args[1], isDirectory: true)
    } else {
        inputDir = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    }

    let outputDir: URL
    if args.count >= 3 {
        outputDir = URL(fileURLWithPath: args[2], isDirectory: true)
    } else {
        outputDir = inputDir.appendingPathComponent("codex_output", isDirectory: true)
    }

    do {
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
    } catch {
        fputs("ERROR: cannot create output directory at \(outputDir.path): \(error)\n", stderr)
        exit(1)
    }

    let files: [URL]
    do {
        files = try fileManager.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "arw" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        fputs("ERROR: cannot list input directory \(inputDir.path): \(error)\n", stderr)
        exit(1)
    }

    if files.isEmpty {
        print("No .ARW files found in \(inputDir.path)")
        return
    }

    let context = CIContext(options: [
        .cacheIntermediates: false,
        .priorityRequestLow: true
    ])

    let reportURL = outputDir.appendingPathComponent("style_report.csv")
    let reportHeader = "file,style,status,error\n"
    _ = try? reportHeader.write(to: reportURL, atomically: true, encoding: .utf8)

    var successCount = 0
    var failureCount = 0
    var styleCounts: [StyleProfile: Int] = [:]

    for (index, inputURL) in files.enumerated() {
        // Keep memory stable on large batches.
        autoreleasepool {
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let outputURL = outputDir.appendingPathComponent("\(baseName).jpg")
            let result = processFile(inputURL: inputURL, outputURL: outputURL, context: context)

            if let style = result.style {
                successCount += 1
                styleCounts[style, default: 0] += 1
                print("[\(index + 1)/\(files.count)] \(inputURL.lastPathComponent) -> \(outputURL.lastPathComponent) (\(style.rawValue))")
                let csvLine = "\(inputURL.lastPathComponent),\(style.rawValue),ok,\n"
                if let handle = try? FileHandle(forWritingTo: reportURL) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    if let data = csvLine.data(using: .utf8) {
                        try? handle.write(contentsOf: data)
                    }
                }
            } else {
                failureCount += 1
                let message = result.error ?? "unknown error"
                print("[\(index + 1)/\(files.count)] \(inputURL.lastPathComponent) FAILED: \(message)")
                let escaped = message.replacingOccurrences(of: ",", with: ";")
                let csvLine = "\(inputURL.lastPathComponent),,failed,\(escaped)\n"
                if let handle = try? FileHandle(forWritingTo: reportURL) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    if let data = csvLine.data(using: .utf8) {
                        try? handle.write(contentsOf: data)
                    }
                }
            }
        }
    }

    print("Completed: \(successCount) succeeded, \(failureCount) failed")
    for style in [StyleProfile.portrait, .landscape, .lowLight, .urban, .balanced] {
        print("  \(style.rawValue): \(styleCounts[style, default: 0])")
    }
    print("Report: \(reportURL.path)")
}

run()
