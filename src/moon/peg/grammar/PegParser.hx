package moon.peg.grammar;

import moon.core.Console;
import moon.core.Pair;
import moon.core.Symbol;
import moon.core.Text;
import moon.peg.grammar.Rule;
import moon.peg.parser.Lexer;
import moon.peg.parser.Operators;
import moon.peg.parser.Token;
import moon.peg.parser.TokenStream;

using moon.peg.grammar.RuleTools;

/**
 * Custom written recursive descent parser to parse
 * the PEG grammar file.
 * 
 * Should I write peg grammar to parse peg grammar?
 * Maybe in the future when there's reason to.
 * 
 * @author Munir Hussin
 */
class PegParser
{
    public static var debugOutput:Bool = false;
    public static var debugRules:Bool = false;
    public static var depth:Int = 0;
    
    public static var operators:Operators;
    public static var lexer:Lexer<Token>;
    
    public var code:String;
    public var tokens:TokenStream<Token>;
    
    /*==================================================
        Constructors
    ==================================================*/
    
    public static function __init__():Void
    {
        operators = initOperators();
        lexer = initLexer();
    }
    
    public static function initOperators()
    {
        var ops = new Operators();
        var i:Int = 0;
        
        ++i;
        ops.add(OpInfo.binary("|", i, Right, "Any"));
        ops.add(OpInfo.binary("/", i, Right, "Or"));
        
        ++i;
        ops.add(OpInfo.binary(",", i, Right, "Seq"));
        
        ++i;
        ops.add(OpInfo.unary("&", i, Left, "Ahead"));
        ops.add(OpInfo.unary("!", i, Left, "NotAhead"));
        
        ++i;
        ops.add(OpInfo.unary("*", i, Right, "ZeroOrMore"));
        ops.add(OpInfo.unary("+", i, Right, "OneOrMore"));
        ops.add(OpInfo.unary("?", i, Right, "ZeroOrOne"));
        
        ++i;
        ops.add(OpInfo.unary("@", i, Left, "Hide"));
        ops.add(OpInfo.unary("$", i, Left, "Pass"));
        ops.add(OpInfo.unary("%", i, Left, "Anon"));
        
        ++i;
        ops.add(OpInfo.binary(":", i, Left, "Transform"));
        
        return ops;
    }
    
