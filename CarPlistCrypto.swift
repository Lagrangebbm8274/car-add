import Foundation

enum CarPlistError: LocalizedError {
    case invalidPlist, noCars, duplicate(String), malformed(String), checksum(String)
    var errorDescription: String? {
        switch self {
        case .invalidPlist: return "无法读取有效的 plist 字典。"
        case .noCars: return "没有识别到 CAR_n 车辆记录。"
        case .duplicate(let name): return "车辆已存在：\(name)"
        case .malformed(let key): return "车辆记录格式无法识别：\(key)"
        case .checksum(let key): return "车辆记录校验失败：\(key)"
        }
    }
}

struct CarRecord: Identifiable {
    let id: Int
    let name: String
    var keyName: String { "CAR_\(id)" }
}

enum CarPlistCrypto {
    private static let defaultKey = Array("e806f6".utf8)
    private static let marker: [UInt8] = [0x0F, 0x02, 0x00]

    static func read(_ data: Data) throws -> ([String: Any], [CarRecord]) {
        guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw CarPlistError.invalidPlist
        }
        var records: [CarRecord] = []
        for (encodedKey, encodedValue) in dict {
            guard let plainKey = decryptKey(encodedKey),
                  let match = plainKey.range(of: #"^CAR_(\d+)$"#, options: .regularExpression),
                  let number = Int(plainKey[match].dropFirst(4)),
                  let value = encodedValue as? String else { continue }
            guard let name = decryptValue(value, carKey: plainKey) else { throw CarPlistError.malformed(plainKey) }
            records.append(CarRecord(id: number, name: name))
        }
        records.sort { $0.id < $1.id }
        return (dict, records)
    }

    static func adding(_ name: String, to data: Data) throws -> (Data, CarRecord) {
        let (dict, cars) = try read(data)
        guard !cars.isEmpty else { throw CarPlistError.noCars }
        guard !cars.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw CarPlistError.duplicate(name)
        }
        let nextID = (cars.map(\.id).max() ?? -1) + 1
        let carKey = "CAR_\(nextID)"
        var updated = dict
        let encryptedKey = encryptKey(carKey)
        guard updated[encryptedKey] == nil else { throw CarPlistError.malformed(carKey) }
        updated[encryptedKey] = encryptValue(name, carKey: carKey)
        let output = try PropertyListSerialization.data(fromPropertyList: updated, format: .xml, options: 0)
        // Re-open and verify the exact newly added record before returning it.
        let (_, verifiedCars) = try read(output)
        guard verifiedCars.contains(where: { $0.id == nextID && $0.name == name }) else {
            throw CarPlistError.checksum(carKey)
        }
        return (output, CarRecord(id: nextID, name: name))
    }

    private static func xor(_ bytes: [UInt8], with key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return bytes }
        return bytes.enumerated().map { $0.element ^ key[$0.offset % key.count] }
    }
    private static func encryptKey(_ key: String) -> String {
        Data(xor(Array(key.utf8), with: defaultKey)).base64EncodedString()
    }
    private static func decryptKey(_ encoded: String) -> String? {
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(bytes: xor(Array(data), with: defaultKey), encoding: .utf8)
    }
    private static func valueKey(_ carKey: String) -> [UInt8] { Array((carKey + "e806f6").utf8) }
    private static func encryptValue(_ value: String, carKey: String) -> String {
        let plain = Array(value.utf8)
        let encrypted = xor(plain, with: valueKey(carKey))
        let hash = XXHash32.hash(plain)
        var payload = encrypted + marker
        payload += [UInt8(hash & 0xff), UInt8((hash >> 8) & 0xff), UInt8((hash >> 16) & 0xff), UInt8((hash >> 24) & 0xff)]
        return Data(payload).base64EncodedString()
    }
    private static func decryptValue(_ encoded: String, carKey: String) -> String? {
        guard let data = Data(base64Encoded: encoded) else { return nil }
        let bytes = Array(data)
        guard bytes.count >= 7 else { return nil }
        let split = bytes.count - 7
        guard Array(bytes[split..<(split + 3)]) == marker else { return nil }
        let plainBytes = xor(Array(bytes[..<split]), with: valueKey(carKey))
        let expected = UInt32(bytes[split + 3]) | (UInt32(bytes[split + 4]) << 8) | (UInt32(bytes[split + 5]) << 16) | (UInt32(bytes[split + 6]) << 24)
        guard XXHash32.hash(plainBytes) == expected else { return nil }
        return String(bytes: plainBytes, encoding: .utf8)
    }
}

private enum XXHash32 {
    private static let p1: UInt32 = 2654435761
    private static let p2: UInt32 = 2246822519
    private static let p3: UInt32 = 3266489917
    private static let p4: UInt32 = 668265263
    private static let p5: UInt32 = 374761393
    private static func rotl(_ x: UInt32, _ r: UInt32) -> UInt32 { (x << r) | (x >> (32 - r)) }
    private static func read32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i+1]) << 8) | (UInt32(b[i+2]) << 16) | (UInt32(b[i+3]) << 24)
    }
    private static func round(_ acc: UInt32, _ input: UInt32) -> UInt32 { rotl(acc &+ input &* p2, 13) &* p1 }
    static func hash(_ bytes: [UInt8]) -> UInt32 {
        let n = bytes.count
        var i = 0
        var h: UInt32
        if n >= 16 {
            var v1 = p1 &+ p2, v2 = p2, v3: UInt32 = 0, v4 = 0 &- p1
            while i <= n - 16 {
                v1 = round(v1, read32(bytes, i)); i += 4
                v2 = round(v2, read32(bytes, i)); i += 4
                v3 = round(v3, read32(bytes, i)); i += 4
                v4 = round(v4, read32(bytes, i)); i += 4
            }
            h = rotl(v1, 1) &+ rotl(v2, 7) &+ rotl(v3, 12) &+ rotl(v4, 18)
        } else { h = p5 }
        h &+= UInt32(n)
        while i + 4 <= n { h = rotl(h &+ read32(bytes, i) &* p3, 17) &* p4; i += 4 }
        while i < n { h = rotl(h &+ UInt32(bytes[i]) &* p5, 11) &* p1; i += 1 }
        h ^= h >> 15; h = h &* p2; h ^= h >> 13; h = h &* p3; h ^= h >> 16
        return h
    }
}
