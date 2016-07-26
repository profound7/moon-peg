package moon.peg;

import moon.core.Symbol;
import moon.peg.grammar.Parser;
import moon.peg.grammar.ParseTree;
import moon.test.TestCase;
import moon.test.TestRunner;

using moon.peg.grammar.ParseTreeTools;

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
        var r1 = p.parse("aaaab", "c");
        var r2 = p.parse("cat123cat432", "x");
        
        assert.isDeepEqual(r1,
            Node("c",
                Multi([
                    Node("a", Value("a")),
                    Node("a", Value("a")),
                    Node("a", Value("a")),
                    Node("a", Value("a")),
                    Node("b", Value("b"))
                ])
            )
        );
        
        assert.isDeepEqual(r2,
            Node("x",
                Multi([
                    Node("s", Value("cat")),
                    Node("d", Value("123")),
                    Value("cat"),
                    Node("d", Value("432"))
                ])
            )
        );
    }
}
