import Foundation

indirect enum PlistValue: Equatable {
    case string(String)
    case integer(Int)
    case real(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case array([PlistItem])
    case dict([PlistItem])
}

struct PlistItem: Identifiable, Equatable {
    var id = UUID()
    var key: String
    var value: PlistValue
}

enum PlistType: String, CaseIterable, Identifiable {
    case string, integer, real, bool, date, array, dict
    var id: String { rawValue }
    var titleKey: String { "plist.type_\(rawValue)" }

    var defaultValue: PlistValue {
        switch self {
        case .string: return .string("")
        case .integer: return .integer(0)
        case .real: return .real(0)
        case .bool: return .bool(false)
        case .date: return .date(Date())
        case .array: return .array([])
        case .dict: return .dict([])
        }
    }
}

enum PlistCodec {
    static func decode(_ any: Any) -> PlistValue {
        switch any {
        case let d as [String: Any]:
            return .dict(d.keys.sorted().map { PlistItem(key: $0, value: decode(d[$0]!)) })
        case let a as [Any]:
            return .array(a.enumerated().map { PlistItem(key: "\($0.offset)", value: decode($0.element)) })
        case let s as String:
            return .string(s)
        case let d as Date:
            return .date(d)
        case let d as Data:
            return .data(d)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            if CFNumberIsFloatType(n) { return .real(n.doubleValue) }
            return .integer(n.intValue)
        default:
            return .string("\(any)")
        }
    }

    static func encode(_ value: PlistValue) -> Any {
        switch value {
        case .string(let s): return s
        case .integer(let i): return NSNumber(value: i)
        case .real(let d): return NSNumber(value: d)
        case .bool(let b): return NSNumber(value: b)
        case .date(let d): return d
        case .data(let d): return d
        case .array(let items): return items.map { encode($0.value) }
        case .dict(let items):
            var out: [String: Any] = [:]
            for i in items { out[i.key] = encode(i.value) }
            return out
        }
    }

    /// Reads a plist file. Root must be a dictionary or an array.
    static func read(_ url: URL) throws -> (value: PlistValue, format: PropertyListSerialization.PropertyListFormat) {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        let value = decode(obj)
        switch value {
        case .dict, .array: return (value, format)
        default: throw RakiError.unsupportedPlist
        }
    }

    static func write(_ value: PlistValue, to url: URL, format: PropertyListSerialization.PropertyListFormat) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: encode(value), format: format, options: 0)
        try data.write(to: url, options: .atomic)
    }
}
