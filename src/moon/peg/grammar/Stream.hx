package moon.peg.grammar;

import moon.core.Console;
import moon.core.Symbol;
import moon.core.Text;
import moon.peg.grammar.Rule;
import moon.peg.grammar.ParseTree;

using StringTools;
using moon.tools.ArrayTools;

/**
 * PEG parser with memoization (Packrat parser)
 * 
 *      https://en.wikipedia.org/wiki/Parsing_expression_grammar
 * 
 * In order to support direct and indirect left recursion, I've
 * implemented the algorithm by Warth, Douglass, Millstein from
 * the URL below:
 * 
 *      http://www.vpri.org/pdf/tr2007002_packrat.pdf
 * 
 * Memoization speeds up parsing a bit, but uses more memory,
 * especially for parsing that has a lot of backtracking.
 * 
 * Also, some ideas adapted from:
 * 
 *      https://github.com/Engelberg/instaparse
 * 
 * Notes:
 *      - There's only ordered choice (PEG), no unordered choice (CFG)
 *      - Only results of Id (identifiers) are memoized currently
 *          (Other rules like Seq, Str etc.. are not memoized)
 * 
 * @author Munir Hussin
 */
class Stream
{
    private static var debugOutput:Bool = true;
    
    public var text:String;
    public var rules:Map<String, Rule>;
    
    public var i:Int;
    public var depth:Int;
    
    public var cache:Cache;
    public var heads:Map<Int, Head>;
    public var recursionStack:RecursionInfo;
    public var errors:Array<String>;
    
    public var rxCache:Array<EReg>;
    public var object:Dynamic;
    
    
    public function new(text:String, rules:Map<String, Rule>)
    {
        this.text = text;
        this.rules = rules;
        
        this.i = 0;
        this.depth = 0;
        
        this.cache = new Cache();
        this.heads = new Map<Int, Head>();
        this.errors = [];
    }
    
    public inline function get(offset:Int=0):String
    {
        return text.substr(i + offset);
    }
    
    /**
     * checks if stream has ended
     */
    public inline function hasEnded():Bool
    {
        return i < text.length;
    }
    
    public inline function equals(s:String):Bool
    {
        return text.substr(i, s.length) == s;
    }
    
    public inline function consume(n:Int)
    {
        i += n;
    }
    
    public function expect(s:String)
    {
        if (equals(s))
            consume(s.length);
        else
            throw "Expected " + s;
    }
    
    public function error(pos:Int, msg:String):ParseTree
    {
        var p:PositionInfo = position(pos);
        var err:String = 'Line ${p.line}, column ${p.column}: $msg';
        errors.push(err);
        //return Error(err);
        return Error;
    }
    
    public function position(p:Int):PositionInfo
    {
        var line:Int = 0;
        var column:Int = p + 1;
        
        var s:Text = text.substr(0, p);
        var nlCount = s.count("\n");
        
        line = nlCount + 1;
        
        if (nlCount > 0)
        {
            var pos = s.lastIndexOf("\n");
            column = s.length - pos;
        }
        
        return { offset: p, line: line, column: column };
    }
    
    #if debug
        public function debug(msg:Dynamic):Void
        {
            if (debugOutput)
                Console.println(Text.of(" ").repeat(depth * 3) + Std.string(msg));
        }
    #else
        public macro function debug(a:haxe.macro.Expr, b:Array<haxe.macro.Expr>)
        {
            return macro null;
        }
    #end
    
    /*==================================================
        Left Recursion Support
    ==================================================*/
    
    // I left the argument/variable names the same as
    // on that PDF for easier debugging.
    
    /**
     * Grow-LR method from the Warth et al paper.
     * This is used to handle left recursive rules.
     */
    private function grow(rule:String, pos:Int, info:CacheData, head:Head):ParseTree
    {
        // line A
        heads[pos] = head;
        
        while (true)
        {
            i = pos;
            
            // line B
            head.evalSet = head.involvedSet.copy();
            var ans:ParseTree = eval(rule);
            
            if (ans == Error || i <= info.pos)
                break;
                
            info.ans = ans;
            info.pos = i;
        }
        
        // line C
        heads.remove(pos);
        
        i = info.pos;
        return info.ans;
    }
    
