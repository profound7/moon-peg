# Possible changes/ideas for version 1.0

## Constants

These should be available using an import.
Maybe an `import const`.

Type       | Const          | Description
-----------|----------------|-------------
?          | ALNUM          | [A-Za-z0-9]
?          | ALPHA          | [A-Za-z]
?          | ASCII          | ASCII characters
?          | CONTROL        | control characters
?          | DIGIT          | [0-9]
?          | GRAPH          | visible characters
?          | LOWER          | [a-z]
?          | PRINT          | GRAPH / BLANK
?          | PUNCTUATION    | punctuation characters
?          | UPPER          | [A-Z]
?          | HEX            | [0-9A-Fa-f] hexadecimal digits
?          | IDENT          | alphanumeric and _
Special    | .              | matches any single character
Special    | E              | alias of EPSILON, matches empty string
Special    | EPSILON        | matches empty string
Special    | EOF            | end of file
Whitespace | SPACE          | `\r` / `\n` / `\t` / `\s`
Whitespace | SPACES         | SPACE*
Whitespace | TAB            | `\t`
Whitespace | BLANK          | SPACE / TAB
Whitespace | CR             | `\r`
Whitespace | LF             | `\n`
Whitespace | CRLF           | `\r` `\n` sequence
Whitespace | NEWLINE        | CRLF / LF / CR


## Notations

These are not finalized yet. The meaning of the symbols should be consistent.
Currently, there's $A to unwrap on LHS, but %A to unwrap on RHS, which is inconsistent.
Below, $A on the LHS and $A on the RHS has the same meaning of "unwrap".

- &#35; comment
- & ahead
- ! not-ahead
- $ backreference
- % unwrap
- ^ non-capturing
- ~ regex
- : transform (can be used to wrap)
- @ function call

name            | example           | description
----------------|-------------------|----------------------------
comment         | # whatever        | single-line comment
reference       | x = a             | non-terminal reference `Node("a", x)`
non-capturing   | x = %a            | if match, return Empty instead
non-capturing   | %x = a            | rule x will return Empty if succeeds
wrap            | x = a:foo         | wraps a node. `Node("a", x) => Node("foo", Node("a", x))`
unwrap          | x = $a            | unwraps the node. `Node("a", x) => x`
unwrap          | $x = a            | rule x will not result in a node
rename          | x = $a:foo        | unwrap a then wrap with foo, essentially renaming the node
backreference   | x = a:foo $foo    | int index or string label
join            | x = a:"-"         | array.join("-") 
index           | x = a:2           | array[2]
array           | x = a:(2 1)       | return [array[2], array[1]]
function def    | @x = (sin $a)     | return [array[2], array[1]]
function call   | x = @a            | parser triggers onCall(rule:Rule):ParseTree


## Labels

```
a = "A"

w = "A" "A"
x = a a
y = foo:a bar:a
```

Matching "AA" of w results in `[Value("A"), Value("A")]`.
Matching "AA" of x results in `[Node("a", Value("A")), Node("a", Value("A"))]`.
Matching "AA" of y results in `[Node("foo", Node("a", Value("A"))), Node("foo", Node("a", Value("A")))]`.


## Back-references

Current:
```
a = ~/[A-Za-z]/
b = ~/[0-9]/

x = a b 0
```

x matches "cat123cat" but not "cat123dog"

Using numbers require counting and prone to mistakes.
Use $ to mean back-references. $ can be followed by a number or label

```
x = a b $0
x = whatever:a b $whatever
```
    
## Fail expressions

An expression that always fails.
Used to provide helpful error messages.

```
x = fail "some error message here"
```
    
## Import

Includes from another source.
This trigger's the parser's onInclude(source) callback, where the implementation is up to the developer.
On sys targets, this can be a File.getContents.
On non-sys targets like JavaScript, this could retrieve from another source like a StringMap or an AJAX call.

```
# foo.peg
a = "A"
c = "C"
```

```
# bar.peg
b = "B"
c = "C"
```

```
# example1.peg
import foo
import bar          # ERROR c is ambiguous

x = a b             # when the imported rule is not ambiguous
y = foo.c bar.c     # when the imported rule is ambiguous
z = c               
```


```
# example2.peg
import foo
import bar warn     # WARNING c is ambiguous

x = a b             # when the imported rule is not ambiguous
y = foo.c bar.c     # when the imported rule is ambiguous
z = c               # c refers to bar.c
```

## Super

`super` refer's to the rule's existing definition. Can be used to override or extend its definitions.

```
# foo.peg
x = "A"
x = super / "B"     # x = "A" / "B"
```

```
# main.peg
import foo

x = super / "C"     # x = ("A" / "B") / "C"
# or
x = foo.x / "C"     # x = foo.x / "C"
# both matches, but the bottom one may result in Node("foo.x", whatever)
```

## Custom Nodes

This would require a haxe parser. A simple Lisp interpreter might be better? See Functions section below.

```
a = [A-Za-z]+
d = [0-9]+
foo = a num:d $0 {
    var x:Int = Std.parseInt($num);
    return new Whatever($0, x, $2);    
}
```

## Custom Results

This would require a haxe parser. A simple Lisp interpreter might be better? See Functions section below.

```
d = [0-9]+
foo = num1:d num2:d ^{
    var x:Int = Std.parseInt($num1);
    var y:Int = Std.parseInt($num2);
    return x + y    
}
```

Parsing "2 6" results in ["2", "6", 8]

## Functions

Alternative idea to extend functionality by having a Lisp interpreter.
"@" denotes "code"

Maybe version 2 or 3.

```
@foo(r) = (if (match r) "YES" (error "NO"))
        
@bar = (if (> pos 10) a b)

a = "A" / "a"
b = "BB"

x = @foo(a) @bar
```
