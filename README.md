
# Lazarus language

Lazarus is a small but powerful strongly typed scripting language inspired by lua. The main design decision is to provide interpretation of the source file, so-called LAZ files, as well as interactive environment for executing Lazarus line by line.

## How to get the tool
Official Docker image is provided on Docker Hub.
To play with Lazarus interpreter, you can use command:
`docker run -it --name lazarus pelegrin/lazarus:1.0`

If you want an source editor, vim is provided in Docker image, use the follwing command

You jump right into the action
```
Lazarus interpreter v.0.9 ©2024 GoodCode
System library v.0.8
  Lazarus interactive commands
    :? - print this help
    :s - print VM stack
    :m - print VM memory
    :vars - print Interpreter internal vars structure
    :buff - show Interpreter buffer
    :params - show Interpreter param structure
    :list - show LAZ files in current directory
    :run <file> - run LAZ file from current directory
    :exit - exit
  lazarus line:1 >
  ```

Image supplied with example LAZ files, which can be run with :run filename command.
Or can start coding in LAZ right in command line.

Image is based on Alpine Linux and optimized.

For using image with editor please use the following command
`docker run -it --entrypoint /bin/bash pelegrin/lazarus:1.0`
Command `lazarus` is avaliable in path for running source files.


## Using the tool
To run lazarus with source file or in interactive mode place the following command
`lazarus [options] <source_file>` or  `lazarus -i ` (for interactive mode)
  where options are:
* -i : Interactive mode or Executes source file if path is provided and switch to interactive mode
* -d | -debug : Enabling printing internal data structures
* -c : Compile mode, compile source file from path and saves it with .lzc extension. Experimental. Using for compile system library
* -h : Get this information
* -v : Print interpreter version

Also possible to run a source file and then switch to interactive mode.
To do that provide both path to source file and -i switch. It gives the benefit of having initialized and assigned variables from source file in interactive mode

## Developing the tool
Clone repository and submit PR request with description of changes.
Folder structure.
Dockerfile - official Docker image
examples - LAZ source files with varios language examples. Also provided in Docker image.
package - latest version intepreter using in Docker image
scripts - Test and additional bash scripts.
systemlib - current version of system lib with sources in Lazarus language.
week1-week8 - Lazarus interpreter in different readiness stages (developed in BAPL course)


### Running tests
Two scripts are provided in scripts folder. run_sources.sh execute all source files with interpreter and run_tests.sh runs all lua tests file.

# Lazarus language
Lazarus is a strongly typed language. Any variable should be declared first, before usage.
For example, `number a, a = 1` uses sequence statements for declaration and initialisation of variable `a`.
Syntactic sugar statement `number a = 1` also can be used. Language recognize it as declaration and assignment. In fact this statement translated internally to the same `number a, a = 1` sequence staments.

## Types and Values
### Booleans
The boolean types represented by number type. 1 (and any other number) represents `true` and 0 represents `false`
### Numbers
The number type represents real (double-precision floating-point) numbers.
We can write numeric constants with an optional decimal part, plus an optional decimal exponent. Examples of valid numeric constants are:
` 4     0.4     4.57e-3     0.3e12     5e+20`

Language supports numbers in hexadecimal that starts with `0X` or `0x`. 
Examples are: 
`0xFF 0X1AB 0x99`

### Functions
Functions in Lazarus are a first class citizens. They can be used as return value from other functions or as parameters to function calls. Functions also can be used in assignments.
Variable type should be a function in this case, like here
```
number func factorial(number n)
  if n == 0
    return 1
  else
    return n * factorial(n - 1)
  end
end
func f = factorial
@f(6) // print 720
```
Closures are also supported, like in this example
```
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
```

### Strings
Strings are fully supported in Lazarus. Strings represent text.
Mathematical `+` in case of strings do the concatenational of strings.
Example:
```
string s = 'The Lazarus language' + ' is cool'
```
For strings also supported length operator `#` and getting literal via indexing, like in this example,
`s[1] == 'T'` (puts true on a stack)

