module integrationtest.buffered.main;

import ocean.io.stream.Buffered;
import ocean.util.test.DirectorySandbox;
import ocean.io.device.File;
import ocean.core.Test;

version (unittest) {} else
void main ()
{
    auto sandbox = DirectorySandbox.create();
    scope (exit)
        sandbox.exitSandbox();

    auto output = new BufferedOutput(
        new File("test.txt", File.WriteCreate),
        1024
    );

    output("hello");
    output.close();

    auto text = File.get("test.txt");
    test!("==")(text, "hello");
}
