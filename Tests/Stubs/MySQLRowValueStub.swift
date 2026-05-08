import Foundation

enum MySQLRowValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case date(Date)
    case data(Data)
    case null

    var displayValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .date(let d):
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return f.string(from: d)
        case .data(let d): return d.map { String(format: "%02x", $0) }.joined()
        case .null: return "NULL"
        }
    }

    var isNull: Bool { self == .null }
}
