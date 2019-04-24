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

            v_action = order[0]
            v_symbol = order[1]
            v_ticket = order[2]
            v_type = order[3]
            v_openprice = order[4]
            v_closeprice = order[5]
            v_lots = order[6]
            v_sl = order[7]
            v_tp = order[8]
            
            print("Action: ", v_action, ", Symbol: ", v_symbol)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
