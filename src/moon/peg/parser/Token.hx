package moon.peg.parser;

/**
 * ...
 * @author Munir Hussin
 */
enum Token
{
    TBracket(x:String, open:Bool);
    
    TInt(x:Int);
    TFloat(x:Float);
    TString(x:String);
    TRegex(x:String, a:String);
    TSymbol(x:String);
    TOperator(x:String);
    
    TTrue;
    TFalse;
    TNull;
}