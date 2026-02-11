import Foundation
import ImageIO

/*
 EXIF integrity validator for Sony RAW -> JPEG pipeline.

 Guarantees:
 - Every source ARW has a matching output JPEG.
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

/// Batch validator entry point.
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

    let arwFiles: [URL]
    do {
        arwFiles = try fileManager.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "arw" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        fputs("ERROR: unable to list input dir: \(error)\n", stderr)
        exit(1)
    }

    var missingOutput = [String]()
    var missingSourceProps = [String]()
    var missingOutputProps = [String]()
    var missingSourceDateOriginal = [String]()
    var missingOutputDateOriginal = [String]()
    var mismatchedDateOriginal = [(name: String, source: String, output: String)]()
    var mismatchedDateDigitized = [(name: String, source: String, output: String)]()
    var mismatchedTIFFDateTime = [(name: String, source: String, output: String)]()

    for arw in arwFiles {
        let baseName = arw.deletingPathExtension().lastPathComponent
        let jpg = outputDir.appendingPathComponent("\(baseName).jpg")

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
        if outputDates.original == nil {
            missingOutputDateOriginal.append(jpg.lastPathComponent)
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
    print("Input ARW files: \(arwFiles.count)")
    print("Missing output JPEGs: \(missingOutput.count)")
    print("Missing source metadata payload: \(missingSourceProps.count)")
    print("Missing output metadata payload: \(missingOutputProps.count)")
    print("Missing source DateTimeOriginal: \(missingSourceDateOriginal.count)")
    print("Missing output DateTimeOriginal: \(missingOutputDateOriginal.count)")
    print("Mismatched DateTimeOriginal: \(mismatchedDateOriginal.count)")
    print("Mismatched DateTimeDigitized: \(mismatchedDateDigitized.count)")
    print("Mismatched TIFF DateTime: \(mismatchedTIFFDateTime.count)")

    if !mismatchedDateOriginal.isEmpty {
        print("First DateTimeOriginal mismatch: \(mismatchedDateOriginal[0].name) src=\(mismatchedDateOriginal[0].source) out=\(mismatchedDateOriginal[0].output)")
    }

    if missingOutput.isEmpty,
       missingSourceProps.isEmpty,
       missingOutputProps.isEmpty,
       missingOutputDateOriginal.isEmpty,
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
