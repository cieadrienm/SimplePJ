import Darwin
import Foundation

/// Errors that can occur during a TCP PJLink session.
public enum PJLinkClientError: Error, Equatable, Sendable, LocalizedError {
    case invalidAddress(String)
    case connectionTimedOut(String, UInt16)
    case connectionRefused(String, UInt16)
    case invalidGreeting(String)
    case authenticationFailed
    case responseTimedOut(String)
    case networkFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let ip): return "Adresse IPv4 invalide (\(ip))"
        case .connectionTimedOut(let ip, let port): return "Délai dépassé vers \(ip):\(port)"
        case .connectionRefused(let ip, let port): return "Connexion refusée sur \(ip):\(port)"
        case .invalidGreeting(let line): return "Réponse PJLink inattendue (\(line))"
        case .authenticationFailed: return "Mot de passe PJLink refusé (ERRA)"
        case .responseTimedOut(let cmd): return "Pas de réponse à \(cmd)"
        case .networkFailure(let detail): return "Erreur réseau : \(detail)"
        }
    }
}

/// Outcome of a single or batched PJLink session.
public struct PJLinkSessionResult: Sendable {
    public var updatedProjector: Projector
    public var replies: [PJLinkReply]
    public var exchanges: [PJLinkExchange]
    public var latencyMs: Double

    public init(updatedProjector: Projector, replies: [PJLinkReply], exchanges: [PJLinkExchange], latencyMs: Double) {
        self.updatedProjector = updatedProjector
        self.replies = replies
        self.exchanges = exchanges
        self.latencyMs = latencyMs
    }
}

/// Low-overhead TCP PJLink Class 1 & Class 2 client built on non-blocking BSD sockets.
public enum PJLinkClient {
    /// Executes a single command on a projector and returns the updated state + exchange log.
    public static func execute(
        _ command: PJLinkCommand,
        on projector: Projector,
        timeout: TimeInterval = 1.5
    ) throws -> PJLinkSessionResult {
        try executeBatch([command], on: projector, timeout: timeout)
    }

