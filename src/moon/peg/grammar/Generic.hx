package moon.peg.grammar;

import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

/**
 * This is old shit written back when I wasn't really familiar with macros.
 * This is deprecated. ParserBuilder is currently referencing it.
 * 
 * @author Munir Hussin
 */
@:deprecated
class Generic
{
    #if macro
    
    public static function getId(e:Expr):String
    {
        switch (e.expr)
        {
            case EConst(CIdent(s)):
                return s;
            case _:
                throw e.toString() + " is not an Identifier";
        }
    }
    
    public static function getClassType(name:String):ClassType
    {
        switch (Context.getType(name))
        {
            case TInst(classType, _):
                return classType.get();
            case _:
                throw "Class not found";
        }
    }
    
    public static function makeTypeDef(pack:Array<String>, name:String, meta:Metadata, kind:TypeDefKind, fields:Array<Field>):TypeDefinition
    {
        var tdef:TypeDefinition =
        {
            pack: pack,
            name: name,
            pos: Context.currentPos(),
            meta: meta,
            kind: kind,
            fields: fields,
        };
        
        return tdef;
    }
    
    
    
    public static function getPackage():Array<String>
    {
        var ct:ComplexType = Context.getLocalType().toComplexType();
        
        if (ct == null)
            return Context.getLocalClass().get().pack;
            
        return switch (ct)
        {
            case TPath({pack: p}):
                p;
                
            case _:
                null;
        }
    }
    
    public static inline function getComplexType(type:String):ComplexType
    {
        return Context.typeof(parse('{var x:$type; x;}')).toComplexType();
    }
    
    public static inline function parse(code:String):Expr
    {
        return Context.parse(code, Context.currentPos());
    }
    
    public static function addMethod(fields:Array<Field>, isAbstract=false, selfType:ComplexType, ?doc:String, ?metadata:Metadata,
        access:Array<Access>, name:String, args:Array<FunctionArg>, ret:ComplexType, body:String)
    {
        if (metadata == null)
            metadata = [];
            
        // abstracts instance fields should still be static, but with @:impl
        /*if (isAbstract && access.indexOf(AStatic) == -1)
        {
            access.push(AStatic);
            metadata.push(meta(":impl"));
            args.unshift(fnArg("this", selfType));
        }*/
        
        fields.push(
        {
            name: name,
            doc: doc,
            access: access,
            kind: FieldType.FFun(
            {
                args: args,
                ret: ret,
                expr: parse(body),
            }),
            meta: metadata,
            pos: Context.currentPos(),
        });
    }
    
    public static function meta(name:String):MetadataEntry
    {
        return { name: name, pos: Context.currentPos() };
    }
    
    public static function fnArg(name:String, ?type:ComplexType):FunctionArg
    {
        return { name: name, type: type };
    }
    
    public static function fnArgsFromParams(params:Array<{t:Type}>):Array<FunctionArg>
    {
        return [for (i in 0...params.length)
            fnArg("arg"+i, params[i].t.toComplexType())];
    }
    
    public static function getParams(type:Type):Array<Type>
    {
        return switch (type)
        {
            case TInst(_, params):
                params;
                
            case t:
                Context.error("Class expected", Context.currentPos());
        }
    }
    
    public static function getParamNames():Array<String>
    {
        return Context.getLocalClass().get().params.map(function (p) return p.name);
    }
    
    public static function getTypeParameters():Array<TypeParameter>
    {
        return Context.getLocalClass().get().params;
    }
    
    public static function getConcreteTypes():Array<Type>
    {
        return getParams(Context.getLocalType());
    }
    
    public static function getBuildParams():StringMap<Type>
    {
        var params:Array<Type> = getParams(Context.getLocalType());
        var names:Array<String> = getParamNames();
        return [for (i in 0...params.length) names[i] => params[i]];
    }
    
    public static function getQualifiedType(pack:Array<String>, name:String):String
    {
        return pack.join(".") + "." + name;
    }
    
