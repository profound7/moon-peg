package moon.peg.grammar;

import moon.core.Compare;
import moon.core.Symbol;
import moon.peg.grammar.Rule;

#if macro
    // TODO: REFACTOR and get rid of this Generic class
    import moon.peg.grammar.Generic;
    import haxe.macro.Context;
    import haxe.macro.Type;
    import haxe.macro.Expr;
    import haxe.macro.TypeTools;
#end

#if sys
    import sys.io.File;
#end

using StringTools;
using moon.peg.grammar.RuleTools;

/**
 * ParserBuilder generates a Parser class based on PEG input.
 * There's 3 ways of using this class.
 * 
 * 1. Use Parser class without class parameters, or 0 as parameter.
 *    This allows you to load any rules at runtime.
 *      
 *      var p = new Parser(peg);
 *      or
 *      var p:Parser<0> = new Parser<0>(peg);
 * 
 * 2. Use Parser class with String parameter.
 *    This uses haxe's genericBuild, so the file is processed
 *    at compile-time. You do not need the file at runtime.
 *      
 *      var p = new Parser<"my/package/Lisp.peg">();
 *      var ast = p.parse(codes);
 * 
 * 3. If you wish to modify the generated parser by hand:
 *      On non-sys targets:
 *          // how you get the peg text and
 *          // how you save the codes is up to you
 *          var rules = PegParser.parse(peg);
 *          var codes = new ParserBuilder(rules).buildParser("my.package.MyParser");
 *          // save the codes...
 * 
 *      On sys targets
 *          ParserBuilder.generate("lisp.peg", "my.package.MyParser", "../src");
 * 
 * @author Munir Hussin
 */
class ParserBuilder
{
    public var rules:Map<String, Rule>;
    
    #if macro
    public var fields:Array<Field>;
    
    public static function build():Type
    {
        var ltype:Type = Context.getLocalType();
        var bfields:Array<Field> = Context.getBuildFields();
        var fields:Array<Field> = [for (f in bfields) f];
        
        try
        {
            switch (ltype)
            {
                // var p:Parser<0>;
                case TInst(_, [TInst(_.get() => { kind:KExpr(macro 0) }, _)]):
                    return buildDefault(fields);
                    
                // var p = new Parser(data);
                case TInst(_, [TMono(_.get() => null)]):
                    return buildDefault(fields);
                    
                // var p = new Parser<"data/file.rules">();
                case TInst(_, [TInst(_.get() => { kind: KExpr(macro $v { (s:String) } ) }, _)]):
                    return buildFile(fields, s);
                    
                case _:
                    throw "ParserBuilder: Expected class";
            }
        }
        catch (ex:Dynamic)
        {
            var errors = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
            var errLines = errors.split("\n");
            
            trace("Error: ");
            trace(ex);
            
            for (e in errLines)
                trace(e);
                
            throw ex;
        }
        
        return null;
    }
    
    public static function fileContents(path:String):String
    {
        // make it work, even if used as a lib of other projects
        var file = Context.resolvePath(path);
        return File.getContent(file);
    }
    
    public static function buildDefault(fields:Array<Field>):Type
    {
        var name:String = "ParserBase";
        var kind:TypeDefKind = TDClass();
        
        if (Generic.isLocalTypeDefined(name))
        {
            return Generic.getLocalType(name);
        }
        
        Generic.addMethod(fields, false, null, null, [], [APublic], "new",
            [Generic.fnArg("data", macro:String)], macro:Void,
            "rules = PegParser.parse(data)");
        
        return Generic.defineLocalType(name, [], kind, fields);
    }
    
    public static function buildFile(fields:Array<Field>, filePath:String):Type
    {
        var name:String = "Parser_" + sanitize(filePath);
        var kind:TypeDefKind = TDClass();
        
        if (Generic.isLocalTypeDefined(name))
        {
            return Generic.getLocalType(name);
        }
        
        var input:String = fileContents(filePath);
        var rules:Map<String, Rule> = PegParser.parse(input);
        var builder:ParserBuilder = new ParserBuilder(rules);
        builder.fields = fields;
        builder.buildConstructor();
        
        return Generic.defineLocalType(name, [], kind, fields);
    }
    
    public static function sanitize(path:String):String
    {
        path = path.replace("_", "__");
        return ~/[^A-Z0-9]/gi.replace(path, "_");
    }
    
    #end
    
    #if sys
    
