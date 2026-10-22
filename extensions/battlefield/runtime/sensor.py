"""Robot-side optional publisher SDK: authenticated, versioned, bounded observations.

The receiver grants node/source/kind/frame explicitly. Publishers cannot grant
themselves fusion, speech, forwarding, or official robot-control permissions.
"""
import os
import secrets
import socket
import sys
from contract import SCHEMA, MAX_BYTES, canonical, decode, identifier, observation, sign, utc_ms


class SensorPublisher:
    def __init__(self, configuration):
        self.config = configuration
        self.socket = None
        self.key = b""
        self.sequence = 0
        self.session = secrets.token_hex(12)

    def start(self):
        self.stop()
        if not all(identifier(self.config.get(k)) for k in ("node_id", "team_id", "match_id")):
            raise ValueError("publisher scope")
        self.key = os.environ.get(self.config.get("key_env", "SITUATION_SENSOR_KEY"), "").encode()
        if len(self.key) < 32:
            raise ValueError("missing publisher environment key (minimum 32 bytes)")
        socket.inet_pton(socket.AF_INET, self.config["host"])
        port = self.config["port"]
        if type(port) is not int or not 1024 <= port <= 65535:
            raise ValueError("receiver port")
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)

    def publish(self, sample):
        if not self.socket:
            raise RuntimeError("publisher not started")
        item = observation(sample)
        self.sequence += 1
        body = {"schema": SCHEMA, "node_id": self.config["node_id"], "team_id": self.config["team_id"],
                "match_id": self.config["match_id"], "session": self.session, "sequence": self.sequence,
                "stamp_ms": utc_ms(), "kind": "observation", "payload": item}
        packet = canonical({"body": body, "signature": sign(body, self.key)})
        if len(packet) > MAX_BYTES:
            raise ValueError("observation packet too large")
        return self.socket.sendto(packet, (self.config["host"], self.config["port"])) == len(packet)

    def stop(self):
        if self.socket:
            self.socket.close()
        self.socket = None
        self.key = b""


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Display-only robot sensor observation publisher")
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    with open(args.config, "rb") as stream:
        config = decode(stream.read(MAX_BYTES+1))
    publisher = SensorPublisher(config)
    publisher.start()
    try:
        for raw in sys.stdin.buffer:
            publisher.publish(decode(raw))
    finally:
        publisher.stop()


if __name__ == "__main__":
    main()
