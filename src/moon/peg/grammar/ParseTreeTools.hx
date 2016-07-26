package moon.peg.grammar;

import moon.core.Symbol;

/**
 * ...
 * @author Munir Hussin
 */
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
    
}