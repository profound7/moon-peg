package moon.peg.parser;

import moon.core.Pair;
import moon.peg.grammar.ParseTree;
import moon.peg.parser.Operators;

using StringTools;

/**
 * ExprParser is a quick-n-dirty parser that you can extend from
 * if you need to have a parser that handles unary/binary/ternary operators
 * with user-definable associativity and precedence, using recursive descent.
 * 
 * NOTE: You should be able to accomplish similar with PEG located
 * at moon.peg.grammar.Parser.
 * 
 * TODO: This class is incomplete. I used this before I wrote the PEG parser.
 * And then I decided to refactor it since I used similar codes for
 * multiple different parsers, but I didn't complete the refactoring since
 * I wrote the PEG parser, which is more editable than a custom recursive
 * descent parser. Maybe I'll complete this in the future.
 * 
 * To see a similar custom recursive descent in use, see PegParser.
 * 
 * @author Munir Hussin
 */
class ExprParser
{
    public static var operators:Operators;
    public static var lexer:Lexer<Token>;
    
    public var code:String;
    public var tokens:TokenStream<Token>;
    
    public var primaries:Map<Int, >;
    
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
        ops.add(OpInfo.binary("+", i, Left, "+"));
        
        ++i;
        ops.add(OpInfo.binary("*", i, Left, "*"));
        
        ++i;
        ops.add(OpInfo.binary(":", i, Right, "cons"));
        
        ++i;
        ops.add(OpInfo.binary(".", i, Left, "."));
        
        ++i;
        ops.add(OpInfo.unary("'", i, Left, "quote"));
        ops.add(OpInfo.unary("`", i, Left, "backquote"));
        ops.add(OpInfo.unary(",", i, Left, "unquote"));
        ops.add(OpInfo.unary(",@", i, Left, "expand"));
        