    /**
     * Retrieve cached results
     */
    private function recall(R:String, P:Int):CacheData
    {
        var m = cache.get(P, R);
        var h = heads[P];
        
        // if not growing a seed parse, just return what is
        // stored in the memo table
        if (h == null)
            return m;
            
        // do not eval any rule that is not involved in
        // this left recursion
        if (m == null && ![h.rule].concat(h.involvedSet).contains(R))
        {
            //return new CacheData(P, Error("recursion"));
            return new CacheData(P, Error);
        }
            
        // allow involved rules to be evaluated, but only once,
        // during a seed-growing iteration
        if (h.evalSet.contains(R))
        {
            h.evalSet.remove(R);
            var ans = eval(R);
            m.ans = ans;
            m.pos = i;
        }
        
        return m;
    }
    
    /**
     * Left recursion is detected.
     * So initialize the left recursion info.
     */
    private function setup(R:String, L:RecursionInfo):Void
    {
        if (L.head == null)
            L.head = new Head(R, [], []);
            
        var s = recursionStack;
        
        while (s.head != L.head)
        {
            s.head = L.head;
            //L.head.involvedSet = L.head.involvedSet.union([s.rule]);
            L.head.involvedSet.push(s.rule);
            s = s.next;
        }
    }
    
    private function answer(R:String, P:Int, M:CacheData):ParseTree
    {
        var lr:RecursionInfo = switch (M.ans)
        {
            case Recursion(lr):
                lr;
                
            case _:
                throw "Expected recursion, got " + M.ans;
        }
        
        var h:Head = lr.head;
        
        if (h.rule != R)
        {
            return lr.seed;
        }
        else
        {
            M.ans = lr.seed;
            if (M.ans == Error)
                return M.ans;
            else
                return grow(R, P, M, h);
        }
    }
    
    
    private inline function eval(R:String):ParseTree
    {
        var result = matchRule(rules[R]);
        
        return switch (result)
        {
            case Error:
                result;
                    
            case Tree(v):
                v;
                
            case _:
                Node(R, result);
        }
    }
    
    private function applyRule(R:String, P:Int):ParseTree
    {
        var m = recall(R, P);
        
        if (m == null)
        {
            // create new LR and push it onto rule invocation stack
            //var lr = new RecursionInfo(Error("Left recursion"), R, null, recursionStack);
            var lr = new RecursionInfo(Error, R, null, recursionStack);
            recursionStack = lr;
            
            // memoize lr, then eval R
            m = new CacheData(P, Recursion(lr));
            cache.set(P, R, m);
            var ans = eval(R);
            
            // pop lr off the rule invocation stack
            recursionStack = recursionStack.next;
            m.pos = i;
            
            if (lr.head != null)
            {
                lr.seed = ans;
                return answer(R, P, m);
            }
            else
            {
                m.ans = ans;
                return ans;
            }
        }
        else
        {
            i = m.pos;
            
            return switch (m.ans)
            {
                case Recursion(lr):
                    setup(R, lr);
                    lr.seed;
                    
                case _:
                    m.ans;
            }
        }
    }
    
    
    /*==================================================
        Match Methods
    ==================================================*/
    
    public function match(id:String):ParseTree
    {
        var rule:Rule = rules.exists(id) ?
            rules[id] :
            throw "No such grammar rule id: " + id;
            
        debug('match: $id start $i $rule');
        ++depth;
        
        var result = applyRule(id, i);
        
        --depth;
        debug('match: $id end $i $rule');
        
        return switch (result)
        {
            case Error:
                if (depth == 0)
                    throw errors;
                else
                    result;
                    
            case Tree(v):
                return v;
                
            case _:
                return result;
        }
    }
    
