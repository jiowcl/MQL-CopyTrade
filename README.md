# MT4-CopyTrade

Copy Trade System for MetaTrader 4 Client based on MQL script.

# Environment

- Windows 7 above (recommend)
- MetaTrader 4 Client
- [ZeroMQ](https://github.com/zeromq)
- [ZeroMQ for MQL](https://github.com/dingmaotu/mql-zmq)

# Features

- Remote Publisher and Subscriber (Based on IP address)
- New Order (Market Order, Pending Order)
- Modify Order (TP, SL)
- Close Order (Normal Close, Partial Close)
- Subscriber Min Lots, Max Lots and Percent Lots
- Subscriber Symbol adjust
- Subscriber Free Margin Check

# Publisher Optins

| Properties | Description |
| --- | --- |
| `Server`                  | Bind the Publisher server IP address |
| `ServerDelayMilliseconds` | Push the order to subscriber delay milliseconds |
| `ServerReal`              | Under real server |

# Subscriber Options

| Properties | Description |
| --- | --- |
| `Server`                  | Subscribe the Publisher server IP address |
| `ServerDelayMilliseconds` | Subscriber from Publisher delay milliseconds |
| `ServerReal`              | Under real server |
| `SignalAccount`           | Subscribe the Publisher MT4 account |
| `MinLots`                 | Limit the minimum lots |
| `MaxLots`                 | Limit the maximum lots |
| `PercentLots`             | Lots Percent from Publisher lots |
| `Slippage`                |  |
| `AllowOpenTrade`          | Allow open a new order |
| `AllowCloseTrade`         | Allow close a order |
| `AllowModifyTrade`        | Allow modify a order |
| `MinFreeMargin`           | Minimum free margin to open a new order |
| `SymbolPrefixAdjust`      | Adjust the Symbol Name between A broker and B broker |

# License

Copyright (c) 2019 ji-Feng Tsai.<br/>
MQL-Zmq Copyright (c) Ding Li [ZeroMQ for MQL](https://github.com/dingmaotu).

Code released under the MIT license.