        return ops;
    }
    
    public static function initLexer():Lexer<Token>
    {
        var lex = new Lexer<Token>();
        
        lex.onInit = function(text:String):String
        {
            text = StringTools.replace(text, "\r\n", "\n");
            text = Lexer.removeShebang(text);
            return text;
        };
        
        lex.define("block comments", ~/(\/\*)/m,
            function(c, n) return Lexer.skipComments(n, "/*", "*/"));
            
        lex.define("block close comments", ~/(\*\/)/m,
            function(s) throw "Mismatched close comments");
            
        lex.define("inline comments", ~/(\/\/)/m,
            function(c, n) return Lexer.skipComments(n, "//"));
            
        lex.define("whitespace", ~/([\s\n\r\t]+)/);
        
        lex.define("hex", ~/(0x[0-9A-F]+)/i,
            function(s) return TInt(Std.parseInt(s)));
            
        lex.define("float", ~/([-+]?((\d*\.\d+)([eE][-+]?\d+)?|(\d+)([eE][-+]?\d+)))/,
            function(s) return TFloat(Std.parseFloat(s)));
            
        lex.define("integer", ~/(-?[0-9]+)/,
            function(s) return TInt(Std.parseInt(s)));
            
        lex.define("true", ~/(true)/,
            function(s) return TTrue);
            
        lex.define("false", ~/(false)/,
            function(s) return TFalse);
            
        lex.define("null", ~/(null)/,
            function(s) return TNull);
            
        lex.define("string", ~/(")/,
            function(c, n) return Lexer.escape(n, '"'),
            function(s) return TString(s));
            
        lex.define("bracket open", ~/(\()/,
            function(s) return TBracket("(", true));
            
        lex.define("bracket close", ~/(\))/,
            function(s) return TBracket("(", false));
            
        lex.define("square open", ~/(\[)/,
            function(s) return TBracket("[", true));
            
        lex.define("square close", ~/(\])/,
            function(s) return TBracket("[", false));
            
        lex.define("curly open", ~/(\{)/,
            function(s) return TBracket("{", true));
            
        lex.define("curly close", ~/(\})/,
            function(s) return TBracket("{", false));
            
        lex.define("operators", ~/('|`|,@|,|@|\.|:)/,
            function(s) return TOperator(s));
            
        // everything else is a symbol
        lex.define("symbol", ~/([^\s\n\r\t()[\]{}'`,@.:]+)/,
            function(s) return TSymbol(s));
            
        return lex;
    }
    
    public function new(code:String)
    {
        this.code = code;
        this.tokens = lexer.tokenize("(" + code + ")");
        //trace(tokens.tokens);
    }
    
    
    
    /*==================================================
        Methods
    ==================================================*/
    
    public function parse(code:String):ParseTree
    {
        var i:Int = 0;
        var tmp:Array<ParseTree> = [];
        
        while (tokens.hasNext())
            tmp.push(parseExpression(0));
            
        return Arr(tmp);
    }
    
    
    // pri: unop expr
    // pri: atom
    // pri: list
    public function parsePrimary():ParseTree
    {
        if (!tokens.hasNext())
            throw "Unexpected EOF";
            
        var token:Token = tokens.current();
        var tokIdx:Int = token.getIndex();
        
        if (primaries.exists(tokIdx))
        {
            var fn = primaries[tokIdx];
            return fn(token);
        }
        else switch (token)
        {
            // unop expr
            case TOperator(op):
                
                if (operators.isUnary(token, Left))
                {
                    tokens.next();
                    
                    var op:OpInfo = operators.getUnary(token, Left);
                    return Node(op.fn, parseExpression(op.precedence));
                }
                else
                {
                    throw "Unexpected operator: " + op;
                }
                
            case _:
                throw "Unexpected token: " + token;
        }
    }
    
    // expr: seq unop
    // expr: seq binop expr
    // expr: seq terop1 expr terop2 expr
    public function parseExpression(precedence:Int=0, ?primary:ParseTree):ParseTree
    {
        var curr:ParseTree = primary == null ? parsePrimary() : primary;
        var token:Token;
        
        while (tokens.hasNext() && operators.isBinary(tokens.current()))
        {
            token = tokens.current();
            
            var op:OpInfo = operators.getBinary(token);
            if (op.precedence < precedence) break;
            
            tokens.next();
            
            var next:Rule = parseExpression(op.associativity == Left ?
                op.precedence + 1 :
                op.precedence);
                
            curr = Rule.createByName(op.fn, [curr, next]);
        }
        
        curr = parseTernary(precedence, curr);
        curr = parseUnary(precedence, curr);
        return curr;
    }
    
    // cond ? a : b
    // Primary TernaryOp1 Expression TernaryOp2 Expression
    public function parseTernary(precedence:Int, curr:ParseTree):ParseTree
    {
        var token:Token;
        
        while (tokens.hasNext() && operators.isTernary(tokens.current()))
        {
            token = tokens.current();
            
            var op:OpInfo = operators.getTernary(token);
            
            if (!token.equals(TOperator(op.code)) || op.precedence < precedence)
                break;
            
            var subPrecedence:Int = op.associativity == Right ? op.precedence : op.precedence + 1;
            var trueNode:ParseTree;
            var falseNode:ParseTree;
            tokens.next();
            
            // get the true part
            if (op.allowShortHand && tokens.current().equals(TOperator(op.code2)))
            {
                trueNode = Empty;
            }
            else
            {
                // we need to disable TOperator(op.code2) in the expression so
                // that we can detect that token manually afterwards
                trueNode = parseExpression(subPrecedence);
            }
            
            // get the false part
            tokens.expect(TOperator(op.code2));
            falseNode = parseExpression(subPrecedence);
            
            curr = Node(op.fn, Arr([curr, trueNode, falseNode]));
        }
        
        return curr;
    }
    
    // Expression PostUnaryOp
    public function parseUnary(precedence:Int, curr:ParseTree):ParseTree
    {
        var token:Token;
        
        // while loop allows chaining of unary expressions, eg:
        // id(a)[b](c)[d][e]++;
        while (tokens.hasNext() && operators.isUnary(tokens.current(), Right))
        {
            //trace("unary! " + token);
            //trace("  node: " + node);
            token = tokens.current();
            
            var op:OpInfo = operators.getUnary(token, Right);
            
            if (!token.equals(TOperator(op.code)) || op.precedence < precedence)
                break;
            
            var subPrecedence:Int = op.associativity == Right ? op.precedence : op.precedence + 1;
            
            //trace("  unary ACCEPTED!");
            curr = switch (token)
            {
                case TOperator(x):
                    tokens.next();
                    Node(op.fn, curr);
                    
                case _:
                    throw "Not a unary operator: " + curr;
            }
            
            // parse the rest, eg: id(a)[b] + therest
            curr = parseExpression(subPrecedence, curr);
        }
        
        return curr;
    }
}