### Array
An array in Lazarus is a fixed-size collection of similar data items. In other words, elements in array can only be of one type.
Array always support length operator `#` and returns a size of array provided by declaration.
Example of declacation and using of array.
```
number i = 5, [number] x[i]
while i > 0
   x[i] = i + 5, i = i - 1
done
@x
```

## Expressions
### Arithmetic Operators
Language supports the usual set of arithmetic operations:
*addition, subtraction, multiplication, division*. It also supports *modulo* and *exponentiation*.
Using brackets alter precedence of calculations, for example:
*(1 + 2) * 3* results in 9 

### Logical operators
Equality operator `==` balanced by not equal operator `!=`
Different comparasion operators are supported like
`<= >= < >`
### Unary operators
Supported *decrement, increment, unary minus.* (--, ++, -) in infix notation. 
Size operator `#` can be used for some data types, namely arrays and strings. In both cases, it returns size of array or string (number of literals) accordinly. 

### Relational Operators
Lazarus provides the following relational operators.
`< > <= >= == !=`

### Logical Operators
Logical `&&` (AND)  and `||` (OR) operators are also provided. Short-cut calculations are used for it. For example, 
```
number x = 0
x != 0 && 1/x
```
works without any problem, as 1/x even not calcucaled.

Logical ! `NOT` operator is avaliable for boolean type.

### Ternary operator
Language provides ternary operator for conditional calculation.
`<condition>? true statement : false statement`
true statement only evaluates when result of condition expression is true
Example,
```
number x = 1
x > 0 ? @'YES' : @'NO' //prints YES
```

## Identifiers

An identifier is a sequence of letters and digits. The first character must be a letter, the underscore _ counts as a letter. Upper and lower case letters are different. Identifiers may have any length.
## Declaration of variables
Before use of variable, it should be declared.
Decralation syntax is
`type id`, where type is one of the supported types (boolean, string, number, func, array) and id described in Identifiers section.
Variable also can be declared and initialised like in this example.
`number x = 3`


## Comments
Line starting with  /* introduces a block comment, which terminates with the characters */ started with new line. 
Characters  // introduce a comment terminated with end of line.

## Control structures
### If statement
The if in Lazarus is a decision-making statement that is used to execute code based on the value of the given expression.
Syntax of if statement
```
if condition 1
  statements
elseif condition 2
  statements
else
  statements
end
```
condition can have function call in it.
Consider the following example (prints YES)
```
func f = factorial
if f(6) == 720
  @'YES'
else
  @'NO'
end
```
### While statement
At the moment language only supports `while` control structure for cycles.
Syntax of while statement 
```
while condition
  statements
done
```
Statements are repreated while condition is true.

## Functions 
Functions are the main mechanism for abstraction of statements in Lazarus.
Functions can compute and return values. Function can be used in any expression of Lazarus language.

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
Now we can use function before full declaration.
As you can see, forward declaration of function has missed parameters and it's type. Due to this, parameters in preliminary function calls are not checked by compiler. We are aware of this limitation.

## System library
Language provides a library of frequently used functions, knowns as a system library. Those are avaliable for usage in your programms.
Functions are written in Lazarus and compiled for usage.
At the moment, we provide a `substring` function.
Syntax is 
```
substring(s, number)
```
function returns substring of passed string s, with `number` of literals. if number is positive substring cutted for the beginig of s, in case of negative number, function returns substring starting from the end of a string. 

## Simple Input/Output
Language provides operator for output `@` and `->` for input.
Full example.
```
number x
->$x
@x
```
We declare variable first, then waiting for user input and assigned it to variable.
Then we print value of variable in console.


## Reserved words
Language has the following reserved words:
```
"return", "while", "for", "done", "elseif", "if", "else" , "end", "and", "or", "true", "false", "number", "bool", "string", "func"
```
