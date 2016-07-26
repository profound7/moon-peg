package moon.peg.grammar;

/**
 * ...
 * @author Munir Hussin
 */
class RuleTools
{
    
    public static function iter(r:Rule, f:Rule->Void):Void
    {
        return switch (r)
        {
            case Str(_)
                | Rx(_, _)
                | Rxc(_)
                | Id(_)
                | Num(_):
            
            case Seq(a, b)
                | Or(a, b)
                | Any(a, b)
                | Transform(a, b):
                    f(a);
                    f(b);
                
            case ZeroOrMore(a)
                | OneOrMore(a)
                | ZeroOrOne(a)
                | Ahead(a)
                | NotAhead(a)
                | Hide(a)
                | Pass(a)
                | Anon(a):
                    f(a);
        }
    }
    
    public static function map(r:Rule, f:Rule->Rule):Rule
    {
        return switch (r)
        {
            case Str(_)
                | Rx(_, _)
                | Rxc(_)
                | Id(_)
                | Num(_):
                    r;
            
            case Seq(a, b): Seq(f(a), f(b));
            case Or(a, b): Or(f(a), f(b));
                
            case ZeroOrMore(a): ZeroOrMore(f(a));
            case OneOrMore(a): OneOrMore(f(a));
            case ZeroOrOne(a): ZeroOrOne(f(a));
                
            case Ahead(a): Ahead(f(a));
            case NotAhead(a): NotAhead(f(a));
            case Any(a, b): Any(f(a), f(b));
                
            case Hide(a): Hide(f(a));
            case Pass(a): Pass(f(a));
            case Anon(a): Anon(f(a));
                
            case Transform(a, b): Transform(f(a), f(b));
        }
    }
}