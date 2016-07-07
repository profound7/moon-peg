package moon.peg;

import haxe.Timer;
import moon.core.Symbol;
import moon.peg.lang.LispParser;
import moon.test.TestCase;
import moon.test.TestRunner;

/**
 * ...
 * @author Munir Hussin
 */
class LispTest extends TestCase
{
    public static function main()
    {
        var r = new TestRunner();
        r.add(new LispTest());
        r.run();
    }
    
    public function testLisp()
    {
        var data = '
            (var x "Hello") // test comment
            (var y "World") // another comment
            
            (var o/*p multiline comment
                {
                    a : "hello" : "bye"
                    b : ["foo" "bar"]
                    c : 5.2
                }
                q*/r
            )
            
            (var q \'(www eee))
            (var s `(abc ,x ,@q ghi))
            
            (print s)
        ';
        
        // data repetitions vs time
        // 0: 0.042s
        // 1: 0.106s
        // 2: 0.194s
        // 3: 0.307s
        // 4: 0.449s
        // 5: 0.621s
        // 6: 0.787s
        // 7: 1.006s
        // 8: 1.459s
        // 9: 1.731s
        
        //data = data + data + data + data + data + data + data + data + data + data;
        
        var p = new LispParser();
        var r = p.parse(data);
        
        //trace(r);
        
        assert.isDeepEqual(r,
            [
                [Symbol.of("var"), Symbol.of("x"), "Hello"],
                [Symbol.of("var"), Symbol.of("y"), "World"],
                [Symbol.of("var"), Symbol.of("o"), Symbol.of("r")],
                [Symbol.of("var"), Symbol.of("q"), [Symbol.of("quote"), [Symbol.of("www"), Symbol.of("eee")]]],
                [Symbol.of("var"), Symbol.of("s"), [Symbol.of("backquote"), [Symbol.of("abc"), [Symbol.of("unquote"), Symbol.of("x")], [Symbol.of("expand"), Symbol.of("q")], Symbol.of("ghi")]]],
                [Symbol.of("print"), Symbol.of("s")],
            ]
        );
    }
}
