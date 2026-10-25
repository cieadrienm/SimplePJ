import Darwin
import Foundation

/// Active IPv4 network interface on this Mac.
public struct NetworkInterface: Hashable, Codable, Sendable {
    public let name: String
    public let ipv4: String
    public let netmask: String
    public let cidr: String
    public let broadcast: String?
    public let isVPN: Bool

    public init(name: String, ipv4: String, netmask: String, cidr: String, broadcast: String? = nil, isVPN: Bool = false) {
        self.name = name
        self.ipv4 = ipv4
        self.netmask = netmask
        self.cidr = cidr
        self.broadcast = broadcast
        self.isVPN = isVPN
    }

    public static func scannableInterfaces() -> [NetworkInterface] {
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let first = ptr else { return [] }
        defer { freeifaddrs(first) }

        var results: [NetworkInterface] = []
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cur?.pointee {
            cur = ifa.ifa_next
            let flags = Int32(ifa.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let addr = ifa.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
                  let mask = ifa.ifa_netmask else { continue }

            let name = String(cString: ifa.ifa_name)
            if name.hasPrefix("awdl") || name.hasPrefix("llw") || name.hasPrefix("ap") { continue }

            let ip = ipv4String(from: addr)
            let maskStr = ipv4String(from: mask)
            guard !ip.isEmpty, !ip.hasPrefix("169.254."),
                  let ipU32 = IPv4Range.uint32(from: ip),
                  let maskU32 = IPv4Range.uint32(from: maskStr) else { continue }

            let prefix = min(max(32 - maskU32.trailingZeroBitCount, 16), 30)
            let effectiveMask: UInt32 = prefix == 0 ? 0 : (~UInt32(0) << (32 - prefix))
            let networkU32 = ipU32 & effectiveMask
            let cidr = "\(IPv4Range.string(from: networkU32))/\(prefix)"
            let bcastU32 = networkU32 | ~effectiveMask
            let bcast = IPv4Range.string(from: bcastU32)
            let isVPN = name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec")

            let item = NetworkInterface(name: name, ipv4: ip, netmask: maskStr, cidr: cidr, broadcast: bcast, isVPN: isVPN)
            if !results.contains(where: { $0.cidr == item.cidr && $0.name == item.name }) {
                results.append(item)
            }
        }
        return results.sorted { lhs, rhs in
            if lhs.isVPN != rhs.isVPN { return !lhs.isVPN }
            return lhs.name < rhs.name
        }
    }

    private static func ipv4String(from sa: UnsafePointer<sockaddr>) -> String {
        sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
            var addr = sin.pointee.sin_addr
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { return "" }
            return String(cString: buf)
        }
    }
}

/// Target endpoint (`ip` + `port`) parsed from a CIDR, range, or explicit `ip:port` list.
public struct PJLinkEndpoint: Hashable, Codable, Sendable {
    public var ip: String
    public var port: UInt16

    public init(ip: String, port: UInt16 = kPJLinkDefaultPort) {
        self.ip = ip
        self.port = port
    }
}

/// IPv4 address & range parser (`192.168.1.0/24`, `192.168.1.10-50`, `192.168.1.20:4352`, comma-separated).
public enum IPv4Range {
    public static func uint32(from ip: String) -> UInt32? {
        var addr = in_addr()
        guard inet_pton(AF_INET, ip.trimmingCharacters(in: .whitespacesAndNewlines), &addr) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }

    public static func string(from value: UInt32) -> String {
        let a = (value >> 24) & 0xFF
        let b = (value >> 16) & 0xFF
        let c = (value >> 8) & 0xFF
        let d = value & 0xFF
        return "\(a).\(b).\(c).\(d)"
    }

    public static func parseEndpoints(_ input: String, defaultPort: UInt16 = kPJLinkDefaultPort, maxCount: Int = 4096) -> [PJLinkEndpoint] {
        var endpoints: [PJLinkEndpoint] = []
        var seen: Set<PJLinkEndpoint> = []

        func append(_ ep: PJLinkEndpoint) {
            guard endpoints.count < maxCount else { return }
            if seen.insert(ep).inserted { endpoints.append(ep) }
        }

        let parts = input
            .replacingOccurrences(of: ";", with: ",")
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for part in parts {
            // Check if part has explicit :port (and isn't CIDR)
            var token = part
            var port = defaultPort
            if let colon = part.lastIndex(of: ":"), !part.contains("/") {
                let portStr = String(part[part.index(after: colon)...])
                if let p = UInt16(portStr), p > 0 {
                    port = p
                    token = String(part[..<colon])
                }
            }

            if token.contains("/") {
                let sub = token.split(separator: "/")
                guard sub.count == 2,
                      let base = uint32(from: String(sub[0])),
                      let prefix = Int(sub[1]), (16...32).contains(prefix) else { continue }
                if prefix == 32 {
                    append(PJLinkEndpoint(ip: string(from: base), port: port))
                } else if prefix == 31 {
                    let net = base & (~UInt32(0) << 1)
                    append(PJLinkEndpoint(ip: string(from: net), port: port))
                    append(PJLinkEndpoint(ip: string(from: net + 1), port: port))
                } else {
                    let mask = ~UInt32(0) << (32 - prefix)
                    let net = base & mask
                    let bcast = net | ~mask
                    if bcast > net + 1 {
                        for addr in (net + 1)..<bcast {
                            append(PJLinkEndpoint(ip: string(from: addr), port: port))
                            if endpoints.count >= maxCount { break }
                        }
                    }
                }
            } else if token.contains("-") {
                let sub = token.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard sub.count == 2, let start = uint32(from: sub[0]) else { continue }
                let end: UInt32?
                if let fullEnd = uint32(from: sub[1]) {
                    end = fullEnd
                } else if let lastOctet = UInt32(sub[1]), lastOctet <= 255 {
                    end = (start & 0xFFFF_FF00) | lastOctet
                } else {
                    end = nil
                }
                guard let endAddr = end, endAddr >= start else { continue }
                for addr in start...min(endAddr, start + UInt32(maxCount)) {
                    append(PJLinkEndpoint(ip: string(from: addr), port: port))
                }
            } else if let single = uint32(from: token) {
                append(PJLinkEndpoint(ip: string(from: single), port: port))
            }
        }
        return endpoints
    }
}

