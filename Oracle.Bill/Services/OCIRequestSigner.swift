import CryptoKit
import Foundation
import Security

struct OCIRequestSigner {
    var tenancyId: String
    var userId: String
    var fingerprint: String
    var privateKeyPEM: String

    func sign(_ request: inout URLRequest, body: Data) throws {
        guard let url = request.url, let host = url.host else {
            throw OCIRequestSigningError.invalidURL
        }

        let method = request.httpMethod?.lowercased() ?? "get"
        let path = url.path.isEmpty ? "/" : url.path
        let requestTarget = "\(method) \(path)\(url.query.map { "?\($0)" } ?? "")"
        let date = Self.httpDateFormatter.string(from: Date())
        let contentSHA256 = Data(SHA256.hash(data: body)).base64EncodedString()
        let contentType = "application/json"
        let contentLength = "\(body.count)"

        request.setValue(date, forHTTPHeaderField: "date")
        request.setValue(host, forHTTPHeaderField: "host")
        request.setValue(contentLength, forHTTPHeaderField: "content-length")
        request.setValue(contentType, forHTTPHeaderField: "content-type")
        request.setValue(contentSHA256, forHTTPHeaderField: "x-content-sha256")

        let signedHeaders = [
            "date",
            "(request-target)",
            "host",
            "content-length",
            "content-type",
            "x-content-sha256"
        ]
        let signingString = [
            "date: \(date)",
            "(request-target): \(requestTarget)",
            "host: \(host)",
            "content-length: \(contentLength)",
            "content-type: \(contentType)",
            "x-content-sha256: \(contentSHA256)"
        ].joined(separator: "\n")

        let privateKey = try PrivateKeyLoader.privateKey(fromPEM: privateKeyPEM)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            Data(signingString.utf8) as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? OCIRequestSigningError.signingFailed
        }

        let authorization = """
        Signature version="1",keyId="\(tenancyId)/\(userId)/\(fingerprint)",algorithm="rsa-sha256",headers="\(signedHeaders.joined(separator: " "))",signature="\(signature.base64EncodedString())"
        """
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()
}

private enum PrivateKeyLoader {
    static func privateKey(fromPEM pem: String) throws -> SecKey {
        let label = try pemLabel(from: pem)
        let der = try derData(fromPEM: pem)
        let keyData = label == "PRIVATE KEY" ? try unwrapPKCS8IfNeeded(der) : der
        return try makeSecKey(fromDER: keyData)
    }

    private static func pemLabel(from pem: String) throws -> String {
        guard let beginRange = pem.range(of: "-----BEGIN "),
              let labelEnd = pem[beginRange.upperBound...].range(of: "-----")?.lowerBound else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        return String(pem[beginRange.upperBound..<labelEnd])
    }

    private static func derData(fromPEM pem: String) throws -> Data {
        let lines = pem.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined()

        guard let data = Data(base64Encoded: lines) else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        return data
    }

    private static func makeSecKey(fromDER data: Data) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as Error? ?? OCIRequestSigningError.unsupportedPrivateKey
        }

        return key
    }

    private static func unwrapPKCS8IfNeeded(_ data: Data) throws -> Data {
        var reader = DERReader(data: data)
        let topLevel = try reader.readElement(expectedTag: 0x30)
        var sequence = DERReader(data: topLevel)
        _ = try sequence.readElement(expectedTag: 0x02)
        _ = try sequence.readElement(expectedTag: 0x30)
        return try sequence.readElement(expectedTag: 0x04)
    }
}

private struct DERReader {
    private var bytes: [UInt8]
    private var index = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    mutating func readElement(expectedTag: UInt8) throws -> Data {
        guard index < bytes.count, bytes[index] == expectedTag else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        index += 1
        let length = try readLength()
        guard index + length <= bytes.count else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        let value = Data(bytes[index..<(index + length)])
        index += length
        return value
    }

    private mutating func readLength() throws -> Int {
        guard index < bytes.count else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        let first = bytes[index]
        index += 1
        if first < 0x80 {
            return Int(first)
        }

        let byteCount = Int(first & 0x7f)
        guard byteCount > 0, byteCount <= 4, index + byteCount <= bytes.count else {
            throw OCIRequestSigningError.unsupportedPrivateKey
        }

        var length = 0
        for _ in 0..<byteCount {
            length = (length << 8) + Int(bytes[index])
            index += 1
        }
        return length
    }
}

enum OCIRequestSigningError: LocalizedError {
    case invalidURL
    case unsupportedPrivateKey
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The OCI request URL is invalid."
        case .unsupportedPrivateKey:
            "The private key must be an unencrypted PEM RSA key."
        case .signingFailed:
            "The OCI request could not be signed."
        }
    }
}