    /// Executes a batch of commands on a projector, reusing the TCP socket when supported
    /// and transparently reconnecting when a projector closes the socket after one command.
    public static func executeBatch(
        _ commands: [PJLinkCommand],
        on projector: Projector,
        timeout: TimeInterval = 1.5
    ) throws -> PJLinkSessionResult {
        guard !commands.isEmpty else {
            return PJLinkSessionResult(updatedProjector: projector, replies: [], exchanges: [], latencyMs: 0)
        }

        var updated = projector
        var replies: [PJLinkReply] = []
        var exchanges: [PJLinkExchange] = []
        let sessionStart = DispatchTime.now()

        var socketFD: Int32 = -1
        var activeChallenge: String? = nil
        var isFirstCommandOnSocket = true

        defer {
            if socketFD >= 0 { Darwin.close(socketFD) }
        }

        func openAndGreet() throws {
            if socketFD >= 0 {
                Darwin.close(socketFD)
                socketFD = -1
            }
            let fd = try connectTCP(ip: updated.ip, port: updated.port, timeout: timeout)
            socketFD = fd
            let greetingLine = try readLine(fd: fd, timeout: timeout)
            guard let greeting = PJLinkGreeting.parse(greetingLine) else {
                throw PJLinkClientError.invalidGreeting(greetingLine)
            }
            switch greeting {
            case .noAuth:
                updated.requiresAuth = false
                activeChallenge = nil
            case .challenge(let token):
                updated.requiresAuth = true
                activeChallenge = token
            case .authError:
                updated.requiresAuth = true
                updated.connectionState = .authRequired
                updated.lastError = PJLinkResponseError.authenticationFailure.label
                throw PJLinkClientError.authenticationFailed
            }
            isFirstCommandOnSocket = true
        }

        try openAndGreet()

        for command in commands {
            let cmdStart = DispatchTime.now()
            let wireBody = command.wireBody

            // On a newly opened PJLink 1 connection, the first command carries the MD5 digest prefix.
            let framed: String
            if isFirstCommandOnSocket, let challenge = activeChallenge {
                framed = PJLinkAuth.frameCommand(wireBody, challenge: challenge, password: updated.password)
            } else {
                framed = PJLinkAuth.frameCommand(wireBody)
            }

            var rawReply: String?
            do {
                try writeAll(fd: socketFD, string: framed, timeout: timeout)
                let line = try readLine(fd: socketFD, timeout: timeout)
                if !line.isEmpty {
                    rawReply = line
                }
            } catch {
                rawReply = nil
            }

            // Many projectors (Panasonic, Epson, Sony) close the TCP socket after 1 command.
            // If this wasn't the first command on the socket and reading failed, reconnect cleanly.
            if rawReply == nil && !isFirstCommandOnSocket {
                try openAndGreet()
                let retryFramed: String
                if let challenge = activeChallenge {
                    retryFramed = PJLinkAuth.frameCommand(wireBody, challenge: challenge, password: updated.password)
                } else {
                    retryFramed = PJLinkAuth.frameCommand(wireBody)
                }
                try writeAll(fd: socketFD, string: retryFramed, timeout: timeout)
                let line = try readLine(fd: socketFD, timeout: timeout)
                if !line.isEmpty {
                    rawReply = line
                }
            }

            isFirstCommandOnSocket = false
            let cmdElapsedMs = Double(DispatchTime.now().uptimeNanoseconds - cmdStart.uptimeNanoseconds) / 1_000_000.0

            guard let line = rawReply, !line.isEmpty else {
                let ex = PJLinkExchange(
                    projectorIP: updated.endpointLabel,
                    projectorTitle: updated.displayTitle,
                    tx: wireBody,
                    rx: "TIMEOUT",
                    durationMs: cmdElapsedMs,
                    isError: true
                )
                exchanges.append(ex)
                throw PJLinkClientError.responseTimedOut(wireBody)
            }

            let parsed = PJLinkReply.parse(line)
            let isErr = parsed?.error != nil
            exchanges.append(
                PJLinkExchange(
                    projectorIP: updated.endpointLabel,
                    projectorTitle: updated.displayTitle,
                    tx: wireBody,
                    rx: line.trimmingCharacters(in: .whitespacesAndNewlines),
                    durationMs: cmdElapsedMs,
                    isError: isErr
                )
            )

            if let reply = parsed {
                replies.append(reply)
                if reply.error == .authenticationFailure {
                    updated.connectionState = .authRequired
                    updated.requiresAuth = true
                    updated.lastError = PJLinkResponseError.authenticationFailure.label
                    throw PJLinkClientError.authenticationFailed
                }
                if case .inputNameQuery(let inputCode) = command, reply.error == nil {
                    updated.applyInputName(code: inputCode, name: reply.value)
                } else {
                    updated.apply(reply: reply)
                }
            }
        }

        let totalMs = Double(DispatchTime.now().uptimeNanoseconds - sessionStart.uptimeNanoseconds) / 1_000_000.0
        let firstMs = exchanges.first?.durationMs ?? totalMs
        updated.connectionState = .online
        updated.latencyMs = firstMs
        updated.lastSeen = Date()
        updated.lastError = nil

        // Ensure follow-up action commands refresh dynamic state immediately when needed
        for command in commands {
            switch command {
            case .powerOn:
                if updated.power == .standby || updated.power == .unknown { updated.power = .warming }
            case .powerOff:
                if updated.power == .on { updated.power = .cooling }
            case .shutterClose:
                updated.shutter = .videoAndAudioMuted
            case .shutterOpen:
                updated.shutter = .open
            case .shutterVideoMute(let mute):
                updated.shutter = mute ? .videoMuted : .open
            case .shutterAudioMute(let mute):
                updated.shutter = mute ? .audioMuted : .open
            case .inputSelect(let code):
                updated.currentInput = code
            case .freeze(let f):
                updated.freeze = f
            default:
                break
            }
        }

        return PJLinkSessionResult(
            updatedProjector: updated,
            replies: replies,
            exchanges: exchanges,
            latencyMs: firstMs
        )
    }

