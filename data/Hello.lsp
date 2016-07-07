

(var x "Hello") // test comment 
(var y "World") // another comment

(var o/*p
    {
        a : "hello" : "bye"
        b : ["foo" "bar"]
        c : 5.2
    }
    q*/r
)

(var q '(www eee))
(var s `(abc ,x ,@q ghi))

(print s)