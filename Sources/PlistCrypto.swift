import Foundation

enum PlistToolError: LocalizedError {
    case invalidPlist, noCars, duplicateCar(String), malformedCar(String), carChecksum(String)
    case nicknameKeysMissing, gemKeyMissing, gemInvalid
    var errorDescription: String? {
        switch self {
        case .invalidPlist: return "文件无法解析为 plist 字典。请确认选择的是游戏存档文件。"
        case .noCars: return "没有识别到 CAR_n 车辆记录，无法安全确定新编号。"
        case .duplicateCar(let name): return "车辆已存在：\(name)"
        case .malformedCar(let key): return "车辆记录格式无法识别：\(key)"
        case .carChecksum(let key): return "新增车辆校验失败：\(key)"
        case .nicknameKeysMissing: return "这个 plist 缺少昵称修改所需字段，未作任何更改。"
        case .gemKeyMissing: return "没有找到 ExtraGems 字段，未作任何更改。"
        case .gemInvalid: return "宝石数量必须是 0 到 2,147,483,647 之间的整数。"
        }
    }
}

struct CarRecord: Identifiable {
    let id: Int
    let name: String
    var keyName: String { "CAR_\(id)" }
}

struct PlistWorkspace {
    let dictionary: [String: Any]
    let format: PropertyListSerialization.PropertyListFormat
    let sourceName: String

    static func load(data: Data, filename: String) throws -> PlistWorkspace {
        // Try Apple's normal parser first. It auto-detects XML and binary plist regardless of extension.
        for options: PropertyListSerialization.ReadOptions in [[], [.mutableContainersAndLeaves]] {
            var detected = PropertyListSerialization.PropertyListFormat.xml
            if let object = try? PropertyListSerialization.propertyList(from: data, options: options, format: &detected),
               let dict = object as? [String: Any] {
                return PlistWorkspace(dictionary: dict, format: detected, sourceName: filename)
            }
        }
        throw PlistToolError.invalidPlist
    }

    func serialized(_ updated: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: updated, format: format, options: 0)
    }
}