    public function matchRule(rule:Rule):ParseTree
    {
        var result:ParseTree = null;
        var pos:Int = i;
        
        //try
        //{
            switch (rule)
            {
                case Str(s):
                    result = matchStr(s);
                    
                case Transform(Rx(r, a), Num(g)):
                    var rx = new EReg("^" + r, a);
                    result = matchRx(rx, g);
                    
                case Rx(r, a):
                    var rx = new EReg("^" + r, a);
                    result = matchRx(rx, 0);
                    
                case Transform(Rxc(i), Num(g)):
                    result = matchRx(rxCache[i], g);
                    
                case Rxc(i):
                    result = matchRx(rxCache[i], 0);
                    
                case Id(id):
                    result = match(id);
                    
                case Seq(a, b):
                    result = matchSeq(a, b);
                    
                case Or(a, b):
                    result = matchOr(a, b);
                    
                case Any(a, b):
                    result = matchAny(a, b);
                    
                case ZeroOrMore(r):
                    result = matchZeroOrMore(r);
                    
                case OneOrMore(r):
                    result = matchOneOrMore(r);
                    
                case ZeroOrOne(r):
                    result = matchZeroOrOne(r);
                    
                case Ahead(r):
                    result = matchAhead(r);
                    
                case NotAhead(r):
                    result = matchNotAhead(r);
                    
                // special operations
                case Hide(r):
                    result = matchHide(r);
                    
                case Pass(r):
                    result = matchPass(r);
                    
                case Transform(r, t):
                    result = matchTransform(r, t);
                    
                case Anon(r):
                    result = matchAnon(r);
                    
                case _:
                    throw 'Unexpected rule $rule';
            }
        //}
        /*catch (ex:String)
        {
            result = error(pos, ex);
        }
        catch (ex:Dynamic)
        {
            result = error(pos, "Unexpected error: " + ex);
        }*/
        
        
        if (result == Error)
        {
            // didn't match, so restore position
            //trace(ex);
            debug('err $rule');
            i = pos;
        }
        #if debug
            else debug('ok: $result : $rule');
        #end
        
        return result;
    }
    
    /**
     * "A"
     * String matching
     */
    public function matchStr(s:String):ParseTree
    {
        var sub = text.substr(i, s.length);
        
        if (sub == s)
        {
            consume(s.length);
            return Value(s);
        }
        else
        {
            return error(i, 'Expected $s');
        }
    }
    
    /**
     * ~/[A-Z]+/i
     * Regular expression matching
     * @param r     the regular expression string
     * @param a     options, such as m for multiline, i for case insensitive
     * @param g     which group to consume
     */
    public function matchRx(rx:EReg, g:Int):ParseTree
    {
        //if (x.match(get()) && x.matchedPos().pos == 0)
        if (rx.match(get()))
        {
            if (rx.matchedPos().pos > 0)
                throw "Unexpected error. Matched position should be 0";
            
            var s:String = rx.matched(g);
            //expect(s);
            //return Value(s);
            return matchStr(s);
        }
        else
        {
            return error(i, "Expected regex " + rx);
        }
    }
    
    /**
     * Sequence: A B
     * Both A and B must match
     * This version does not match backreferences
     */
    public function matchSeqOld(a:Rule, b:Rule):ParseTree
    {
        var ta:ParseTree = matchRule(a);
        
        if (ta == Error)
            return ta;
        
        var tb:ParseTree = matchRule(b);
        
        if (tb == Error)
            return tb;
        
        // nested sequences returns a single array instead of nested array
        var results:Array<ParseTree> = [];
        results = addToResults(results, ta);
        results = addToResults(results, tb);
        
        // success!
        return Multi(results);
    }
    
