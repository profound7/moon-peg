package;

import moon.peg.LispTest;
import moon.peg.ParserTest;
import moon.peg.StreamTest;
import moon.test.TestCase;
import moon.test.TestRunner;

/**
 * ...
 * @author Munir Hussin
 */
class Test
{
    
    public static function main()
    {
        var modules:Array<Class<TestCase>> =
        [
            ParserTest,
            LispTest,
            StreamTest,
        ];
        
        var r = new TestRunner();
        for (m in modules)
            r.add(Type.createInstance(m, []));
        r.run();
    }
}
