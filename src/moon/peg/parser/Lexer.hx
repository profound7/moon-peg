package moon.peg.parser;

import moon.core.Pair;
import moon.tools.ERegTools;

using StringTools;

/**
 * ...
 * @author Munir Hussin
 */
class Lexer<T:EnumValue>
{
    public static var escapes =
    [
        "n".code => "\n",
        "r".code => "\r",
        "t".code => "\t",
        "'".code => "'",
        '"'.code => "\"",
        "\\".code => "\\",
    ];
    
    private var defs:Array<LexerDef<T>>;
    public var onInit:String->String;
    public var onUnknown:String->T;
    
    public function new()
    {
        defs = [];
    }
    
    /*==================================================
        Methods
    ==================================================*/
    
    public function define(name:String, rx:EReg, ?process:String->String->Pair<String, Int>, ?token:String->T):Void
    {
        defs.push(new LexerDef(name, rx, process, token));
    }
    
    public function tokenize(text:String):TokenStream<T>
    {
        return new TokenStream(parse(text));
    }
    
    public function parse(text:String):Array<T>
    {
        var out:Array<T> = [];
        
        if (onInit != null)
            text = onInit(text);
        
        while (text.length > 0)
        {
            var def:LexerDef<T> = find(text);
            
            if (def != null)
            {
                var curr:String = def.rx.matched(1);
                var next:String = def.rx.matchedRight();
                
                if (def.process != null)
                {
                    var info:Pair<String, Int> = def.process(curr, next);
                    curr = info.head;
                    next = next.substr(info.tail);
                }
                
                if (def.token != null)
                {
                    var val = def.token(curr);
                    
                    if (val != null)
                    {
                        out.push(val);
                    }
                }
                
                text = next;
            }
            else
            {
                throw "Lexer: Unknown pattern: " + text;
            }
        }
        
        return out;
    }
    
    public function find(text:String):LexerDef<T>
    {
        for (d in defs)
        {
            if (d.rx.match(text))
                if (d.rx.matchedPos().pos > 0)
                    throw "Lexer: Regular expression must start with ^ " + d.name + " -- " + text;
                else
                    return d;
        }
        
        return null;
    }
    
    
    /*==================================================
        Static methods
    ==================================================*/
    
    /**
     * This function skips block comments. It detects
     * nested block comments.
     */
    public static function skipComments(text:String, open:String, close:String=null, nested:Bool=false):Pair<String, Int>
    {
        var eopen = ERegTools.escape(open);
        var eclose = close != null ? ERegTools.escape(close) : "\\n|$";
        
        var depth:Int = 1;
        var pos:Int = 0;
        var rx:EReg = nested ? new EReg('($eopen|$eclose)', "m") : new EReg('($eclose)', "m");
        
        while (rx.match(text))
        {
            var m1:String = rx.matched(1);
            
            if (m1 == open)
            {
                ++depth;
            }
            else if (m1 == close || (close == null && (m1 == "" || m1 == "\n")))
            {
                --depth;
                if (depth < 0)
                    throw "Lexer: Unexpected EOF";
            }
            
            text = rx.matchedRight();
            var p = rx.matchedPos();
            pos += p.pos + p.len;
            
            if (depth == 0)
                break;
        }
        
        if (depth != 0)
            throw "Lexer: Unexpected EOF";
            
        return Pair.of(null, pos);
    }
    
    /**
     * This strips away all inline comments from the code.
     * It also detects and removes shebang line if it's there.
     */
    public static function removeShebang(text:String):String
    {
        var lines:Array<String> = text.split("\n");
        
        // remove shebang line if it's there
        if (lines.length > 0 && lines[0].startsWith("#!"))
            lines[0] = "";
        
        return lines.join("\n");
    }
    
    /**
     * Returns the string portion of the code.
     * It is expected for the code to already be in the string.
     * i.e. the code must not begin with "
     * The string will be parsed and escape sequences replaced
     * with the actual characters.
     */
    public static function string(code:String, end:String, ?escapes:Map<Int, String>, regexMode:Bool=false):Pair<String, Int>
    {
        if (escapes == null)
            escapes = Lexer.escapes;
            
        var out:StringBuf = new StringBuf();
        var i:Int = 0;
        var n:Int = code.length;
        
        while (i < n)
        {
            var char:Int = code.fastCodeAt(i);
            var next:Int;
            
            // start of escape sequence
            if (char == "\\".code)
            {
                if (regexMode)
                {
                    out.addChar(char);
                    
                    ++i;
                    if (i >= n) throw "Lexer: Invalid string";
                    
                    next = code.fastCodeAt(i);
                    out.addChar(next);
                }
                else
                {
                    ++i;
                    
                    if (i >= n) throw "Lexer: Invalid string";
                    
                    // get next character
                    next = code.fastCodeAt(i);
                    
                    if (escapes.exists(next))
                    {
                        out.add(escapes[next]);
                    }
                    else
                    {
                        throw "Lexer: Invalid escape sequence ";
                    }
                }
            }
            else if (code.substr(i, end.length) == end)
            {
                return Pair.of(out.toString(), i + end.length);
            }
            else
            {
                out.addChar(char);
            }
            
            ++i;
        }
        
        throw "Invalid string";
    }
    
    public static function regex(code:String, end:String):Pair<String, Int>
    {
        var info:Pair<String, Int> = string(code, end, null, true);
        var curr:String = info.head;
        var next:String = code.substr(info.tail);
        var rx:EReg = ~/^([a-z]+)/i;
        
        if (rx.match(next))
        {
            info.head = curr + "\t" + rx.matched(1);
            info.tail += rx.matchedPos().len;
        }
        else
        {
            info.head = curr + "\t";
        }
        
        return info;
    }
}

class LexerDef<T:EnumValue>
{
    public var name:String;
    public var rx:EReg;
    public var process:String->String->Pair<String, Int>;
    public var token:String->T;
    
    public function new(name:String, rx:EReg, process:String->String->Pair<String, Int>, token:String->T)
    {
        this.name = name;
        this.rx = rx;
        this.process = process;
        this.token = token;
    }
}


enum LexerAction
{
    Ignore;
    Terminate;
    Parse(lex:Lexer<Dynamic>);
}