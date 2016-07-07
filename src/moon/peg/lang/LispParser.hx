package moon.peg.lang;

import moon.core.Symbol;
import moon.peg.grammar.Parser;
import moon.peg.grammar.ParseTree;

/**
 * ...
 * @author Munir Hussin
 */
class LispParser
{
    public static var p = new Parser<"../data/Lisp.peg">();
    
    public function new()
    {
        //trace("rules:");
        //trace(p.rules);
        //trace("end rules\n\n");
        p.object = this;
    }
    
    public function parse(text:String, ?id:String):Dynamic
    {
        var out = p.parse(text, id);
        //trace(out);
        //return out;
        return toLisp(out);
    }
    
    public function toLisp(tree:ParseTree):Dynamic
    {
        return switch (tree)
        {
            case Empty:
                null;
                
            case Value(v):
                v;
                
            case Multi(a):
                [for (x in a) toLisp(x)];
                
            case Tree(v):
                toLisp(v);
                
            case Node(id, v):
                
                switch (id)
                {
                    case "symbol":
                        Symbol.of(toLisp(v));
                        
                    case "true":
                        true;
                        
                    case "false":
                        false;
                        
                    case "null":
                        null;
                        
                    case "float":
                        Std.parseFloat(toLisp(v));
                        
                    case "int":
                        Std.parseInt(toLisp(v));
                        
                    case "string":
                        Std.string(toLisp(v));
                        
                    case "list":
                        var a:Dynamic = toLisp(v);
                        
                        if (!Std.is(a, Array))
                        {
                            trace('LispParser Warning: Expected array: $v');
                            a = [a];
                        }
                        
                        a;
                        
                    case "array" | "object" | "cons":
                        var a:Dynamic = toLisp(v);
                        
                        if (!Std.is(a, Array))
                            throw 'LispParser Error: Expected array, got $a';
                            
                        var arr:Array<Dynamic> = a;
                            
                        Symbol.call(id, arr);
                        
                    case "quote" | "backquote" | "unquote" | "expand":
                        [Symbol.of(id), toLisp(v)];
                        
                    case _:
                        throw 'LispParser Error: Unexpected node: $id';
                }
                
            case _:
                throw 'LispParser Error: Not implemented: $tree';
        }
    }
}
