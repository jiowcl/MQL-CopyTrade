# MQL-CopyTrade

Copy Trade System for MetaTrader 4 Client based on MQL script.

![GitHub](https://img.shields.io/github/license/jiowcl/MQL-CopyTrade.svg)
![Libraries.io dependency status for GitHub repo](https://img.shields.io/librariesio/github/dingmaotu/mql-zmq.svg)

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
- Custom Trading Symbol between Publisher and Subscriber
- Subscriber Min Lots, Max Lots and Percent Lots
- Subscriber Invert Original Orders
- Subscriber Symbol adjust
- Subscriber Free Margin Check

The Publishers do not need to log in with a trading password, just log in and using the investor password.

# Publisher Optins

| Properties | Description |
| --- | --- |
| `Server`                  | Bind the Publisher server IP address |
| `ServerDelayMilliseconds` | Push the order to subscriber delay milliseconds |
| `ServerReal`              | Under real server |
| `AllowSymbols`            | Allow trading Symbols |

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
| `AllowSymbols`            | Allow trading Symbols |
| `InvertOrder`             | Invert original orders |
| `MinFreeMargin`           | Minimum free margin to open a new order |
| `SymbolPrefixAdjust`      | Adjust the Symbol Name between A broker and B broker |

# License

Copyright (c) 2017-2019 ji-Feng Tsai.<br/>
MQL-Zmq Copyright (c) Ding Li [ZeroMQ for MQL](https://github.com/dingmaotu).

Code released under the MIT license.

# TODO

- Trading hours during which the subscriber is allowed to trade
- Invert original trade direction (Solved)
- Copy orders with specific Symbols (Solved)
- More examples

# Donation

If this application help you reduce time to trading, you can give me a cup of coffee :)

[![paypal](https://www.paypalobjects.com/en_US/TW/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=3RNMD6Q3B495N&source=url)
