package moon.peg.grammar;

/**
 * These are the various operations available for the parsing grammar
 * @author Munir Hussin
 */
enum Rule
{
    // standard PEG rules
    Str(s:String);                      // "A"
    Rx(x:String, a:String);             // [A-Z]+   You can also use haxe's style regex ~/[A-Z]+/i
    Rxc(i:Int);                         //          Cached regex. i is the index
    Id(id:String);                      // A        Rule reference
    Num(x:Int);                         // 2        Used for backreferences
    
    Seq(a:Rule, b:Rule);                // A B      Sequence
    Or(a:Rule, b:Rule);                 // A / B    Ordered choice. Returns the first success.
    
    ZeroOrMore(r:Rule);                 // A*       Greedy 0 or more
    OneOrMore(r:Rule);                  // A+       Greedy 1 or more
    ZeroOrOne(r:Rule);                  // A?       Optional
    
    Ahead(r:Rule);                      // &A       Look-ahead. Does not consume match.
    NotAhead(r:Rule);                   // !A       Negative look-ahead. Does not consume match.
    
    // non-standard rules
    Any(a:Rule, b:Rule);                // A | B    Greedy choice. Both evaluated. Result that consumes more is used.
    
    // special operations
    Hide(r:Rule);                       // @A       Matches and consumes. If successful, return Empty instead.
    Pass(r:Rule);                       // $A       Unwrap result of A. i.e. $(Node("X", v)) ==> v
    Anon(r:Rule);                       // %A       Prevent creation of Node to current rule.
                                        //          $A = B      ==> A = %B
                                        //          Usage:
                                        //          A = B | %C
                                        //              if B matches ==> Node("A", resultOfB)
                                        //              if C matches ==> resultOfC
    
    Transform(r:Rule, ref:Rule);        // A:X      Wrap result of A to a Node (opposite of $A which unwraps).
                                        //              A:X ==> Node("X", resultOfA)
                                        // A:","    Flattens result into Value. String is delimiter for joining arrays.
                                        //              If resultOfA is Multi(["abc", "123", Node("b", Value("xyz"))])
                                        //              Then,
                                        //                  A:""    ==> Value("abc123xyz")
                                        //                  A:"-"   ==> Value("abc-123-xyz")
                                        // A:n      Where n is a number.
                                        //          If n is 0, the original result is returned.
                                        //          If A results in a Multi, return nth item of that Multi.
                                        //          If A results in a Node(_, Multi), return the nth item of that Multi.
                                        //          If A is a regular expression rule, return the nth captured group.
                                        //
                                        // A:(1 0)  Create Multi. You can use this to resequence result.
                                        //              If resultOfA is Multi(["abc", "123"])
                                        //              Then,
                                        //                  A:(2 1)     ==> Multi(["123", "abc"])
                                        //                  A:(2 1 0)   ==> Multi(["123", "abc", "abc", "123"]) // 0 is "abc", "123"
                                        //                  A:(2 1 2 1) ==> Multi(["123", "abc", "123", "abc"])
                                        //                  A:(2 "-" 1) ==> Multi(["123", "abc-123", "abc"])
                                        //          Transformations can be nested.
                                        //              The result of one transformation, can be further transformed,
                                        //              like in the following rule:
                                        //              A:(0:"-" 1)
                                        //
                                        // A:$f     Calls a custom transformation function (ParserTree->ParserTree).
                                        //          You need to set the value of parser.object to where
                                        //          the methods are.
                                        //          The method should look like:
                                        //              function foo (result:ParserTree):ParserTree
                                        //          And can be called with
                                        //              A:$foo
}
