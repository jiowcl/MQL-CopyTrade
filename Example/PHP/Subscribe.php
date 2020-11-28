<?php
$enabled = true;
$serverAddr = "tcp://localhost:5559";

$socket = new ZMQSocket(new ZMQContext(), ZMQ::SOCKET_SUB);
$socket->connect($serverAddr );
$socket->setSockOpt(ZMQ::SOCKOPT_SUBSCRIBE, "");

// Zmq blocking mode for received the message
while ($enabled) {
    $messageReceived = trim($socket->recv());
    $messageData = explode(" ", $messageReceived);
    
    if (count($messageData) != 2)
        continue;

    $orderData = explode("|", $messageData[1]);

    if (count($orderData) != 9)
        continue;

    print_r([
        "Login"  => $messageData[0],
        "Action" => $orderData[0],
        "Symbol" => $orderData[1]
    ]);
}

$socket->disconnect($serverAddr );