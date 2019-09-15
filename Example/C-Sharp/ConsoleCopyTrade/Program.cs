using System;
using NetMQ;
using NetMQ.Sockets;
using ConsoleCopyTrade.MT4;

namespace ConsoleCopyTrade
{
    public class Program
    {
        /// <summary>
        /// Main
        /// </summary>
        public static void Main(string[] args)
        {
            using (SubscriberSocket subSocket = new SubscriberSocket())
            {
                subSocket.Options.ReceiveHighWatermark = 1000;

                subSocket.Connect("tcp://localhost:5559");
                subSocket.Subscribe("");

                while (true)
                {
                    string messageReceived = subSocket.ReceiveFrameString();
                    string[] messageData = messageReceived.Split(' ');

                    if (messageData.Length != 2)
                        continue;

                    string[] orderData = messageData[1].Split('|');

                    if (orderData.Length != 9)
                        continue;

                    Response response = new Response
                    {
                        Login = int.Parse(messageData[0]),
                        Action = orderData[0],
                        Symbol = orderData[1],
                        Ticket = int.Parse(orderData[2]),
                        Type = int.Parse(orderData[3]),
                        OpenPrice = double.Parse(orderData[4]),
                        ClosePrice = double.Parse(orderData[5]),
                        Lots = double.Parse(orderData[6]),
                        SL = double.Parse(orderData[7]),
                        TP = double.Parse(orderData[8])
                    };

                    Console.WriteLine("Login: " + response.Login + ", Action: " + response.Action + ", Symbol: " + response.Symbol);
                }
            }
        }
    }
}
