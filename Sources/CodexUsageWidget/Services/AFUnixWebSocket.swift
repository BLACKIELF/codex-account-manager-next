import Darwin
import Foundation
import Security

enum AFUnixWebSocketError: Error {
    case invalidSocketPath
    case socketFailed(Int32)
    case connectFailed(Int32)
    case handshakeFailed
    case protocolViolation
    case messageTooLarge
    case disconnected
}

final class AFUnixWebSocket {
    typealias MessageHandler = (Data) -> Void
    typealias DisconnectHandler = () -> Void

    private let socketPath: String
    private let maximumMessageBytes: Int
    private let callbackQueue: DispatchQueue
    private let readerQueue: DispatchQueue
    private let writeLock = NSLock()
    private let stateLock = NSLock()
    private var descriptor: Int32 = -1
    private var didReportDisconnect = false

    init(socketPath: String, maximumMessageBytes: Int, callbackQueue: DispatchQueue) {
        self.socketPath = socketPath
        self.maximumMessageBytes = maximumMessageBytes
        self.callbackQueue = callbackQueue
        readerQueue = DispatchQueue(
            label: "com.blackielf.codex-account-manager-next.task-websocket.reader",
            qos: .utility
        )
    }

    func start(
        onReady: @escaping () -> Void,
        onMessage: @escaping MessageHandler,
        onDisconnect: @escaping DisconnectHandler
    ) {
        readerQueue.async { [weak self] in
            guard let self else { return }
            do {
                let descriptor = try self.openSocket()
                self.setDescriptor(descriptor)
                var buffer = try self.performHandshake(descriptor: descriptor)
                self.callbackQueue.async(execute: onReady)
                try self.readFrames(
                    descriptor: descriptor,
                    buffer: &buffer,
                    onMessage: onMessage
                )
            } catch {
                // The owning client publishes the fail-closed disconnected state.
            }
            self.close()
            self.reportDisconnect(onDisconnect)
        }
    }

    func sendText(_ data: Data) -> Bool {
        sendFrame(opcode: 0x1, payload: data)
    }

    func close() {
        stateLock.lock()
        let descriptor = self.descriptor
        self.descriptor = -1
        stateLock.unlock()
        guard descriptor >= 0 else { return }
        Darwin.shutdown(descriptor, SHUT_RDWR)
        Darwin.close(descriptor)
    }