    public static function isLocalTypeDefined(name:String):Bool
    {
        try
        {
            Context.getType(getQualifiedType(getPackage(), name));
            return true;
        }
        catch (ex:Dynamic)
        {
            return false;
        }
    }
    
    public static function getLocalType(name:String):Type
    {
        return Context.getType(getQualifiedType(getPackage(), name));
    }
    
    public static function defineLocalType(name:String, meta:Metadata, kind:TypeDefKind, fields:Array<Field>):Type
    {
        var tdef:TypeDefinition = makeTypeDef(getPackage(), name, meta, kind, fields);
        Context.defineType(tdef);
        return getLocalType(name);
    }
    
    public static function replaceParam(ctype:ComplexType, params:StringMap<Type>):ComplexType
    {
        return switch (ctype)
        {
            case TPath(p):
                var type = params.get(p.name);
                
                if (type != null)
                    type.toComplexType();
                else
                    ctype;
                
            case TFunction(args, ret):
                TFunction(args.map(function(a) return replaceParam(a, params)),
                    replaceParam(ret, params));
                    
            case TAnonymous(fields):
                applyTypeParameters(fields, params);
                ctype;
                
            case TParent(t):
                TParent(replaceParam(t, params));
                
            case TExtend(p, fields):
                applyTypeParameters(fields, params);
                TExtend(p, fields);
                
            case TOptional(t):
                TOptional(replaceParam(t, params));
        }
    }
    
    public static function applyTypeParameters(fields:Array<Field>, params:StringMap<Type>):Void
    {
        for (f in fields)
        {
            switch (f.kind)
            {
                case FVar(t, e):
                    f.kind = FVar(replaceParam(t, params));
                    
                case FFun(fn):
                    for (a in fn.args)
                    {
                        a.type = replaceParam(a.type, params);
                    }
                    
                    if (fn.ret != null)
                        fn.ret = replaceParam(fn.ret, params);
                    
                case FProp(g, s, t, e):
            }
        }
    }
        
    private static function buildTest():Type 
    {
        var ltype:Type = Context.getLocalType();
        var pack:Array<String> = getPackage();
        var bfields:Array<Field> = Context.getBuildFields();
        
        // [{ name => T, t => TInst(moon.core.Blah.T,[]) }]
        //trace(Context.getLocalClass().get().params);
        //trace(bfields);
        
        
        var params = getBuildParams();
        //trace(params);
        
        
        
        if (isLocalTypeDefined("Hello"))
        {
            trace("type exists, returning from cache");
            return getLocalType("Hello");
        }
        
        trace("type does not exists. creating fresh.");
        
        applyTypeParameters(bfields, params);
        
        var fields:Array<Field> = [for (f in bfields) f];
        
        return defineLocalType("Hello", [], TDClass(), fields);
        
        /*
        switch (ltype)
        {
            case TInst(t, [TFun(args, ret)]):
                //trace(args.map(function(a) return a.t));
                
                var typeDef = makeTypeDef("Hello", TDClass());
                
                try
                {
                    var type:Type = Context.getType(typeDef.pack.join(".") + "." + typeDef.name);
                    trace("returning existing type");
                    return type.toComplexType();
                }
                catch (e:Dynamic) {}
                
                trace("creating new type");
                var fields:Array<Field> = typeDef.fields;
                
                addMethod(fields, null, null, [APublic], "new", [], null, 'trace("Hello!")');
                addMethod(fields, null, null, [APublic], "haha", fnArgsFromParams(args),
                    ret.toComplexType(), '{trace("gagaga!"); return true;}');
                    
                for (f in bfields)
                    fields.push(f);
                
                Context.defineType(typeDef);
                var type:Type = Context.getType("Hello");
                
                return type.toComplexType();
                
            case t:
                Context.error("Class expected", Context.currentPos());
        }
        
        return null;*/
    }
    
    #end
}
