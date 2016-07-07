package moon.peg;

import moon.core.Symbol;
import moon.peg.grammar.Parser;
import moon.test.TestCase;
import moon.test.TestRunner;

using moon.peg.grammar.ParseTree;

/**
 * @author Munir Hussin
 */
class ParserTest extends TestCase
{
    public static function main()
    {
        var r = new TestRunner();
        r.add(new ParserTest());
        r.run();
    }
    
    public function testParser()
    {
        var data = '
            a = "a"
            b = "b"
            
            s = ~/[a-z]+/
            d = ~/[0-9]+/
            
            c = a* b
            x = s d 0 d;
        ';
        
        var p = new Parser(data);
        var r1 = p.parse("aaaab", "c").toLisp();
        var r2 = p.parse("cat123cat432", "x").toLisp();
        
        assert.isDeepEqual(r1,
            [Symbol.of("c"), 
                [Symbol.of("a"), "a"],
                [Symbol.of("a"), "a"],
                [Symbol.of("a"), "a"],
                [Symbol.of("a"), "a"],
                [Symbol.of("b"), "b"],
            ]
        );
        
        assert.isDeepEqual(r2,
            [Symbol.of("x"), 
                [Symbol.of("s"), "cat"],
                [Symbol.of("d"), "123"],
                "cat",
                [Symbol.of("d"), "432"],
            ]
        );
    }
}