    private func openSocket() throws -> Int32 {
        let pathBytes = Array(socketPath.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
            throw AFUnixWebSocketError.invalidSocketPath
        }
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw AFUnixWebSocketError.socketFailed(errno) }
        var noSigPipe: Int32 = 1
        _ = withUnsafePointer(to: &noSigPipe) {
            setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, $0, socklen_t(MemoryLayout<Int32>.size))
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { destination in
                socketPath.withCString { source in
                    _ = Darwin.strlcpy(destination, source, pathBytes.count)
                }
            }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw AFUnixWebSocketError.connectFailed(code)
        }
        return descriptor
    }

    private func performHandshake(descriptor: Int32) throws -> Data {
        var nonce = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, nonce.count, &nonce) == errSecSuccess else {
            throw AFUnixWebSocketError.handshakeFailed
        }
        let key = Data(nonce).base64EncodedString()
        let request = "GET / HTTP/1.1\r\n"
            + "Host: localhost\r\n"
            + "Upgrade: websocket\r\n"
            + "Connection: Upgrade\r\n"
            + "Sec-WebSocket-Key: \(key)\r\n"
            + "Sec-WebSocket-Version: 13\r\n\r\n"
        guard writeAll(Data(request.utf8), descriptor: descriptor) else {
            throw AFUnixWebSocketError.disconnected
        }

        var buffer = Data()
        let delimiter = Data("\r\n\r\n".utf8)
        while buffer.range(of: delimiter) == nil {
            guard buffer.count < 32 * 1_024 else { throw AFUnixWebSocketError.handshakeFailed }
            buffer.append(try readChunk(descriptor: descriptor))
        }
        guard let headerRange = buffer.range(of: delimiter) else {
            throw AFUnixWebSocketError.handshakeFailed
        }
        let headerData = buffer[..<headerRange.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else {
            throw AFUnixWebSocketError.handshakeFailed
        }
        let lines = header.components(separatedBy: "\r\n")
        guard lines.first?.split(separator: " ").dropFirst().first == "101" else {
            throw AFUnixWebSocketError.handshakeFailed
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            headers[String(line[..<separator]).lowercased()] = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
        }
        let expectedAccept = SHA1.hash(Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
            .base64EncodedString()
        guard headers["upgrade"]?.lowercased() == "websocket",
              headers["connection"]?.lowercased().split(separator: ",").map({
                  $0.trimmingCharacters(in: .whitespaces)
              }).contains("upgrade") == true,
              headers["sec-websocket-accept"] == expectedAccept else {
            throw AFUnixWebSocketError.handshakeFailed
        }
        return Data(buffer[headerRange.upperBound...])
    }

    private func readFrames(
        descriptor: Int32,
        buffer: inout Data,
        onMessage: @escaping MessageHandler
    ) throws {
        var fragmentedOpcode: UInt8?
        var fragmentedPayload = Data()
        while true {
            try fill(&buffer, count: 2, descriptor: descriptor)
            // buffer 经 removeFirst 后下标不从 0 开始，必须一律基于 startIndex 定位
            let base = buffer.startIndex
            let first = buffer[base]
            let second = buffer[base + 1]
            guard first & 0x70 == 0, second & 0x80 == 0 else {
                throw AFUnixWebSocketError.protocolViolation
            }
            let isFinal = first & 0x80 != 0
            let opcode = first & 0x0f
            var headerBytes = 2
            var payloadLength = UInt64(second & 0x7f)
            if payloadLength == 126 {
                try fill(&buffer, count: 4, descriptor: descriptor)
                payloadLength = UInt64(buffer[base + 2]) << 8 | UInt64(buffer[base + 3])
                headerBytes = 4
            } else if payloadLength == 127 {
                try fill(&buffer, count: 10, descriptor: descriptor)
                guard buffer[base + 2] & 0x80 == 0 else { throw AFUnixWebSocketError.protocolViolation }
                payloadLength = (2..<10).reduce(UInt64(0)) { ($0 << 8) | UInt64(buffer[base + $1]) }
                headerBytes = 10
            }
            guard payloadLength <= UInt64(maximumMessageBytes),
                  payloadLength <= UInt64(Int.max),
                  headerBytes <= Int.max - Int(payloadLength) else {
                throw AFUnixWebSocketError.messageTooLarge
            }
            let frameBytes = headerBytes + Int(payloadLength)
            try fill(&buffer, count: frameBytes, descriptor: descriptor)
            let payload = Data(buffer[(base + headerBytes)..<(base + frameBytes)])
            buffer.removeFirst(frameBytes)

            if opcode & 0x08 != 0 {
                guard isFinal, payload.count <= 125 else { throw AFUnixWebSocketError.protocolViolation }
                if opcode == 0x8 { return }
                if opcode == 0x9, !sendFrame(opcode: 0xA, payload: payload) { return }
                guard opcode == 0x9 || opcode == 0xA else {
                    throw AFUnixWebSocketError.protocolViolation
                }
                continue
            }
            if opcode == 0x0 {
                guard fragmentedOpcode != nil else { throw AFUnixWebSocketError.protocolViolation }
                guard fragmentedPayload.count <= maximumMessageBytes - payload.count else {
                    throw AFUnixWebSocketError.messageTooLarge
                }
                fragmentedPayload.append(payload)
                if isFinal {
                    let message = fragmentedPayload
                    let originalOpcode = fragmentedOpcode
                    fragmentedOpcode = nil
                    fragmentedPayload.removeAll(keepingCapacity: false)
                    if originalOpcode == 0x1 { callbackQueue.async { onMessage(message) } }
                }
            } else {
                guard opcode == 0x1 || opcode == 0x2, fragmentedOpcode == nil else {
                    throw AFUnixWebSocketError.protocolViolation
                }
                if isFinal {
                    if opcode == 0x1 { callbackQueue.async { onMessage(payload) } }
                } else {
                    fragmentedOpcode = opcode
                    fragmentedPayload = payload
                }
            }
        }
    }

    private func fill(_ buffer: inout Data, count: Int, descriptor: Int32) throws {
        while buffer.count < count { buffer.append(try readChunk(descriptor: descriptor)) }
    }

    private func readChunk(descriptor: Int32) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let count = Darwin.read(descriptor, &bytes, bytes.count)
            if count > 0 { return Data(bytes.prefix(count)) }
            if count == 0 { throw AFUnixWebSocketError.disconnected }
            if errno != EINTR { throw AFUnixWebSocketError.disconnected }
        }
    }

    private func sendFrame(opcode: UInt8, payload: Data) -> Bool {
        guard payload.count <= maximumMessageBytes else { return false }
        var mask = [UInt8](repeating: 0, count: 4)
        guard SecRandomCopyBytes(kSecRandomDefault, mask.count, &mask) == errSecSuccess else {
            return false
        }
        var frame = Data([0x80 | opcode])
        if payload.count < 126 {
            frame.append(UInt8(0x80 | payload.count))
        } else if payload.count <= Int(UInt16.max) {
            frame.append(0x80 | 126)
            frame.append(UInt8((payload.count >> 8) & 0xff))
            frame.append(UInt8(payload.count & 0xff))
        } else {
            frame.append(0x80 | 127)
            let count = UInt64(payload.count)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((count >> UInt64(shift)) & 0xff))
            }
        }
        frame.append(contentsOf: mask)
        frame.append(contentsOf: payload.enumerated().map { $0.element ^ mask[$0.offset % 4] })
        writeLock.lock()
        defer { writeLock.unlock() }
        stateLock.lock()
        let descriptor = self.descriptor
        stateLock.unlock()
        return descriptor >= 0 && writeAll(frame, descriptor: descriptor)
    }

    private func writeAll(_ data: Data, descriptor: Int32) -> Bool {
        data.withUnsafeBytes { rawBuffer in
            guard var pointer = rawBuffer.baseAddress else { return data.isEmpty }
            var remaining = rawBuffer.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count > 0 {
                    remaining -= count
                    pointer = pointer.advanced(by: count)
                } else if count < 0, errno == EINTR {
                    continue
                } else {
                    return false
                }
            }
            return true
        }
    }

    private func setDescriptor(_ descriptor: Int32) {
        stateLock.lock()
        self.descriptor = descriptor
        stateLock.unlock()
    }

    private func reportDisconnect(_ handler: @escaping DisconnectHandler) {
        stateLock.lock()
        let shouldReport = !didReportDisconnect
        didReportDisconnect = true
        stateLock.unlock()
        if shouldReport { callbackQueue.async(execute: handler) }
    }
}