    /**
     * Sequence: A B
     * Both A and B must match
     * 
     * You can use numbers as backreferences.
     * Example:
     *      S = ~/[a-z]+/
     *      D = ~/[0-9]+/
     *      X = D / S D 0
     * 
     * In rule X, there are 2 sequences, D and S D 0.
     * Sequence numbering starts from 0, so S is index 0
     * and so on.
     * 
     * If S matches "cat", then 0 will check for "cat",
     * since the 0th item in the sequence is S.
     * 
     * So rule X will match cat123cat but not cat123dog
     */
    public function matchSeq(a:Rule, b:Rule, ?results:Array<ParseTree>):ParseTree
    {
        if (results == null)
            results = [];
            
        var ta:ParseTree = switch(a)
        {
            case Num(i):
                var r = results[i];
                var s = flattenTree(r, "");
                matchStr(s);
                
            case _:
                matchRule(a);
        }
        
        if (ta == Error)
            return ta;
            
        // add rule A's result
        results.push(ta);
            
        var tb:ParseTree = switch(b)
        {
            case Num(i):
                var r = results[i];
                var s = flattenTree(r, "");
                matchStr(s);
                
            case Seq(x, y):
                matchSeq(x, y, results);
                
            case _:
                matchRule(b);
        }
        
        
        if (tb == Error)
            return tb;
        
        // nested sequences returns a single array instead of nested array
        var results:Array<ParseTree> = [];
        results = addToResults(results, ta);
        results = addToResults(results, tb);
        
        // success!
        return Multi(results);
    }
    
    /**
     * Ordered choice: A / B
     * Either A or B or Error, in order
     */
    public function matchOr(a:Rule, b:Rule):ParseTree
    {
        var ta:ParseTree = matchRule(a);
        
        // success!
        if (ta != Error)
            return ta;
        
        var tb:ParseTree = matchRule(b);
        
        // success!
        if (tb != Error)
            return tb;
            
        // error
        var ea = flattenRule(a);
        var eb = flattenRule(b);
        return error(i, 'Expected $ea or $eb');
    }
    
    /**
     * Greedy choice: A | B
     * Non-standard behavior.
     * 
     * Returns whichever consumes more of the stream.
     * If both consumes the stream in the same amount,
     * the first result is used.
     * 
     * This is obviously slower than A / B
     * since both possibilities needs to be checked,
     * instead of stopping when a success was found.
     */
    public function matchAny(a:Rule, b:Rule):ParseTree
    {
        // remember initial position
        var pos:Int = i;
        var ta:ParseTree = matchRule(a);
        var posA:Int = i;
        
        // reset position to try the other path
        i = pos;
        var tb:ParseTree = matchRule(b);
        var posB:Int = i;
        
        // both error
        if (ta == Error && tb == Error)
        {
            var ea = flattenRule(a);
            var eb = flattenRule(b);
            
            i = pos;
            return error(i, 'Expected $ea or $eb');
        }
        else
        {
            if (ta == Error)
            {
                i = posB;
                return tb;
            }
            else if (tb == Error)
            {
                i = posA;
                return ta;
            }
            else if (posA >= posB)
            {
                i = posA;
                return ta;
            }
            else
            {
                i = posB;
                return tb;
            }
        }
    }
    
    /**
     * A*
     * Match none or more, greedily.
     * 
     * Note that (A* A) will always fail, since the first part (A*)
     * will leave nothing behind for the second part (A) to match.
     */
    public function matchZeroOrMore(r:Rule):ParseTree
    {
        var results:Array<ParseTree> = [];
        var tr:ParseTree;
        var pos:Int = 0;
        
        while (true)
        {
            pos = i;
            tr = matchRule(r);
            
            // stop when
            // - there is no progress when matching the rule
            // - the current rule produces an error
            if (i <= pos || tr == Error)
            {
                break;
            }
            
            // no error, so add it in
            results = addToResults(results, tr);
            //results.push(tr);
        }
        
        if (results.length == 0)
            return Empty;
        else
            return Multi(results);
    }
    
    /**
     * A+       == A A*
     * Match one or more, greedily.
     * 
     * Note that (A+ A) will always fail, since the first part (A+)
     * will leave nothing behind for the second part (A) to match.
     */
    public function matchOneOrMore(r:Rule):ParseTree
    {
        var ta = matchRule(r);
        
        // error: matches zero
        if (ta == Error)
            return ta;
            
        // already matched one, now match the rest
        var tb = matchZeroOrMore(r);
        
        return switch (tb)
        {
            case Empty:
                Multi(addToResults([], ta));
                
            case Multi(a):
                var results:Array<ParseTree> = [];
                results = addToResults(results, ta);
                results = addToResults(results, tb);
                Multi(results);
                
            case _:
                throw "Unexpected results";
        }
    }
    
