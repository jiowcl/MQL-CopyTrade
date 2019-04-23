#!/usr/bin/env python
import sys
import time

import zmq
import numpy

def main():
    connect_to = "tcp://127.0.0.1:5559"
    topics = ""

    ctx = zmq.Context()
    s = ctx.socket(zmq.SUB)
    s.connect(connect_to)
    s.setsockopt(zmq.SUBSCRIBE, b'')

    try:
        while True:
            recv = s.recv_multipart()
            recvMsg = recv[0].decode("utf-8")
            message = recvMsg.split(" ")
            order = message[1].split("|")

            print(order)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()