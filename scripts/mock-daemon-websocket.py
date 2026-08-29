#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import socket
import struct
import sys

path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(1)


def receive_frame(connection, buffered=b""):
    def require(count):
        nonlocal buffered
        while len(buffered) < count:
            chunk = connection.recv(65536)
            if not chunk:
                raise EOFError
            buffered += chunk

    require(2)
    first, second = buffered[0], buffered[1]
    assert second & 0x80
    length = second & 0x7f
    offset = 2
    if length == 126:
        require(4)
        length = struct.unpack(">H", buffered[2:4])[0]
        offset = 4
    elif length == 127:
        require(10)
        length = struct.unpack(">Q", buffered[2:10])[0]
        offset = 10
    require(offset + 4 + length)
    mask = buffered[offset:offset + 4]
    payload = bytes(
        value ^ mask[index % 4]
        for index, value in enumerate(buffered[offset + 4:offset + 4 + length])
    )
    return first & 0x0f, payload, buffered[offset + 4 + length:]


def frame(opcode, payload, final=True):
    header = bytes([(0x80 if final else 0) | opcode])
    length = len(payload)
    if length < 126:
        return header + bytes([length]) + payload
    if length <= 65535:
        return header + bytes([126]) + struct.pack(">H", length) + payload
    return header + bytes([127]) + struct.pack(">Q", length) + payload


connection, _ = server.accept()
buffered = b""
while b"\r\n\r\n" not in buffered:
    buffered += connection.recv(4096)
header, buffered = buffered.split(b"\r\n\r\n", 1)
key_line = next(line for line in header.split(b"\r\n") if line.lower().startswith(b"sec-websocket-key:"))
key = key_line.split(b":", 1)[1].strip()
accept = base64.b64encode(hashlib.sha1(key + b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest())
connection.sendall(
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n"
)

opcode, payload, buffered = receive_frame(connection, buffered)
assert opcode == 1 and json.loads(payload)["method"] == "initialize"
response = json.dumps({"id": 1, "result": {"serverInfo": {"name": "mock"}}}).encode()
connection.sendall(frame(1, response[:17], False) + frame(0, response[17:]))
opcode, payload, buffered = receive_frame(connection, buffered)
assert opcode == 1 and json.loads(payload)["method"] == "initialized"
connection.sendall(frame(9, b"health-check"))
opcode, payload, buffered = receive_frame(connection, buffered)
assert opcode == 10 and payload == b"health-check"
opcode, payload, buffered = receive_frame(connection, buffered)
request = json.loads(payload)
assert opcode == 1 and request["method"] == "thread/list" and request["params"]["limit"] == 30
threads = [{"id": f"thread-{index}", "status": "notLoaded"} for index in range(30)]
response = json.dumps({"id": 2, "result": {"data": threads, "nextCursor": None}}).encode()
split = len(response) // 2
connection.sendall(frame(1, response[:split], False) + frame(0, response[split:]))
connection.close()
server.close()
os.unlink(path)