    /**
     * A?
     * Match none or one
     */
    public inline function matchZeroOrOne(r:Rule):ParseTree
    {
        var tr = matchRule(r);
        return tr == Error ? Empty : tr;
    }
    
    
    /**
     * Matches the rule, but does not consume.
     * Returns the match results.
     * Used by matchAhead and matchNotAhead.
     */
    public inline function matchPeek(r:Rule):ParseTree
    {
        var pos:Int = i;
        var tr:ParseTree = matchRule(r);
        i = pos;
        return tr;
    }
    
    /**
     * &A
     * Look-Ahead
     */
    public inline function matchAhead(r:Rule):ParseTree
    {
        var tr = matchPeek(r);
        return tr == Error ? tr : Empty;
    }
    
    /**
     * !A
     * Negative look-Ahead
     */
    public inline function matchNotAhead(r:Rule):ParseTree
    {
        var tr = matchPeek(r);
        return tr == Error ? Empty : tr;
    }
    
    /**
     * @A
     * Hide. Matches the rule and consumes, but will
     * return an Empty result instead if successful.
     */
    public inline function matchHide(r:Rule):ParseTree
    {
        var tr = matchRule(r);
        return tr == Error ? tr : Empty;
    }
    
    /**
     * $A
     * Unwraps a Node.
     * If the result of rule A is Node(id, val), val will be returned.
     * Otherwise, the original result is returned.
     */
    public inline function matchPass(r:Rule):ParseTree
    {
        var tr = matchRule(r);
        
        return switch (tr)
        {
            case Node(_, x):
                x;
                
            case _:
                tr;
        }
    }
    
    /**
     * Rule definition result will not be wrapped in Node.
     * Instead, the original value is returned.
     * 
     * e.g.
     *      A = X                   ==> Node("A", resultX)
     *      $A = X  ==> A = Anon(X) ==> resultX
     */
    public inline function matchAnon(r:Rule):ParseTree
    {
        var tr = matchRule(r);
        return tr == Error ? tr : Tree(tr);
    }
    
    /**
     * A:X
     * Node transformation.
     * 
     *      A:Id
     *      Will wrap the result into Node(Id, result)
     * 
     *      A:","
     *      Will flatten the result into a single Value.
     *      The string is used as seperator to join arrays.
     *      To merge into a single string, use A:""
     * 
     *      A:2     (or any number)
     *      If the result is a multi, return index 2 (or any number)
     */
    public inline function matchTransform(r:Rule, t:Rule):ParseTree
    {
        var tr = matchRule(r);
        return tr == Error ? tr : transform(tr, t);
    }
    
    /**
     * Transforms a ParseTree according to some rules.
     */
    public function transform(result:ParseTree, t:Rule):ParseTree
    {
        return switch (t)
        {
            // A:B
            // wrap result with Node
            case Id(x):
                Node(x, result);
                
            // A:","
            // flatten to string with seperator
            case Str(x):
                Value(flattenTree(result, x));
                
            // A:n
            // return nth item
            case Num(x):
                
                if (x == 0)
                {
                    result;
                }
                else switch (result)
                {
                    case Multi(a) | Node(_, Multi(a)):
                        a[x - 1];
                        
                    case _:
                        throw "Result is not a Multi";
                }
                
            // A:$custom
            // call a custom transformation function
            case Pass(Id(x)):
                var obj = this.object;
                
                if (obj == null)
                    throw 'No object set for custom transformation';
                    
                var field = Reflect.field(obj, x);
                
                if (field == null)
                    throw 'Object does not have field $x';
                
                var ret:Dynamic = Reflect.callMethod(obj, field, [result]);
                var type = Type.typeof(ret);
                
                switch (type)
                {
                    case Type.ValueType.TEnum(ParseTree):
                        ret;
                        
                    case _:
                        throw 'Custom transformation should return a ParseTree, got: $type';
                }
                
                
            case Seq(x, y):
                
                var head = transform(result, x);
                var rest = transform(result, y);
                
                var ret:Array<ParseTree> = [];
                ret = addToResults(ret, head);
                ret = addToResults(ret, rest);
                Multi(ret);
                
            case Transform(x, y):
                
                var head = transform(result, x);
                var next = transform(head, y);
                next;
                
            case _:
                //error(i, 'Not an identifier: $t');
                throw 'Unexpected transformation rule $t';
        }
    }
    
    
    