    /// Polls operational status (and optionally full hardware identity & Class 2 telemetry).
    public static func poll(
        _ projector: Projector,
        includeIdentity: Bool = true,
        includeClass2: Bool = true,
        timeout: TimeInterval = 1.4
    ) -> PJLinkSessionResult {
        var commands: [PJLinkCommand] = [
            .powerQuery,
            .shutterQuery,
            .inputQuery,
            .errorStatusQuery,
            .lampQuery,
        ]
        if includeIdentity || projector.manufacturer == nil || projector.modelName == nil {
            commands.append(contentsOf: [
                .classQuery,
                .nameQuery,
                .manufacturerQuery,
                .modelQuery,
                .extraInfoQuery,
                .inputListQuery,
            ])
        }

        do {
            var result = try executeBatch(commands, on: projector, timeout: timeout)
            var current = result.updatedProjector

            if includeClass2 && current.pjlinkClass >= 2 {
                var class2Commands: [PJLinkCommand] = [
                    .inputResolutionQuery,
                    .filterUsageQuery,
                    .freezeQuery,
                ]
                if includeIdentity || current.serialNumber == nil {
                    class2Commands.append(contentsOf: [
                        .serialNumberQuery,
                        .firmwareVersionQuery,
                        .recommendedResolutionQuery,
                        .replacementLampQuery,
                        .replacementFilterQuery,
                    ])
                    for input in current.availableInputs where input.customName == nil {
                        class2Commands.append(.inputNameQuery(input.code))
                    }
                }
                if let c2Result = try? executeBatch(class2Commands, on: current, timeout: timeout) {
                    current = c2Result.updatedProjector
                    result.replies.append(contentsOf: c2Result.replies)
                    result.exchanges.append(contentsOf: c2Result.exchanges)
                }
            }
            result.updatedProjector = current
            return result
        } catch let error as PJLinkClientError {
            var failed = projector
            if error == .authenticationFailed {
                failed.connectionState = .authRequired
                failed.requiresAuth = true
                failed.lastError = error.localizedDescription
            } else {
                failed.connectionState = .offline
                failed.lastError = error.localizedDescription
            }
            return PJLinkSessionResult(updatedProjector: failed, replies: [], exchanges: [], latencyMs: 0)
        } catch {
            var failed = projector
            failed.connectionState = .offline
            failed.lastError = error.localizedDescription
            return PJLinkSessionResult(updatedProjector: failed, replies: [], exchanges: [], latencyMs: 0)
        }
    }

    /// Tries common factory passwords (`panasonic`, `admin`, `pjlink`, `JBMIA`, `0000`, etc.)
    /// against a password-protected PJLink projector and returns the matching password if found.
    public static func probeCommonPasswords(
        ip: String,
        port: UInt16 = kPJLinkDefaultPort,
        candidates: [String] = PJLinkAuth.commonPasswords,
        timeout: TimeInterval = 1.0
    ) -> String? {
        for candidate in [""] + candidates {
            let probe = Projector(ip: ip, port: port, password: candidate)
            if let result = try? execute(.powerQuery, on: probe, timeout: timeout),
               result.updatedProjector.connectionState == .online {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Low-level Non-blocking BSD Socket Helpers

    private static func connectTCP(ip: String, port: UInt16, timeout: TimeInterval) throws -> Int32 {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else {
            throw PJLinkClientError.invalidAddress(ip)
        }

        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw PJLinkClientError.networkFailure("socket() errno \(errno)")
        }

        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let connectRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectRes < 0 {
            let err = errno
            if err != EINPROGRESS {
                Darwin.close(fd)
                if err == ECONNREFUSED { throw PJLinkClientError.connectionRefused(ip, port) }
                throw PJLinkClientError.connectionTimedOut(ip, port)
            }

            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let timeoutMs = Int32(max(100, Int(timeout * 1000)))
            let ready = Darwin.poll(&pfd, 1, timeoutMs)
            if ready <= 0 {
                Darwin.close(fd)
                throw PJLinkClientError.connectionTimedOut(ip, port)
            }

            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
            if soError != 0 {
                Darwin.close(fd)
                if soError == ECONNREFUSED { throw PJLinkClientError.connectionRefused(ip, port) }
                throw PJLinkClientError.connectionTimedOut(ip, port)
            }
        }

        return fd
    }

    private static func writeAll(fd: Int32, string: String, timeout: TimeInterval) throws {
        let bytes = Array(string.utf8)
        var sent = 0
        let timeoutMs = Int32(max(100, Int(timeout * 1000)))

        while sent < bytes.count {
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let ready = Darwin.poll(&pfd, 1, timeoutMs)
            if ready <= 0 {
                throw PJLinkClientError.networkFailure("write timeout")
            }
            let n = bytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
            }
            if n <= 0 {
                if errno == EINTR { continue }
                throw PJLinkClientError.networkFailure("send errno \(errno)")
            }
            sent += n
        }
    }

    private static func readLine(fd: Int32, timeout: TimeInterval) throws -> String {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(128)
        let deadline = Date().addingTimeInterval(timeout)

        while true {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                if !buffer.isEmpty { break }
                throw PJLinkClientError.responseTimedOut("read")
            }
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = Darwin.poll(&pfd, 1, Int32(max(20, Int(remaining * 1000))))
            if ready <= 0 {
                if !buffer.isEmpty { break }
                throw PJLinkClientError.responseTimedOut("read")
            }
            var byte: UInt8 = 0
            let n = Darwin.recv(fd, &byte, 1, 0)
            if n == 0 {
                break
            }
            if n < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                break
            }
            if byte == 0x0D || byte == 0x0A { // '\r' or '\n'
                if !buffer.isEmpty { break }
                continue
            }
            buffer.append(byte)
            if buffer.count >= 512 { break }
        }

        return String(decoding: buffer, as: UTF8.self)
    }
}