// Shared verified XXHash32 implementation used by the game's obfuscated preference records.
enum XXHash32 {
    private static let p1: UInt32 = 2654435761, p2: UInt32 = 2246822519
    private static let p3: UInt32 = 3266489917, p4: UInt32 = 668265263, p5: UInt32 = 374761393
    private static func rotl(_ x: UInt32, _ r: UInt32) -> UInt32 { (x << r) | (x >> (32 - r)) }
    private static func read32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i+1]) << 8) | (UInt32(b[i+2]) << 16) | (UInt32(b[i+3]) << 24)
    }
    private static func round(_ acc: UInt32, _ input: UInt32) -> UInt32 { rotl(acc &+ input &* p2, 13) &* p1 }
    static func hash(_ bytes: [UInt8]) -> UInt32 {
        let n = bytes.count; var i = 0; var h: UInt32
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

enum CarPlistCrypto {
    private static let keyBytes = Array("e806f6".utf8)
    private static let marker: [UInt8] = [0x0F, 0x02, 0x00]
    static func read(from dictionary: [String: Any]) throws -> [CarRecord] {
        var result: [CarRecord] = []
        for (encodedKey, raw) in dictionary {
            guard let key = decryptKey(encodedKey), let range = key.range(of: #"^CAR_(\d+)$"#, options: .regularExpression),
                  let id = Int(key[range].dropFirst(4)), let value = raw as? String else { continue }
            guard let name = decryptValue(value, carKey: key) else { throw PlistToolError.malformedCar(key) }
            result.append(CarRecord(id: id, name: name))
        }
        return result.sorted { $0.id < $1.id }
    }
    static func adding(_ name: String, to dictionary: [String: Any], allowDuplicate: Bool = false) throws -> ([String: Any], CarRecord) {
        let cars = try read(from: dictionary)
        guard !cars.isEmpty else { throw PlistToolError.noCars }
        if !allowDuplicate { guard !cars.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw PlistToolError.duplicateCar(name) } }
        let id = (cars.map(\.id).max() ?? -1) + 1, key = "CAR_\(id)", encoded = encryptKey(key)
        guard dictionary[encoded] == nil else { throw PlistToolError.malformedCar(key) }
        var updated = dictionary; updated[encoded] = encryptValue(name, carKey: key)
        guard try read(from: updated).contains(where: { $0.id == id && $0.name == name }) else { throw PlistToolError.carChecksum(key) }
        return (updated, CarRecord(id: id, name: name))
    }
    private static func xor(_ bytes: [UInt8], _ key: [UInt8]) -> [UInt8] {
        bytes.enumerated().map { $0.element ^ key[$0.offset % key.count] }
    }
    private static func encryptKey(_ key: String) -> String { Data(xor(Array(key.utf8), keyBytes)).base64EncodedString() }
    private static func decryptKey(_ key: String) -> String? {
        guard let d = Data(base64Encoded: key) else { return nil }
        return String(bytes: xor(Array(d), keyBytes), encoding: .utf8)
    }
    private static func valueKey(_ key: String) -> [UInt8] { Array((key + "e806f6").utf8) }
    private static func encryptValue(_ value: String, carKey: String) -> String {
        let plain = Array(value.utf8), key = valueKey(carKey)
        let h = XXHash32.hash(plain)
        var bytes = xor(plain, key) + marker
        bytes += [UInt8(h & 255), UInt8((h >> 8) & 255), UInt8((h >> 16) & 255), UInt8((h >> 24) & 255)]
        return Data(bytes).base64EncodedString()
    }
    private static func decryptValue(_ value: String, carKey: String) -> String? {
        guard let d = Data(base64Encoded: value) else { return nil }; let b = Array(d)
        guard b.count >= 7 else { return nil }; let split = b.count - 7
        guard Array(b[split..<split+3]) == marker else { return nil }
        let plain = xor(Array(b[..<split]), valueKey(carKey))
        let hash = UInt32(b[split+3]) | (UInt32(b[split+4]) << 8) | (UInt32(b[split+5]) << 16) | (UInt32(b[split+6]) << 24)
        guard XXHash32.hash(plain) == hash else { return nil }
        return String(bytes: plain, encoding: .utf8)
    }
}

enum NicknameCrypto {
    private static let localNameField = "KVdTVwp4BFVV"
    private static let playerField = "NVRRTwNENlBfQShXCF0="
    private static let marker: [UInt8] = [0x0F, 0x02, 0x00]
    static func updating(_ nickname: String, in dictionary: [String: Any]) throws -> [String: Any] {
        guard dictionary[localNameField] != nil, dictionary[playerField] != nil else { throw PlistToolError.nicknameKeysMissing }
        var updated = dictionary
        updated[localNameField] = encode(nickname, key: "LocalN")
        updated[playerField] = encode(nickname, key: "Player")
        return updated
    }
    private static func encode(_ value: String, key: String) -> String {
        let plain = Array(value.utf8), k = Array(key.utf8)
        var b = plain.enumerated().map { $0.element ^ k[$0.offset % k.count] } + marker
        let h = XXHash32.hash(plain)
        b += [UInt8(h & 255), UInt8((h >> 8) & 255), UInt8((h >> 16) & 255), UInt8((h >> 24) & 255)]
        return Data(b).base64EncodedString()
    }
}

enum GemCrypto {
    private static let encryptedKey = "IEBERAdxAFVD" // EncryptKey("ExtraGems") with e806f6
    private static let encryptionKey = Array("ExtraGemse806f6".utf8)
    static func updating(_ amount: Int, in dictionary: [String: Any]) throws -> [String: Any] {
        guard amount >= 0, amount <= Int(Int32.max) else { throw PlistToolError.gemInvalid }
        guard dictionary[encryptedKey] != nil else { throw PlistToolError.gemKeyMissing }
        var updated = dictionary
        updated[encryptedKey] = encode(Int32(amount))
        guard decode(updated[encryptedKey] as? String ?? "") == Int32(amount) else { throw PlistToolError.gemInvalid }
        return updated
    }
    private static func encode(_ value: Int32) -> String {
        var n = UInt32(bitPattern: value).littleEndian
        let plain = withUnsafeBytes(of: &n) { Array($0) }
        let encrypted = plain.enumerated().map { $0.element ^ encryptionKey[$0.offset % encryptionKey.count] }
        let hash = XXHash32.hash(plain)
        var bytes = encrypted + [0x05, 0x02, 0x00]
        bytes += [UInt8(hash & 255), UInt8((hash >> 8) & 255), UInt8((hash >> 16) & 255), UInt8((hash >> 24) & 255)]
        return Data(bytes).base64EncodedString()
    }
    private static func decode(_ value: String) -> Int32? {
        guard let data = Data(base64Encoded: value) else { return nil }; let b = Array(data)
        guard b.count == 11, Array(b[4...6]) == [0x05, 0x02, 0x00] else { return nil }
        let plain = b[0..<4].enumerated().map { $0.element ^ encryptionKey[$0.offset % encryptionKey.count] }
        let expected = UInt32(b[7]) | (UInt32(b[8]) << 8) | (UInt32(b[9]) << 16) | (UInt32(b[10]) << 24)
        guard XXHash32.hash(plain) == expected else { return nil }
        let raw = UInt32(plain[0]) | (UInt32(plain[1]) << 8) | (UInt32(plain[2]) << 16) | (UInt32(plain[3]) << 24)
        return Int32(bitPattern: raw)
    }
}
