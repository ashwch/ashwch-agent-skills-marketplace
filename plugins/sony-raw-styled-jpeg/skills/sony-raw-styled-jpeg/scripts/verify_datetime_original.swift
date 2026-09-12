import Foundation
import ImageIO

/*
 EXIF integrity validator for Sony RAW -> JPEG pipeline.

 Guarantees:
 - Complete mode: every source ARW has a matching output JPEG.
 - Existing-only mode: every retained output JPEG has a matching source ARW.
 - Output JPEG preserves capture-time fields:
   - EXIF DateTimeOriginal
   - EXIF DateTimeDigitized
   - TIFF DateTime
 */

/// Load full image property dictionary via ImageIO.
func imageProperties(at path: String) -> [CFString: Any]? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        return nil
    }
    return properties
}

/// Extract relevant timestamp fields from EXIF/TIFF dictionaries.
func exifDates(_ properties: [CFString: Any]) -> (original: String?, digitized: String?, tiffDateTime: String?) {
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

    return (
        exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
        exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
        tiff?[kCGImagePropertyTIFFDateTime] as? String
    )
}

struct ImagePair {
    let source: URL
    let output: URL
}

/// Batch validator entry point.
func run() {
    let fileManager = FileManager.default
    let arguments = Array(CommandLine.arguments.dropFirst())
    let existingOnly = arguments.contains("--existing-only")
    let paths = arguments.filter { $0 != "--existing-only" }

    let inputDir = URL(
        fileURLWithPath: paths.first ?? fileManager.currentDirectoryPath,
        isDirectory: true
    )
    let outputDir = URL(
        fileURLWithPath: paths.dropFirst().first ?? inputDir.appendingPathComponent("codex_output", isDirectory: true).path,
        isDirectory: true
    )

    let allArwFiles: [URL]
    do {
        allArwFiles = try fileManager.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "arw" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        fputs("ERROR: unable to list input dir: \(error)\n", stderr)
        exit(1)
    }

    let outputFiles: [URL]
    do {
        outputFiles = try fileManager.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        fputs("ERROR: unable to list output dir: \(error)\n", stderr)
        exit(1)
    }

    let rawFilesByStem = Dictionary(grouping: allArwFiles) {
        $0.deletingPathExtension().lastPathComponent.lowercased()
    }
    let missingSourceRaw = outputFiles
        .filter { rawFilesByStem[$0.deletingPathExtension().lastPathComponent.lowercased()] == nil }
        .map(\.lastPathComponent)
    let ambiguousSourceRaw = rawFilesByStem.values
        .filter { $0.count > 1 }
        .flatMap { $0.map(\.lastPathComponent) }

    let imagePairs: [ImagePair]
    if existingOnly {
        imagePairs = outputFiles.compactMap { outputFile in
            let stem = outputFile.deletingPathExtension().lastPathComponent.lowercased()
            guard let matchingRawFiles = rawFilesByStem[stem], matchingRawFiles.count == 1 else {
                return nil
            }
            return ImagePair(source: matchingRawFiles[0], output: outputFile)
        }
    } else {
        imagePairs = allArwFiles.map { rawFile in
            let baseName = rawFile.deletingPathExtension().lastPathComponent
            let outputFile = outputDir.appendingPathComponent("\(baseName).jpg")
            return ImagePair(source: rawFile, output: outputFile)
        }
    }

    var missingOutput = [String]()
    var missingSourceProps = [String]()
    var missingOutputProps = [String]()
    var missingSourceDateOriginal = [String]()
    var missingOutputDateOriginal = [String]()
    var missingOutputDateDigitized = [String]()
    var missingOutputTIFFDateTime = [String]()
    var mismatchedDateOriginal = [(name: String, source: String, output: String)]()
    var mismatchedDateDigitized = [(name: String, source: String, output: String)]()
    var mismatchedTIFFDateTime = [(name: String, source: String, output: String)]()

    for imagePair in imagePairs {
        let arw = imagePair.source
        let jpg = imagePair.output
        let baseName = arw.deletingPathExtension().lastPathComponent

        if !fileManager.fileExists(atPath: jpg.path) {
            missingOutput.append(jpg.lastPathComponent)
            continue
        }

        guard let sourceProps = imageProperties(at: arw.path) else {
            missingSourceProps.append(arw.lastPathComponent)
            continue
        }

        guard let outputProps = imageProperties(at: jpg.path) else {
            missingOutputProps.append(jpg.lastPathComponent)
            continue
        }

        let sourceDates = exifDates(sourceProps)
        let outputDates = exifDates(outputProps)

        // DateTimeOriginal is the primary capture timestamp expected by DAM tools.
        if sourceDates.original == nil {
            missingSourceDateOriginal.append(arw.lastPathComponent)
        }
        if sourceDates.original != nil, outputDates.original == nil {
            missingOutputDateOriginal.append(jpg.lastPathComponent)
        }
        if sourceDates.digitized != nil, outputDates.digitized == nil {
            missingOutputDateDigitized.append(jpg.lastPathComponent)
        }
        if sourceDates.tiffDateTime != nil, outputDates.tiffDateTime == nil {
            missingOutputTIFFDateTime.append(jpg.lastPathComponent)
        }

        if let s = sourceDates.original, let o = outputDates.original, s != o {
            mismatchedDateOriginal.append((name: baseName, source: s, output: o))
        }

        if let s = sourceDates.digitized, let o = outputDates.digitized, s != o {
            mismatchedDateDigitized.append((name: baseName, source: s, output: o))
        }

        if let s = sourceDates.tiffDateTime, let o = outputDates.tiffDateTime, s != o {
            mismatchedTIFFDateTime.append((name: baseName, source: s, output: o))
        }
    }

    print("EXIF Validation Summary")
    print("Validation scope: \(existingOnly ? "existing outputs" : "complete export")")
    print("Input ARW files: \(allArwFiles.count)")
    print("Output JPEG files: \(outputFiles.count)")
    print("Matched RAW/JPEG pairs: \(imagePairs.count - missingOutput.count)")
    let matchedSourceNames = Set(imagePairs.map { $0.source.lastPathComponent.lowercased() })
    let sourceWithoutOutputCount = existingOnly ? allArwFiles.count - matchedSourceNames.count : missingOutput.count
    print("Source RAW files without output: \(sourceWithoutOutputCount)")
    print("Output JPEGs without source RAW: \(missingSourceRaw.count)")
    print("Ambiguous source RAW filenames: \(ambiguousSourceRaw.count)")
    print("Missing output JPEGs: \(missingOutput.count)")
    print("Missing source metadata payload: \(missingSourceProps.count)")
    print("Missing output metadata payload: \(missingOutputProps.count)")
    print("Missing source DateTimeOriginal: \(missingSourceDateOriginal.count)")
    print("Missing output DateTimeOriginal: \(missingOutputDateOriginal.count)")
    print("Missing output DateTimeDigitized: \(missingOutputDateDigitized.count)")
    print("Missing output TIFF DateTime: \(missingOutputTIFFDateTime.count)")
    print("Mismatched DateTimeOriginal: \(mismatchedDateOriginal.count)")
    print("Mismatched DateTimeDigitized: \(mismatchedDateDigitized.count)")
    print("Mismatched TIFF DateTime: \(mismatchedTIFFDateTime.count)")

    if !mismatchedDateOriginal.isEmpty {
        print("First DateTimeOriginal mismatch: \(mismatchedDateOriginal[0].name) src=\(mismatchedDateOriginal[0].source) out=\(mismatchedDateOriginal[0].output)")
    }

    if !imagePairs.isEmpty,
       missingSourceRaw.isEmpty,
       ambiguousSourceRaw.isEmpty,
       missingOutput.isEmpty,
       missingSourceProps.isEmpty,
       missingOutputProps.isEmpty,
       missingOutputDateOriginal.isEmpty,
       missingOutputDateDigitized.isEmpty,
       missingOutputTIFFDateTime.isEmpty,
       mismatchedDateOriginal.isEmpty,
       mismatchedDateDigitized.isEmpty,
       mismatchedTIFFDateTime.isEmpty {
        print("RESULT: PASS")
    } else {
        print("RESULT: FAIL")
        exit(2)
    }
}

run()
