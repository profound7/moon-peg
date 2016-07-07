package moon.peg.parser;

/**
 * ...
 * @author Munir Hussin
 */
class TokenStream<T:EnumValue>
{
    public var tokens:Array<T>;
    public var i:Int;
    
    public function new(tokens:Array<T>)
    {
        this.tokens = tokens;
        this.i = 0;
    }
    
    /**
     * checks if current token is available
     */
    public inline function hasNext():Bool
    {
        return i < tokens.length;
    }
    
    /**
     * returns current token and then increment pointer
     */
    public inline function next():T
    {
        //trace(current());
        return hasNext() ? tokens[i++] : null;
    }
    
    /**
     * returns current token without incrementing pointer
     */
    public inline function current():T
    {
        return peek(0);
    }
    
    /**
     * returns token at an offset
     */
    public inline function peek(offset:Int=0):T
    {
        return i + offset < tokens.length ? tokens[i + offset] : null;
    }
    
    /**
     * Checks if current token equals to `token`.
     * Increments index if token matches.
     * Error thrown if token doesn't match.
     */
    public function expect(token:T):Void
    {
        if (token.equals(current()))
            ++i;
        else
            throw "Expected token " + token + " but got " + current();
    }
    
    /**
     * Checks if current token equals to `token`.
     * Increments index if token matches.
     * Index unchanged if token doesn't match.
     */
    public function optional(token:T):Bool
    {
        if (token.equals(current()))
        {
            ++i;
            return true;
        }
        else
        {
            return false;
        }
    }
}