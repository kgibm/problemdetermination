import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

public class ConsumeCPU
{
    private final static byte[] KEY_PASSWORD = new byte[] {
        't', 'e', 's', 't', 't', 'e', 's', 't',
        't', 'e', 's', 't', 't', 'e', 's', 't'
    };

    public static void main(String[] args) throws Throwable
    {
        int minutes = 2;
        if (args != null && args.length > 0)
        {
            minutes = Integer.parseInt(args[0]);
        }
        System.out.println("Started. Doing CPU intensive work for " + minutes + " minutes...");

        long max = System.currentTimeMillis() + (1000 * 60 * minutes);

        do
        {
            try
            {
                Cipher ciph = Cipher.getInstance("AES");

                SecretKeySpec AESkeySpec = new SecretKeySpec(KEY_PASSWORD, "AES");
                ciph.init(Cipher.ENCRYPT_MODE, AESkeySpec);

                ciph.update("somedata blah blah blah".getBytes());
                ciph.doFinal();
            }
            catch (Throwable t)
            {
                t.printStackTrace();
            }
        }
        while (System.currentTimeMillis() < max);

        System.out.println("Finished CPU Intensive Work. Sleeping indefinitely (Ctrl+C to quit)...");

        Object o = new Object();
        synchronized (o)
        {
            o.wait();
        }
    }
}
