using System;
using System.Collections.Generic;
using System.Text;

namespace ConsoleCopyTrade.MT4
{
    /// <summary>
    /// Response
    /// </summary>

    public class Response
    {
        /// <summary>
        /// Login
        /// </summary>
        public int Login { get; set; }

        /// <summary>
        /// Action
        /// </summary>
        public string Action { get; set; }

        /// <summary>
        /// Symbol
        /// </summary>
        public string Symbol { get; set; }

        /// <summary>
        /// Order Ticket
        /// </summary>
        public int Ticket { get; set; }

        /// <summary>
        /// Order Type
        /// </summary>
        public int Type { get; set; }

        /// <summary>
        /// Open price
        /// </summary>
        public double OpenPrice { get; set; }

        /// <summary>
        /// Close price
        /// </summary>
        public double ClosePrice { get; set; }

        /// <summary>
        /// Lots
        /// </summary>
        public double Lots { get; set; }

        /// <summary>
        /// SL
        /// </summary>
        public double SL { get; set; }

        /// <summary>
        /// TP
        /// </summary>

        public double TP { get; set; }
    }
}
