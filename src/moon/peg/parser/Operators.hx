package moon.peg.parser;

/**
 * ...
 * @author Munir Hussin
 */
class Operators
{
    private var unlops:Map<String, OpInfo>;
    private var unrops:Map<String, OpInfo>;
    private var binops:Map<String, OpInfo>;
    private var terops:Map<String, OpInfo>;
    private var fns:Map<String, OpInfo>;
    
    
    public function new()
    {
        clear();
    }
    
    public function clear():Void
    {
        unlops = new Map<String, OpInfo>();
        unrops = new Map<String, OpInfo>();
        binops = new Map<String, OpInfo>();
        terops = new Map<String, OpInfo>();
        fns = new Map<String, OpInfo>();
    }
    
    public function add(op:OpInfo)
    {
        var map:Map<String, OpInfo> = switch (op.arity)
        {
            case Unary:
                
                switch (op.associativity)
                {
                    case Left:
                        unlops;
                        
                    case Right:
                        unrops;
                }
                
            case Binary:
                binops;
                
            case Ternary:
                terops;
        }
        
        map[op.code] = op;
        fns[op.fn] = op;
    }
    
    
    // isOperator("+")
    public inline function isOperator(code:String):Bool
    {
        return
            binops.exists(code) ? true :
            unlops.exists(code) ? true :
            unrops.exists(code) ? true :
            terops.exists(code) ? true :
            false;
    }
    
    // isOperatorName("Add");
    public inline function isOperatorName(name:String):Bool
    {
        return fns.exists(name);
    }
    
    
    private inline function extract(token:Token):String
    {
        return switch (token)
        {
            case TOperator(op):
                op;
                
            default:
                "";
        }
    }
    
    
    public inline function isUnary(token:Token, associativity:Associativity):Bool
    {
        return associativity == Left ?
            unlops.exists(extract(token)):
            unrops.exists(extract(token));
    }
    
    public inline function isBinary(token:Token):Bool
    {
        return binops.exists(extract(token));
    }
    
    public inline function isTernary(token:Token):Bool
    {
        return terops.exists(extract(token));
    }
    
    public function getUnary(token:Token, associativity:Associativity):OpInfo
    {
        return switch (token)
        {
            case TOperator(o):
                if (associativity == Left)
                    unlops[o];
                else
                    unrops[o];
                
            default:
                throw "Not a unary operator";
        }
    }
    
    public function getBinary(token:Token):OpInfo
    {
        return switch (token)
        {
            case TOperator(o):
                binops[o];
                
            default:
                throw "Not a binary operator";
        }
    }
    
    public function getTernary(token:Token):OpInfo
    {
        return switch (token)
        {
            case TOperator(o):
                terops[o];
                
            default:
                throw "Not a ternary operator";
        }
    }
}




class OpInfo
{
    public var code:String;
    public var precedence:Int;
    public var associativity:Associativity;
    public var arity:Arity;
    public var fn:String;
    
    public var code2:String;
    public var allowShortHand:Bool;
    
    public function new(code:String, code2:String, precedence:Int, associativity:Associativity, arity:Arity, fn:String, allowShortHand:Bool)
    {
        this.code = code;
        this.precedence = precedence;
        this.associativity = associativity;
        this.arity = arity;
        this.fn = fn;
        
        this.code2 = code2;
        this.allowShortHand = allowShortHand;
    }
    
    public static function unary(code:String, precedence:Int, associativity:Associativity, fn:String):OpInfo
    {
        return new OpInfo(code, null, precedence, associativity, Arity.Unary, fn, false);
    }
    
    public static function binary(code:String, precedence:Int, associativity:Associativity, fn:String):OpInfo
    {
        return new OpInfo(code, null, precedence, associativity, Arity.Binary, fn, false);
    }
    
    public static function ternary(code:String, code2:String, precedence:Int, associativity:Associativity, fn:String, allowShortHand:Bool):OpInfo
    {
        return new OpInfo(code, code2, precedence, associativity, Arity.Unary, fn, allowShortHand);
    }
}


enum Arity
{
    Unary;
    Binary;
    Ternary;
}

enum Associativity
{
    Left;
    Right;
}
