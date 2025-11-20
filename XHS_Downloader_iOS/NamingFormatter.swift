import Foundation

struct NamingPreferences {
    static let enableKey = "use_custom_naming_format"
    static let templateKey = "custom_naming_template"

    let enabled: Bool
    let template: String

    static func load() -> NamingPreferences {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: enableKey)
        let template = defaults.string(forKey: templateKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTemplate = template?.isEmpty == false ? template! : NamingFormatter.defaultTemplate
        return NamingPreferences(enabled: enabled, template: finalTemplate)
    }
}

struct NoteMetadata {
    var userName: String?
    var userId: String?
    var title: String?
    var publishTime: String?
}

enum NamingFormatter {
    static let defaultTemplate = "{title}_{publishTime}_{downloadTimestamp}"

    private static let placeholderRegex = try! NSRegularExpression(pattern: "\\{([^}]+)\\}")

    static func makeBaseName(metadata: NoteMetadata,
                             fallbackPostId: String?,
                             index: Int,
                             downloadEpochSeconds: TimeInterval,
                             preferences: NamingPreferences) -> String {
        let indexPart = String(format: "%02d", max(index, 1))

        if preferences.enabled {
            let rendered = render(template: preferences.template,
                                  metadata: metadata,
                                  fallbackPostId: fallbackPostId,
                                  downloadEpochSeconds: downloadEpochSeconds,
                                  index: index,
                                  indexPart: indexPart)
            if let sanitized = sanitize(rendered), !sanitized.isEmpty {
                return sanitized + "_" + indexPart
            }
        }

        let fallback = fallbackPostId ?? metadata.title ?? metadata.userName ?? "xhs"
        let sanitizedFallback = sanitize(fallback) ?? "xhs"
        return sanitizedFallback + "_" + indexPart
    }

    private static func render(template: String,
                               metadata: NoteMetadata,
                               fallbackPostId: String?,
                               downloadEpochSeconds: TimeInterval,
                               index: Int,
                               indexPart: String) -> String {
        let range = NSRange(location: 0, length: (template as NSString).length)
        var result = template
        let matches = placeholderRegex.matches(in: template, options: [], range: range).reversed()
        for match in matches {
            guard match.numberOfRanges > 1,
                  let tokenRange = Range(match.range(at: 1), in: template) else { continue }
            let token = String(template[tokenRange])
            let replacement = replacementValue(for: token,
                                               metadata: metadata,
                                               fallbackPostId: fallbackPostId,
                                               downloadEpochSeconds: downloadEpochSeconds,
                                               index: index,
                                               indexPart: indexPart)
            if let rangeToReplace = Range(match.range, in: result) {
                result.replaceSubrange(rangeToReplace, with: replacement)
            }
        }
        return result
    }

    private static func replacementValue(for token: String,
                                         metadata: NoteMetadata,
                                         fallbackPostId: String?,
                                         downloadEpochSeconds: TimeInterval,
                                         index: Int,
                                         indexPart: String) -> String {
        switch token {
        case "username":
            return sanitize(metadata.userName) ?? ""
        case "userId":
            return sanitize(metadata.userId) ?? ""
        case "title":
            return sanitize(metadata.title) ?? ""
        case "postId":
            return sanitize(fallbackPostId) ?? ""
        case "publishTime":
            return sanitize(metadata.publishTime, allowHyphen: true) ?? ""
        case "index":
            return String(max(index, 1))
        case "index_padded":
            return indexPart
        case "downloadTimestamp":
            return String(Int(downloadEpochSeconds))
        default:
            return ""
        }
    }

    private static func sanitize(_ value: String?, allowHyphen: Bool = false) -> String? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let invalidCharacters: CharacterSet = {
            var set = CharacterSet(charactersIn: "\\/:*?\"<>|")
            if allowHyphen {
                set.remove(charactersIn: "-")
            }
            return set
        }()
        value = value.components(separatedBy: invalidCharacters).joined(separator: "_")
        value = value.replacingOccurrences(of: "[\\p{Cntrl}]", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
        value = value.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if value.count > 120 {
            value = String(value.prefix(120))
        }
        return value.isEmpty ? nil : value
    }
}