private enum SHA1 {
    static func hash(_ data: Data) -> Data {
        var message = Array(data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }
        var state: [UInt32] = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]
        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 80)
            for index in 0..<16 {
                let base = offset + index * 4
                words[index] = UInt32(message[base]) << 24 | UInt32(message[base + 1]) << 16
                    | UInt32(message[base + 2]) << 8 | UInt32(message[base + 3])
            }
            for index in 16..<80 {
                words[index] = rotateLeft(
                    words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16],
                    by: 1
                )
            }
            var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4]
            for index in 0..<80 {
                let (function, constant): (UInt32, UInt32)
                switch index {
                case 0..<20: (function, constant) = ((b & c) | ((~b) & d), 0x5a827999)
                case 20..<40: (function, constant) = (b ^ c ^ d, 0x6ed9eba1)
                case 40..<60: (function, constant) = ((b & c) | (b & d) | (c & d), 0x8f1bbcdc)
                default: (function, constant) = (b ^ c ^ d, 0xca62c1d6)
                }
                let temporary = rotateLeft(a, by: 5) &+ function &+ e &+ constant &+ words[index]
                e = d; d = c; c = rotateLeft(b, by: 30); b = a; a = temporary
            }
            state[0] &+= a; state[1] &+= b; state[2] &+= c; state[3] &+= d; state[4] &+= e
        }
        var digest = Data()
        for word in state {
            digest.append(UInt8((word >> 24) & 0xff))
            digest.append(UInt8((word >> 16) & 0xff))
            digest.append(UInt8((word >> 8) & 0xff))
            digest.append(UInt8(word & 0xff))
        }
        return digest
    }

    private static func rotateLeft(_ value: UInt32, by count: UInt32) -> UInt32 {
        (value << count) | (value >> (32 - count))
    }
}