/// Kernel ARP table reader (`/usr/sbin/arp -an`) for associating MAC addresses with projector IPs.
public enum ARPLookup {
    public static func currentTable() -> [String: String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        proc.arguments = ["-an"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return [:] }
            return parse(text)
        } catch {
            return [:]
        }
    }

    public static func parse(_ output: String) -> [String: String] {
        var map: [String: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let openParen = line.firstIndex(of: "("),
                  let closeParen = line[openParen...].firstIndex(of: ")"),
                  let atRange = line.range(of: " at ") else { continue }
            let ip = String(line[line.index(after: openParen)..<closeParen])
            let afterAt = line[atRange.upperBound...]
            guard let rawMAC = afterAt.split(whereSeparator: \.isWhitespace).first else { continue }
            if let normalized = normalizeMAC(String(rawMAC)) {
                map[ip] = normalized
            }
        }
        return map
    }

    public static func normalizeMAC(_ raw: String) -> String? {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "(incomplete)" || lower == "ff:ff:ff:ff:ff:ff" { return nil }
        let parts = lower.split(separator: ":")
        guard parts.count == 6 else { return nil }
        var bytes: [String] = []
        for p in parts {
            guard let val = UInt8(p, radix: 16) else { return nil }
            bytes.append(String(format: "%02X", val))
        }
        return bytes.joined(separator: ":")
    }
}

/// Progress event emitted during network PJLink discovery.
public enum PJLinkDiscoveryEvent: Sendable {
    case started(total: Int)
    case progress(scanned: Int, total: Int)
    case found(Projector)
    case finished(foundCount: Int, duration: TimeInterval)
}

/// Fast, parallel TCP `:4352` + Class 2 UDP `:4352` (`%2SRCH`) projector discovery engine.
public enum PJLinkDiscovery {
    /// Scans the given endpoints for open PJLink TCP ports and probes every responding projector.
    public static func scan(
        endpoints: [PJLinkEndpoint],
        existingPasswords: [String: String] = [:],
        connectTimeoutMs: Int32 = 380,
        batchSize: Int = 64,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onEvent: (@Sendable (PJLinkDiscoveryEvent) -> Void)? = nil
    ) -> [Projector] {
        let startTime = Date()
        let total = endpoints.count
        onEvent?(.started(total: total))
        guard total > 0 else {
            onEvent?(.finished(foundCount: 0, duration: 0))
            return []
        }

        // Send Class 2 UDP broadcast %2SRCH\r on port 4352 as a complimentary hint
        sendClass2SearchBroadcast()

        var openEndpoints: [PJLinkEndpoint] = []
        var scanned = 0

        for chunkStart in stride(from: 0, to: total, by: max(1, batchSize)) {
            if shouldCancel?() == true { break }
            let chunkEnd = min(chunkStart + max(1, batchSize), total)
            let batch = Array(endpoints[chunkStart..<chunkEnd])
            let reachable = probeTCPBatch(batch, timeoutMs: connectTimeoutMs)
            openEndpoints.append(contentsOf: reachable)
            scanned = chunkEnd
            onEvent?(.progress(scanned: scanned, total: total))
        }

        let arpTable = ARPLookup.currentTable()
        var discovered: [Projector] = []
        let lock = NSLock()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "net.cieadrienm.simplepj.discovery", attributes: .concurrent)

        for ep in openEndpoints {
            if shouldCancel?() == true { break }
            group.enter()
            queue.async {
                defer { group.leave() }
                let pwd = existingPasswords[ep.ip] ?? existingPasswords["\(ep.ip):\(ep.port)"] ?? ""
                var candidate = Projector(
                    ip: ep.ip,
                    port: ep.port,
                    mac: arpTable[ep.ip],
                    password: pwd
                )

                // Verify that the TCP service on this port actually speaks PJLink
                let session = PJLinkClient.poll(candidate, includeIdentity: true, includeClass2: true, timeout: 1.2)
                candidate = session.updatedProjector
                guard candidate.connectionState == .online || candidate.connectionState == .authRequired else {
                    return
                }
                if candidate.mac == nil {
                    candidate.mac = arpTable[ep.ip]
                }

                lock.lock()
                discovered.append(candidate)
                lock.unlock()
                onEvent?(.found(candidate))
            }
        }