    /**
     * Flattens a tree into a String.
     * This can be used to combine disjoint Values into a single Value
     */
    public function flattenTree(tree:ParseTree, seperator:String):String
    {
        return switch (tree)
        {
            case Empty:
                "";
                
            case Value(v):
                Std.string(v);
                
            case Multi(a):
                [for (x in a) flattenTree(x, seperator)].join(seperator);
                
            case Node(_, x):
                flattenTree(x, seperator);
                
            case _:
                throw "Invalid value";
        }
    }
    
    /**
     * Add a new result into results array, while taking care
     * of Empty results and nested arrays.
     */
    private inline function addToResults(results:Array<ParseTree>, t:ParseTree):Array<ParseTree>
    {
        return switch (t)
        {
            case Empty:
                results;
                
            case Multi(a):
                results = results.concat(a);
                
            case _:
                results.push(t);
                results;
        }
    }
    
    /**
     * Flattens a rule into a single String for error output.
     */
    public function flattenRule(r:Rule):String
    {
        return switch (r)
        {
            case Str(s):
                '"$s"';
                
            case Num(x):
                '$x';
                
            case Rx(s, a):
                '~/$s/$a';
                
            case Rxc(i):
                'rx[$i]';
                
            case Id(s):
                'id($s)';
                
            case Seq(a, b):
                flattenRule(a) + " " + flattenRule(b);
                
            case Or(a, b):
                flattenRule(a) + " or " + flattenRule(b);
                
            case Any(a, b):
                flattenRule(a) + " or " + flattenRule(b);
                
            case ZeroOrMore(r):
                flattenRule(r) + "*";
                
            case OneOrMore(r):
                flattenRule(r) + "+";
                
            case ZeroOrOne(r):
                flattenRule(r) + "?";
                
            case Ahead(r):
                "&" + flattenRule(r);
                
            case NotAhead(r):
                "!" + flattenRule(r);
                
            case Transform(r, _):
                flattenRule(r);
                
            case Hide(r) | Pass(r) | Anon(r):
                flattenRule(r);
        }
    }
}

typedef PositionInfo =
{
    var offset:Int;
    var line:Int;
    var column:Int;
}

class Cache // (Position, RuleId)
{
    private var data:Map<Int, Map<String, CacheData>>;
    
    public function new()
    {
        data = new Map<Int, Map<String, CacheData>>();
    }
    
    public function get(pos:Int, id:String):CacheData
    {
        if (!data.exists(pos))
            data[pos] = new Map<String, CacheData>();
        return data[pos][id];
    }
    
    public function set(pos:Int, id:String, value:CacheData):CacheData
    {
        if (!data.exists(pos))
            data[pos] = new Map<String, CacheData>();
        return data[pos][id] = value;
    }
}



class CacheData
{
    public var pos:Int;
    public var ans:ParseTree;
    
    public function new(pos:Int, ans:ParseTree)
    {
        this.pos = pos;
        this.ans = ans;
    }
}

class RecursionInfo
{
    public var seed:ParseTree;
    public var rule:String;
    public var head:Head;
    public var next:RecursionInfo;
    
    public function new(seed:ParseTree, rule:String, head:Head, next:RecursionInfo)
    {
        this.seed = seed;
        this.rule = rule;
        this.head = head;
        this.next = next;
    }
}

class Head
{
    public var rule:String;
    public var involvedSet:Array<String>;   // rules involved in left recursion
    public var evalSet:Array<String>;       // subset of involved rules
    
    public function new(rule:String, involvedSet:Array<String>, evalSet:Array<String>)
    {
        this.rule = rule;
        this.involvedSet = involvedSet;
        this.evalSet = evalSet;
    }
}