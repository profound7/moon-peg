package moon.peg.grammar;

import moon.peg.grammar.Stream;
import moon.peg.grammar.Rule;

using moon.peg.grammar.RuleTools;

/**
 * PEG packrat parser with direct and indirect left recursion support.
 * There's 2 ways of using this class.
 * 
 * 1. Use Parser class without class parameters.
 *    This allows you to load any grammar files at runtime.
 *      
 *      var p = new Parser(peg);
 *      var ast = p.parse(codes);
 * 
 * 2. Use Parser class with String parameter.
 *    This uses haxe's genericBuild, so the grammar file is processed
 *    at compile-time. You do not need the grammar file after
 *    compilation.
 *      
 *      var p = new Parser<"data/lisp.peg">();
 *      var ast = p.parse(codes);
 * 
 * @author Munir Hussin
 */
@:genericBuild(moon.peg.grammar.ParserBuilder.build())
class Parser<Const>
{
    public var rules:Map<String, Rule>;
    public var rxCache:Array<EReg>;
    public var object:Dynamic;
    
    
    public function init(data:String):Void
    {
        rules = PegParser.parse(data);
        initCache();
    }
    
    public function initCache():Void
    {
        var lookup = new Map<String, Int>();
        
        // should we cache ids as well?
        rxCache = [];
        
        // convert all Rx(r, opt) rules into Rxc(i) rules
        function cacheRegularExpressions(rule:Rule):Rule
        {
            return switch (rule)
            {
                case Rx(r, opt):
                    var key = '$r/$opt';
                    
                    if (lookup.exists(key))
                    {
                        Rxc(lookup.get(key));
                    }
                    else
                    {
                        var index = rxCache.length;
                        lookup.set(key, index);
                        
                        rxCache.push(new EReg("^" + r, opt));
                        Rxc(index);
                    }
                    
                case _:
                    RuleTools.map(rule, cacheRegularExpressions);
            }
        }
        
        for (id in rules.keys())
        {
            rules[id] = cacheRegularExpressions(rules[id]);
        }
        
        /*for (id in rules.keys())
        {
            var rule:Rule = rules[id];
            trace('$id = $rule');
        }*/
    }
    
    public function parse(text:String, id:String="#start"):ParseTree
    {
        //trace(id);
        //if (id == null) id = "#start";
        var stream:Stream = new Stream(text, rules);
        stream.object = this.object;
        stream.rxCache = this.rxCache;
        return stream.match(id);
    }
}