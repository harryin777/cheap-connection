//
//  MySQLConnectionResolver.swift
//  cheap-connection
//
//  MySQL连接地址解析器
//

import Foundation
import NIOCore

/// 已解析的套接字地址
struct ResolvedSocketAddress {
    let socketAddress: SocketAddress
    let ipAddress: String
}

/// MySQL连接地址解析器
enum MySQLConnectionResolver {
    /// 解析主机名到多个套接字地址（支持 IPv4/IPv6）
    /// - Parameters:
    ///   - host: 主机名或IP地址
    ///   - port: 端口号
    /// - Returns: 解析后的地址列表
    nonisolated static func resolve(host: String, port: Int) throws -> [ResolvedSocketAddress] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, String(port), &hints, &result)

        guard status == 0, let firstInfo = result else {
            let errorMsg = String(cString: gai_strerror(status))
            throw AppError.connectionFailed("DNS解析失败: \(host) - \(errorMsg)")
        }

        defer {
            freeaddrinfo(firstInfo)
        }

        var addresses: [ResolvedSocketAddress] = []
        var seen: Set<String> = []
        var cursor: UnsafeMutablePointer<addrinfo>? = firstInfo

        while let info = cursor {
            defer {
                cursor = info.pointee.ai_next
            }

            guard let rawAddress = info.pointee.ai_addr else {
                continue
            }

            let ip = numericHost(
                from: rawAddress,
                length: socklen_t(info.pointee.ai_addrlen)
            ) ?? host

            let key = "\(info.pointee.ai_family)-\(ip)-\(port)"
            if !seen.insert(key).inserted {
                continue
            }

            switch info.pointee.ai_family {
            case AF_INET:
                let addrIn = rawAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                addresses.append(ResolvedSocketAddress(
                    socketAddress: SocketAddress(addrIn, host: host),
                    ipAddress: ip
                ))
            case AF_INET6:
                let addrIn6 = rawAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                addresses.append(ResolvedSocketAddress(
                    socketAddress: SocketAddress(addrIn6, host: host),
                    ipAddress: ip
                ))
            default:
                continue
            }
        }

        return addresses
    }

    /// 将套接字地址转换为数字形式的IP字符串
    private nonisolated static func numericHost(from address: UnsafePointer<sockaddr>, length: socklen_t) -> String? {
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            length,
            &hostBuffer,
            socklen_t(hostBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else {
            return nil
        }
        return String(cString: hostBuffer)
    }
}
