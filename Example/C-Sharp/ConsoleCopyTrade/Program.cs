using System;
using NetMQ;
using NetMQ.Sockets;

namespace ConsoleCopyTrade
{
    class Program
    {
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

                    int mt4Login = int.Parse(messageData[0]);
                    string vAction = orderData[0];
                    string vSymbol = orderData[1];
                    //int vTicket = int.Parse(orderData[2]);
                    //int vType = int.Parse(orderData[3]);
                    //double vOpenPrice = double.Parse(orderData[4]);
                    //double vClosePrice = double.Parse(orderData[5]);
                    //double vLots = double.Parse(orderData[6]);
                    //double vSL = double.Parse(orderData[7]);
                    //double vTP = double.Parse(orderData[8]);

                    Console.WriteLine("Login: " + mt4Login + ", Action: " + vAction + ", Symbol: " + vSymbol);
                }
            }
        }
    }
}
