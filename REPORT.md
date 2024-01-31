# Final Project Report: Lazarus

## Language Syntax

For language syntax and usage examples please check README.md file in root of repository.
Language syntax is quite different from Selene provided on the course.


## New Features/Changes
Lazarus is a strongly typed scripting language. One of the design goal was to provide environment for statement execution (more like in Lua) in interactive mode. Lazarus uses different memory layout for VM and different mechanism for function execution. Example of memory can be seen in interactive mode (`-i` option) with :m command. Each function executes in separate environment with prepared memory with global variables/variables in scope and parameters. Parameters are not placed in stack, but in a special memory location.
Closures for functions are also implemented using memory back copy technique.
VM supports input output stream redirection (it borrows implementation from Lua)
With help of it was able to implement integration tests,
test snippet here 
```
  local cmd1 = [[
  echo "@sub('Hello', 3)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd1), "Hel", "first 3 symbols from string")
```
Helps to test system functions written in Lazarus via Lua 

Description of new features in language.

### Ternary operator
Lazarus provides a ternary operator as a compact version of if-else control structure.
Syntax is 
`expression ? true_statement : false_statement`.

Nested ternary operation is not supported.
Simple example
```
number x = 1
x > 0 ? @'YES' : @'NO'
```
Prints YES in console.

### Boolean type
In Lazarus, the boolean data type is a built-in data type. Boolean can store values as `true` or `false`.
Variable of boolean type should be declared before use. 
For example,
```
bool x = true
```
Logical `&&` (AND)  and `||` (OR) operators are also provided. Short-cut calculations are used for it. For example, 
```
number x = 0
x != 0 && 1/x
```
works without any problem, as 1/x is even not calcucaled.
Logical ! `NOT` operator exists for boolean type.

### String type
Strings are fully supported in Lazarus. Strings represent text.
Mathematical `+` in case of strings do the concatenational of strings.
Example:
```
string s = 'The Lazarus language' + ' is cool'
```
For strings also supported length operator `#` and getting literal via indexing, like in this example,
`s[1] == 'T'` (puts true on a stack)

System functions avaliable in any Lazarus source file. At the moment, we provide
substring function with the following synatax
`substring(s, number)` where s should be string or variable of string type,

function returns substring of passed string s, with `number` of literals. if number is positive substring cutted for the beginig of s, in case of negative number, function returns substring starting from the end of a string. 


### Type system
Lazarus is strongly typed language. The following types are supported
number, bool, func, string and array of those type, like [number]
Operators application dependent from type of operand, for example `+` in case of string concatenates it, for number returns sum of two numbers, and doesn't make sense for arrays.
Example of array declaration 
```
number x[5]
```
declares an array of numbers with 5 elements. Indexing in arrays starts with 1 like in Lua.

Known limitations.
When using forward function declaration, paramaters types and numbers are not known during the function call,
For example,
```
number func odd
```
is a forward function declaration. 

typechecker also not applied to function parameters, it's a known limitation and will be improved in the future.
Honest to say, that implementation of type system comes from curiosity, and as we weren't provided info on course. Used third party books, but implementation is far from perfect.

### Simple Input/Output
Lazarus provides operators for input/output. General syntax is 
`iooperator statement`
For input, assumed, that data should be assign to varible, the following example describe a syntax
```
number x
->$x
```
we declare a number variable here and assign it to content provided by user (number)

### System library
Lazarus introduced concept of system library (borrowed from multiple languages). Main idea is to update system library separated from language specific tools.
VM and language front end/backend doesn't depend on system library. Only assumption is that system functions avaliable in special memory region added to VM.
During compilation new system variable/functions are always avaliable in any scope. Rewrite system functions are not possible at the moment by application programmer.
Functions were compiled using Lazarus compiler with special experimental option. Far from perfect, so, option was not provided to programmers
Example of usage system functions

```
substring(s, number)
```
function returns substring of passed string s, with `number` of literals. if number is positive substring cutted for the beginig of s, in case of negative number, function returns substring starting from the end of a string. 


### Functions
Changes to function implementations.
Before used, function should be declared.
Syntax is the following.
```
<type> func id(parameters)
function body
return statement
end
```
Function should contains return statement and type of return statemnt should be same type like in function declacation.
Void type is not supported yet.

Function might be referenced before declaration for function calls in other functions.
Here is the declaration of function `odd`
```
number func odd
```
Closures are implemented, here is a working example.

func func outer()
  number a, a = 1
  number func inner()
    number b, b = 3 // this should not be visible in VM memory after execution
    @a
    return a
  end
  return inner
end

func f, f = outer()
number a, a = 2
f()
@a //print 1 from closure and 2 from main scope

Known limitation for declaration function inside of other functions, is that only one level of nesting is supported (in anticipation of anonymous functions, which were not implemented)

Encorage syntax is to define functions first then use them as parameters or return values, which arguable makes program a little simpler to understand.

## Future
The whole purpose of project is to learn main concepts of compiler/interpeter techinque and have a further reading for more teoretical approach.
Course provides excellent opportunity to build from the ground up a working language with necessary tools.

Though a project might find a usage when requirements are exist for developing DSL.
Main obstacle for usage language in production is closure implementations, which with time consume more and more memory.

So, two development vectors
- Switch VM (implementation structure allows it) implementation to C/C++.
- Basic GC implementation for variables in closures.

I've got a big pleasure to participate in course and `absorb` materials
## Self assessment
| Language criteria             | Score      | Comment
|-------------------------------|------------|------------
| Language Completeness         |   3        | More then one challenge coded into the language                                                           |
| Code Quality & Report         |   3        | Separated language tools from VM implementation. System library                                           |
| Originality & Scope           |   3        | Quite original implementation deviates for Selene. Creative and originality is in questien. Would put 2.5 |
| Self assesment                |   2        |                                                                                                           |

## References
1. Programming in Lua fourth edition. Roberto Ierusalimschy. Rio de Janeiro, 2016
2. Mastering LPeg by Roberto Ierusalimschy. Provided article.
3. Compilers: Principles, Techniques, and Tools 2nd Edition. by Alfred Aho, Jeffrey Ullman, Ravi Sethi, Monica Lam
4. The Garbage Collection Handbook. 2023.  by Richard Jones, Antony Hosking, Eliot Moss
5. Crafting Interpreters. 2021. by Robert Nystrom
6. Functional programming and type systems. 2023. Didier Rémy. http://gallium.inria.fr/~remy/mpri/
7. Type Systems. Luca Cardelli. http://lucacardelli.name/Papers/TypeSystems.pdf