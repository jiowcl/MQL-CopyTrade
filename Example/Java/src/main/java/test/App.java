package test;

import org.zeromq.SocketType;
import org.zeromq.ZMQ;
import org.zeromq.ZContext;

/**
 * Test
 */
public final class App {
    private App() {
        
    }

    /**
     * Main.
     * @param args The arguments of the program.
     */
    public static void main(String[] args) {
        ZContext context = new ZContext();
        ZMQ.Socket subscriber = context.createSocket(SocketType.SUB);

        Boolean enabled = true;
        String serverAddr = "tcp://localhost:5559";

        subscriber.connect(serverAddr);
        subscriber.subscribe("");

        while (enabled) {
            String messageReceived = subscriber.recvStr(0).trim();
            String[] messageData = messageReceived.split(" ");

            if (messageData.length != 2)
                continue;

            String[] orderData = messageData[1].toString().split("\\|");

            if (orderData.length != 9)
                continue;

            System.out.println("Login: " + messageData[0] + ", Action: " + orderData[0] + ", Symbol: " + orderData[1]);
        }

        subscriber.disconnect(serverAddr);
        subscriber.close();

        context.close();
    }
}
