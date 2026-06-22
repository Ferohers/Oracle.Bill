import Foundation

struct OCIConfiguration: Equatable {
    var userId: String
    var fingerprint: String
    var tenancyId: String
    var region: String
    var keyFile: String?
}

enum OCIConfigurationParser {
    static func parse(_ text: String) throws -> OCIConfiguration {
        var values: [String: String] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("["), let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let commentStart = value.range(of: " #")?.lowerBound {
                value = value[..<commentStart].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            values[key] = value
        }

        guard let userId = values["user"], !userId.isEmpty else {
            throw OCIConfigurationError.missing("user")
        }
        guard let fingerprint = values["fingerprint"], !fingerprint.isEmpty else {
            throw OCIConfigurationError.missing("fingerprint")
        }
        guard let tenancyId = values["tenancy"], !tenancyId.isEmpty else {
            throw OCIConfigurationError.missing("tenancy")
        }
        guard let region = values["region"], !region.isEmpty else {
            throw OCIConfigurationError.missing("region")
        }

        return OCIConfiguration(
            userId: userId,
            fingerprint: fingerprint,
            tenancyId: tenancyId,
            region: region,
            keyFile: values["key_file"]
        )
    }
}

enum OCIConfigurationError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .missing(let field):
            "OCI config is missing \(field)."
        }
    }
}