        group.wait()
        discovered.sort {
            (IPv4Range.uint32(from: $0.ip) ?? 0, $0.port) < (IPv4Range.uint32(from: $1.ip) ?? 0, $1.port)
        }
        onEvent?(.finished(foundCount: discovered.count, duration: Date().timeIntervalSince(startTime)))
        return discovered
    }

    /// Probes a batch of TCP endpoints simultaneously using non-blocking sockets and `poll()`.
    private static func probeTCPBatch(_ batch: [PJLinkEndpoint], timeoutMs: Int32) -> [PJLinkEndpoint] {
        struct PendingSocket {
            var fd: Int32
            var endpoint: PJLinkEndpoint
            var connected: Bool
        }

        var pending: [PendingSocket] = []
        pending.reserveCapacity(batch.count)

        for ep in batch {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = ep.port.bigEndian
            guard inet_pton(AF_INET, ep.ip, &addr.sin_addr) == 1 else { continue }

            let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            guard fd >= 0 else { continue }
            var one: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
            let flags = fcntl(fd, F_GETFL, 0)
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

            let res = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if res == 0 {
                pending.append(PendingSocket(fd: fd, endpoint: ep, connected: true))
            } else if errno == EINPROGRESS {
                pending.append(PendingSocket(fd: fd, endpoint: ep, connected: false))
            } else {
                Darwin.close(fd)
            }
        }

        defer {
            for item in pending where item.fd >= 0 {
                Darwin.close(item.fd)
            }
        }

        guard !pending.isEmpty else { return [] }

        var open: [PJLinkEndpoint] = []
        var resolved = [Bool](repeating: false, count: pending.count)
        for i in 0..<pending.count where pending[i].connected {
            open.append(pending[i].endpoint)
            resolved[i] = true
        }

        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while !resolved.allSatisfy({ $0 }) {
            let remainingMs = Int32(deadline.timeIntervalSinceNow * 1000.0)
            if remainingMs <= 0 { break }

            var pollFDs = (0..<pending.count).map { i in
                pollfd(fd: resolved[i] ? -1 : pending[i].fd, events: Int16(POLLOUT), revents: 0)
            }
            let ready = Darwin.poll(&pollFDs, nfds_t(pollFDs.count), remainingMs)
            if ready <= 0 { break }

            for i in 0..<pending.count where !resolved[i] {
                let revents = pollFDs[i].revents
                if revents != 0 {
                    resolved[i] = true
                    if (revents & Int16(POLLOUT)) != 0 && (revents & Int16(POLLERR | POLLHUP)) == 0 {
                        var soErr: Int32 = 0
                        var len = socklen_t(MemoryLayout<Int32>.size)
                        getsockopt(pending[i].fd, SOL_SOCKET, SO_ERROR, &soErr, &len)
                        if soErr == 0 {
                            open.append(pending[i].endpoint)
                        }
                    }
                }
            }
        }
        return open
    }

    /// Sends a best-effort PJLink Class 2 `%2SRCH\r` UDP broadcast packet on port 4352.
    public static func sendClass2SearchBroadcast() {
        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { Darwin.close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        let payload = Array("%2SRCH\r".utf8)
        var targets = ["255.255.255.255"]
        for iface in NetworkInterface.scannableInterfaces() {
            if let bcast = iface.broadcast, !targets.contains(bcast) {
                targets.append(bcast)
            }
        }

        for target in targets {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = kPJLinkDefaultPort.bigEndian
            guard inet_pton(AF_INET, target, &addr.sin_addr) == 1 else { continue }
            payload.withUnsafeBytes { ptr in
                _ = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.sendto(fd, ptr.baseAddress, payload.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }
    }
}

/// Sends Wake-on-LAN UDP magic packets (`FF:FF:FF:FF:FF:FF` + 16× MAC) on ports 9 and 7.
public enum WakeOnLAN {
    public static func buildMagicPacket(mac: String) -> Data? {
        let hex = mac
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count == 12 else { return nil }
        var macBytes: [UInt8] = []
        var idx = hex.startIndex
        for _ in 0..<6 {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            macBytes.append(byte)
            idx = next
        }
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }

    @discardableResult
    public static func send(mac: String, broadcastIP: String = "255.255.255.255") -> Bool {
        guard let packet = buildMagicPacket(mac: mac) else { return false }
        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var sentAny = false
        for port: UInt16 in [9, 7] {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            guard inet_pton(AF_INET, broadcastIP, &addr.sin_addr) == 1 else { continue }
            let sent = packet.withUnsafeBytes { ptr in
                withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.sendto(fd, ptr.baseAddress, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            if sent == packet.count { sentAny = true }
        }
        return sentAny
    }
}
