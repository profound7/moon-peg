package moon.peg.grammar;

import moon.core.Symbol;
import moon.peg.grammar.Stream.RecursionInfo;

/**
 * ParseTree is the result of parsing a text stream.
 * @author Munir Hussin
 */
enum ParseTree
{
    // fails
    Pending;                                    // left recursion detection
    Recursion(info:RecursionInfo);
    //Error(msg:String);                          // failed
    Error;                                      // failed
    
    // successes
    Empty;                                      // no value
    Value(v:String);                            // terminal value
    
    Tree(val:ParseTree);                        // single value (for pass-thru)
    Multi(a:Array<ParseTree>);                  // multi-values (for seq, A* or A+)
    Node(id:String, val:ParseTree);             // with child nodes
}

class ParseTreeTools
{
    /**
     * Flattens a tree into a String.
     * This can be used to combine disjoint Values into a single Value
     */
    public static function flatten(tree:ParseTree, seperator:String=""):String
    {
        return switch (tree)
        {
            case Empty:
                "";
                
            case Value(v):
                Std.string(v);
                
            case Multi(a):
                [for (x in a) flatten(x, seperator)].join(seperator);
                
            case Node(_, x):
                flatten(x, seperator);
                
            case _:
                throw "Invalid value";
        }
    }
    
    public static function toJson(tree:ParseTree):Dynamic
    {
        return switch(tree)
        {
            case Empty:
                null;
                
            case Value(v):
                v;
                
            case Multi(a):
                [for (x in a) toJson(x)];
                
            case Node(_, v):
                toJson(v);
                
            case Tree(v):
                toJson(v);
                
            case _:
                throw "Unexpected tree node: " + tree;
        }
    }
    
    public static function toLisp(tree:ParseTree):Dynamic
    {
        return switch(tree)
        {
            case Empty:
                null;
                
            case Value(v):
                v;
                
            case Multi(a):
                [for (x in a) toLisp(x)];
                
            case Node(id, Multi(a)):
                Symbol.call(id, toLisp(Multi(a)));
                
            case Node(id, v):
                Symbol.call(id, [toLisp(v)]);
                
            case Tree(v):
                toLisp(v);
                
            case _:
                throw "Unexpected tree node: " + tree;
        }
    }
}