    public static function generate(pegPath:String, qualifiedClassName:String, classPath:String):Void
    {
        var peg = File.getContent(pegPath);
        var rules = PegParser.parse(peg);
        var builder = new ParserBuilder(rules);
        
        var codes = builder.buildParser(qualifiedClassName);
        var path = qualifiedClassName.replace(".", "/");
        
        if (classPath == null || classPath.trim() == "")
            classPath = "./";
        else if (!classPath.endsWith("/"))
            classPath += "/";
            
        path = classPath + path + ".hx";
        
        File.saveContent(path, codes);
    }
    
    #end
    
    public function new(rules:Map<String, Rule>)
    {
        this.rules = rules;
    }
    
    public function buildParser(qualifiedClassName:String):String
    {
        var ctor = buildConstructor();
        
        var packs = qualifiedClassName.split(".");
        var className = packs.pop();
        var pack = packs.join(".");
        
        var classCodes:Array<String> =
        [
            'package $pack;',
            '',
            'import moon.peg.grammar.Rule;',
            'import moon.peg.grammar.Stream;',
            'import moon.peg.grammar.ParseTree;',
            'using moon.peg.grammar.RuleTools;',
            '',
            '/**',
            ' * $className',
            ' * Auto-generated from ParserBuilder',
            ' * ',
            ' * @author Munir Hussin',
            ' */',
            'class $className',
            '{',
            '    public var rules:Map<String, Rule>;',
            '    ',
                ctor,
            '    ',
            '    public function parse(text:String, ?id:String):ParseTree',
            '    {',
            '        if (id == null) id = "#start";',
            '        var stream:Stream = new Stream(text, rules);',
            '        return stream.match(id);',
            '    }',
            '}',
        ];
        
        return classCodes.join("\n");
    }
    
    
    public function buildConstructor():String
    {
        var name:String = "new";
        var rulesCodes = [for (id in rules.keys())
            "            " + '"$id"' + " => " + ruleToString(rules[id])];
        
        var code1:Array<String> =
        [
            '    public function $name()',
            '    {',
            '        rules =',
            '        [',
                        rulesCodes.join(",\n"),
            '        ];',
            '        initCache();',
            '    }',
            '    ',
        ];
        
        #if macro
            // remove function signature and function braces
            code1.shift();
            
            //for (c in rulesCodes)
            //    trace(c);
            
            Generic.addMethod(fields, false, null, null, [], [APublic], name,
                [], macro:Void, code1.join("\n"));
                
        #end
        
        return code1.join("\n");
    }
    
    /*public function buildMethod(id:String, rule:Rule):String
    {
        var parseId:String = methodName(id, "parse");
        identifiers.set(id, "");
        
        var code1:Array<String> =
        [
            '    public function $parseId(text:String):ParseTree',
            '    {',
            '        var stream:Stream = new Stream(text, rules);',
            '        return stream.match("$id", true);',
            '    }',
            '    ',
        ];
        
        
        #if macro
            // remove function signature and function braces
            code1.shift();
            
            Generic.addMethod(fields, false, null, null, [], [APublic], parseId,
                [Generic.fnArg("text", macro:String)], macro:ParseTree, code1.join("\n"));
                
        #end
        
        return code1.join("\n");
    }*/
    
    public function ruleToString(rule:Rule, trackId:Bool=true):String
    {
        return rule.getName() + switch (rule)
        {
            case Str(s):
                var r = s
                    .replace('"', '\\"')
                    .replace("\n", "\\n")
                    .replace("\t", "\\t")
                    .replace("\r", "\\r");
                    
                '("$r")';
                
            case Rx(r, a):
                var r = r
                    .replace('\\', '\\\\')
                    .replace('"', '\\"');
                    
                var a = a.replace('"', '\\"');
                
                '("$r", "$a")';
                
            case Rxc(i):
                '($i)';
                
            case Num(x):
                '($x)';
                
            case Id(id):
                '("$id")';
                
            case Or(a, b) | Seq(a, b) | Any(a, b):
                var as = ruleToString(a, trackId);
                var bs = ruleToString(b, trackId);
                '($as, $bs)';
                
            case ZeroOrMore(r) | OneOrMore(r) | ZeroOrOne(r) |
                Ahead(r) | NotAhead(r) | Hide(r) | Pass(r) | Anon(r):
                var rs = ruleToString(r, trackId);
                '($rs)';
                
            case Transform(a, b):
                var as = ruleToString(a, trackId);
                var bs = ruleToString(b, false);
                '($as, $bs)';
                
            case _:
                throw "ParserBuilder: Unexpected rule: " + rule;
        }
    }
    
    
}