    public static function initLexer():Lexer<Token>
    {
        var lex = new Lexer<Token>();
        
        lex.onInit = function(text:String):String
        {
            text = StringTools.replace(text, "\r\n", "\n");
            return text;
        };
        
        lex.define("whitespace", ~/^([\s\n\r\t]+)/);
        
        lex.define("block comments", ~/^(\/\*)/,
            function(c, n) return Lexer.skipComments(n, "/*", "*/"));
            
        lex.define("block close comments", ~/^(\*\/)/,
            function(s) throw "PegParser: Mismatched close comments");
            
        lex.define("inline comments", ~/^(\/\/)/,
            function(c, n) return Lexer.skipComments(n, "//"));
            
        lex.define("identifier", ~/^([A-Z_][A-Z0-9_]*)/i,
            function(s) return TSymbol(s));
            
        lex.define("identifier", ~/^(\.)/,
            function(s) return TSymbol(s));
            
        lex.define("number", ~/^(-?[0-9]+)/,
            function(s) return TInt(Std.parseInt(s)));
            
        lex.define("string", ~/^(")/,
            function(c, n) return Lexer.string(n, '"'),
            function(s) return TString(s));
            
        lex.define("string", ~/^(')/,
            function(c, n) return Lexer.string(n, "'"),
            function(s) return TString(s));
            
        lex.define("regex", ~/^(\[)/,
            function(c, n) return Lexer.string(n, ']', true),
            function(s) return TRegex('[$s]', "!"));
            
        lex.define("regex", ~/^(~\/)/,
            function(c, n) return Lexer.regex(n, '/'),
            function(s)
            {
                var a = s.split("\t");
                return TRegex(a[0], a[1]);
            }
        );
            
        lex.define("bracket open", ~/^(\()/,
            function(s) return TBracket("(", true));
            
        lex.define("bracket close", ~/^(\))/,
            function(s) return TBracket("(", false));
            
            
        lex.define("curly open", ~/^(\{)/,
            function(s) return TBracket("{", true));
            
        lex.define("curly close", ~/^(\})/,
            function(s) return TBracket("{", false));
            
        lex.define("operators", ~/^(=|,|;|\||\/|-|\*|\+|\?|:|#|&|!|@|\$|%)/,
            function(s) return TOperator(s));
            
        return lex;
    }
    
    public function new(code:String)
    {
        this.code = code;
        this.tokens = lexer.tokenize(code);
        //trace(tokens.tokens);
    }
    

    
    public static function parse(code:String):Map<String, Rule>
    {
        var p = new PegParser(code);
        var c = p.parseRules();
        //trace(c); //return null;
        //Sys.exit(0);
        return c;
    }
    
    /*==================================================
        Optimizations
    ==================================================*/
    
    public function printRules(rules:Map<String, Rule>):Void
    {
        for (id in rules.keys())
        {
            var rule:Rule = rules[id];
            Console.println(id + " = " + rule);
        }
    }
    
    public function validateRules(rules:Map<String, Rule>):Void
    {
        var rhs = new Map<String, Int>();
        
        // collect all the IDs found in a rule
        function collectIds(rule:Rule):Void
        {
            switch (rule)
            {
                case Id(x):
                    rhs[x] = 1;
                    
                case Transform(a, b):
                    collectIds(a);
                    
                case _:
                    rule.iter(collectIds);
            }
        }
        
        // first pass, we get all IDs on RHS of the rules
        for (id in rules.keys())
            collectIds(rules[id]);
        
        // second pass, we filter unmatched ids
        for (id in rules.keys())
            rhs.remove(id);
        
        var undefined:Array<String> = [for (id in rhs.keys()) id];
        
        //trace(undefined);
        
        // rules used on rhs, but wasnt defined on lhs
        if (undefined.length > 0)
            throw "PegParser: Grammar has undefined rules: " + undefined.join(", ");
    }
    
    
    public inline function debug(msg:Dynamic):Void
    {
        if (debugOutput)
            Console.println(Text.of(" ").repeat(depth * 3) + Std.string(msg));
    }
    
    /*==================================================
        Methods
    ==================================================*/
    
    public function parseRules():Map<String, Rule>
    {
        var rules = new Map<String, Rule>();
        var n:Int = 0;
        
        while (tokens.hasNext())
        {
            var def = parseDefinition();
            
            if (rules.exists(def.head))
                throw "PegParser: Duplicate definition of " + def.head;
                
            // the first definition is the main one
            if (n == 0)
                rules.set("#start", Anon(Id(def.head)));
                
            rules.set(def.head, def.tail);
            
            ++n;
        }
        
        validateRules(rules);
        
        if (debugRules)
            printRules(rules);
            
        return rules;
    }
    
    // lhs = rhs;
    public function parseDefinition():Pair<String, Rule>
    {
        debug("definition " + tokens.current());
        ++depth;
        
        if (!tokens.hasNext())
            throw "PegParser: Unexpected EOF";
            
        var token:Token = tokens.current();
        
        var isAnon:Bool = switch (token)
        {
            case TOperator("$"):
                tokens.next();
                token = tokens.current();
                true;
                
            case _:
                false;
        }
        
        var lhs:String = switch (token)
        {
            case TSymbol(s):
                tokens.next();
                s;
                
            case _:
                throw "PegParser: Expected identifier";
        }
        
        tokens.expect(TOperator("="));
        var rhs:Rule = parseExpression(0);
        tokens.optional(TOperator(";"));
        
        if (isAnon)
            rhs = Anon(rhs);
        
        --depth;
        debug("end definition" + rhs);
        return Pair.of(lhs, rhs);
    }
    
    // Id
    // "str"
    // #"regex"
    // ( expr )
    // pri unop
    public function parsePrimary():Rule
    {
        debug("primary " + tokens.current());
        ++depth;
        
        if (!tokens.hasNext())
            throw "PegParser: Unexpected EOF";
            
        var token:Token = tokens.current();
        
        var curr:Rule = switch (token)
        {
            case TOperator(x) if (operators.isUnary(token, Left)):
                tokens.next();
                var op:OpInfo = operators.getUnary(token, Left);
                Rule.createByName(op.fn, [parseExpression(op.precedence)]);
                
            case TSymbol(x):
                tokens.next();
                
                switch (x.toLowerCase())
                {
                    case "epsilon":
                        Str("");
                        
                    case _:
                        Id(x);
                }
                
            case TInt(x):
                tokens.next();
                Num(x);
                
            case TString(x):
                tokens.next();
                Str(x);
                
            case TRegex(x, "!"):
                tokens.next();
                token = tokens.current();
                
                switch (token)
                {
                    case TOperator("*"):
                        tokens.next();
                        Rx(x + "*", "");
                        
                    case TOperator("+"):
                        tokens.next();
                        Rx(x + "+", "");
                        
                    case TOperator("?"):
                        tokens.next();
                        Rx(x + "?", "");
                        
                    case _:
                        Rx(x, "");
                }
                
            case TRegex(x, a):
                tokens.next();
                Rx(x, a);
                
            /*
            // this syntax is like instaparse's regex.
            // don't need this anymore since we're using
            // haxe's syntax.
            
            case TOperator("#"):
                tokens.next();
                token = tokens.current();
                
                switch (token)
                {
                    case TString(x):
                        tokens.next();
                        Rx(x, "");
                        
                        
                    case _:
                        throw "Expected regular expression string";
                }*/
                
            case TBracket("(", true):
                tokens.expect(TBracket("(", true));
                var next:Rule = parseExpression(0);
                tokens.expect(TBracket("(", false));
                next;
                
            case _:
                throw "PegParser: Unexpected token: " + token;
        }
        
        --depth;
        debug("end primary " + tokens.current());
        return curr;
    }
    
    
    /*
     * Magically turn spaces into commas or semicommas
     * where applicable
     */
    public function magicCommaInsertion():Void
    {
        // save position
        var pos:Int = tokens.i;
        
        try
        {
            // A _ B C  ==> A , B
            // A _ B =  ==> A ; B
            // A   *    ==> error
            
            // After parsing primary (B), see the next token.
            //
            // If it's an equal sign, it means B is a new rule,
            // so insert a semicolon before B.
            //
            // Otherwise, it's still part of the same rule,
            // so insert a comma before B.
            //
            // If parsePrimary fails, means its neither a sequence
            // nor the beginning of the next rule. It could
            // be some other operator or something. In that case,
            // don't do anything.
            
            parsePrimary();
            
            if (tokens.current().equals(TOperator("=")))
                tokens.tokens.insert(pos, TOperator(";"));
            else
                tokens.tokens.insert(pos, TOperator(","));
        }
        catch (ex:Dynamic)
        {
            // not a pri.. could be operator or other things
            --depth;
            debug("end primary " + tokens.current());
        }
        
        // restore position
        tokens.i = pos;
    }
    
    
    // expr: pri unop
    // expr: pri binop expr
    // expr: pri terop1 expr terop2 expr
    public function parseExpression(precedence:Int=0, ?primary:Rule):Rule
    {
        debug("expr " + tokens.current());
        ++depth;
        
        var curr:Rule = primary == null ? parsePrimary() : primary;
        var token:Token;
        
        magicCommaInsertion();
        
        while (tokens.hasNext() && operators.isBinary(tokens.current()))
        {
            token = tokens.current();
            debug("binop " + tokens.current());
            
            var op:OpInfo = operators.getBinary(token);
            if (op.precedence < precedence) break;
            
            debug("binop accepted " + tokens.current());
            
            tokens.next();
            
            var next:Rule = parseExpression(op.associativity == Left ?
                op.precedence + 1 :
                op.precedence);
                
            curr = Rule.createByName(op.fn, [curr, next]);
        }
        
        curr = parseUnary(precedence, curr);
        
        --depth;
        debug("end expr " + tokens.current());
        return curr;
    }
    
    // expr unop
    // expr unop binop expr
    public function parseUnary(precedence:Int, curr:Rule):Rule
    {
        debug("unary " + tokens.current());
        ++depth;
        
        var token:Token;
        
        // while loop allows chaining of unary expressions, eg:
        // id(a)[b](c)[d][e]++;
        while (tokens.hasNext() && operators.isUnary(tokens.current(), Right))
        {
            token = tokens.current();
            debug("unop " + tokens.current());
            
            var op:OpInfo = operators.getUnary(token, Right);
            
            if (!token.equals(TOperator(op.code)) || op.precedence < precedence)
                break;
            
            debug("unop accepted " + tokens.current());
            
            /*var subPrecedence:Int = op.associativity == Right ?
                op.precedence :
                op.precedence + 1;*/
            
            curr = switch (token)
            {
                case TOperator(x):
                    tokens.next();
                    Rule.createByName(op.fn, [curr]);
                    
                case _:
                    throw "PegParser: Not a unary operator: " + curr;
            }
            
            // parse the rest, eg: id(a)[b] + therest
            curr = parseExpression(precedence, curr);
        }
        
        --depth;
        debug("end unary " + tokens.current());
        return curr;
    }
}