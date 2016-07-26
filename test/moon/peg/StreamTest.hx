package moon.peg;

import moon.core.Symbol;
import moon.peg.grammar.Parser;
import moon.test.TestCase;
import moon.test.TestRunner;

using moon.peg.grammar.ParseTreeTools;

/**
 * ...
 * @author Munir Hussin
 */
@:build(moon.core.Sugar.build())
class StreamTest extends TestCase
{
    public static function main()
    {
        var r = new TestRunner();
        r.add(new StreamTest());
        r.run();
    }
    
    public function testMatchStr()
    {
        var data = '
            a = "Hello"
            
            x = a
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("Hello", "x").toJson(), "Hello");
        
        assert.throws([] => p.parse(" Hello", "x"));
        assert.throws([] => p.parse("hello", "x"));
    }
    
    public function testMatchRx()
    {
        var data = '
            a = ~/[A-Za-z_]/
            
            x = a
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("foo", "x").toJson(), "f");
        assert.returns([] => p.parse("BAR", "x").toJson(), "B");
        assert.returns([] => p.parse("_ba", "x").toJson(), "_");
        
        assert.throws([] => p.parse("42", "x"));
    }
    
    public function testMatchSeq()
    {
        var data = '
            a = "A"
            b = "B"
            
            x = a b
            y = a b 0 1
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("AB", "x").toJson(), ["A", "B"]);
        assert.returns([] => p.parse("ABC", "x").toJson(), ["A", "B"]);
        
        assert.throws([] => p.parse("ACB", "x"));
        assert.throws([] => p.parse("A", "x"));
        assert.throws([] => p.parse("C", "x"));
        
        // with backreferences
        assert.returns([] => p.parse("ABAB", "y").toJson(), ["A", "B", "A", "B"]);
        assert.throws([] => p.parse("ABBA", "y"));
    }
    
    public function testMatchOr()
    {
        var data = '
            a = "A"
            b = "B"
            c = "C"
            
            x = a / b
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), "A");
        assert.returns([] => p.parse("AB", "x").toJson(), "A");
        assert.returns([] => p.parse("B", "x").toJson(), "B");
        assert.returns([] => p.parse("BA", "x").toJson(), "B");
        
        assert.throws([] => p.parse("C", "x"));
    }
    
    public function testMatchAny()
    {
        var data = '
            a = "A"
            b = "B"
            c = "AA"
            
            x = a | b | c
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), "A");
        assert.returns([] => p.parse("AB", "x").toJson(), "A");
        assert.returns([] => p.parse("B", "x").toJson(), "B");
        assert.returns([] => p.parse("BA", "x").toJson(), "B");
        
        // matches c since it consumes more
        assert.returns([] => p.parse("AA", "x").toJson(), "AA");
        
        assert.throws([] => p.parse("C", "x"));
    }
    
    public function testMatchZeroOrMore()
    {
        var data = '
            abc = "A" / "B" / "C"
            
            x = abc*
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), ["A"]);
        assert.returns([] => p.parse("ABC", "x").toJson(), ["A", "B", "C"]);
        assert.returns([] => p.parse("ABBA", "x").toJson(), ["A", "B", "B", "A"]);
        
        // should this be [] instead of null for consistency?
        assert.returns([] => p.parse("123", "x").toJson(), null);
    }
    
    public function testMatchOneOrMore()
    {
        var data = '
            abc = "A" / "B" / "C"
            
            x = abc+
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("B", "x").toJson(), ["B"]);
        assert.returns([] => p.parse("BAC", "x").toJson(), ["B", "A", "C"]);
        assert.returns([] => p.parse("BACA", "x").toJson(), ["B", "A", "C", "A"]);
        
        assert.throws([] => p.parse("123", "x"));
    }
    
    public function testMatchZeroOrOne()
    {
        var data = '
            abc = "A" / "B" / "C"
            
            x = abc?
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), "A");
        assert.returns([] => p.parse("BB", "x").toJson(), "B");
        assert.returns([] => p.parse("123", "x").toJson(), null);
    }
    
    public function testMatchAhead()
    {
        var data = '
            a = "A"
            b = "B"
            c = "C"
            
            x = a &b
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("AB", "x").toJson(), ["A"]);
        
        assert.throws([] => p.parse("A", "x"));
        assert.throws([] => p.parse("AC", "x"));
    }
    
    public function testMatchNotAhead()
    {
        var data = '
            a = "A"
            b = "B"
            c = "C"
            
            x = a !b
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), ["A"]);
        assert.returns([] => p.parse("AC", "x").toJson(), ["A"]);
        
        assert.throws([] => p.parse("AB", "x"));
    }
    
    /**
     * @A
     * Hide. Matches the rule and consumes, but will
     * return an Empty result instead if successful.
     * Can be used for non-capturing expressions.
     */
    public function testMatchHide()
    {
        var data = '
            a = "A"
            b = "B"
            DIGITS = ~/[0-9]+/
            
            x = a
            y = @a
            z = @"(" DIGITS @"+" DIGITS @")"
        ';
        
        var p = new Parser(data);
        
        assert.returns([] => p.parse("A", "x").toJson(), "A");
        assert.returns([] => p.parse("A", "y").toJson(), null);
        assert.returns([] => p.parse("(23+45)", "z").toJson(), ["23", "45"]);
        
        assert.throws([] => p.parse("B", "x"));
        assert.throws([] => p.parse("B", "y"));
        assert.throws([] => p.parse("(AB+CD)", "z"));
    }
}