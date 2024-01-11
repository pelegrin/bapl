
# Environment

## Prerequisites (to change)
1. Install Lua 5.1 or newer
2. Install LuaRocks
3. Install LPeg
4. (Optional) To run test cases, install luaunit

## Using the tool
To run lazarus with source file or in interactive mode use the following command
` ./lazarus [options] <source_file>` or  `./lazarus -i ` (for interactive mode)
  where options are:
* -i : Interactive mode. Executes source file if provided and switch to interactive mode
* -d | -debug : Enabling printing internal data structures
* -c : Compile mode, compile source file from path and saves it with .lzc extension
* -h : Get this information
* -v : Print interpreter version
Also possible to run a source file and then switch to interactive mode.
To do that provide both path to source file and -i switch. It gives the benefit to have initialized and assigned variables from source file in interactive mode
In interactive mode, special commands are avaliable for debuging, if -d option was not provided.
List of recognise commands are
-    :s - print VM stack
-    :m - print VM memory
-    :vars - print Interpreter internal vars structure

## Running tests
Run test cases from command line
> lua file starts with test_.lua

# Lazarus language
## Types and Values
### Booleans
The boolean types represented by number type. 1 (and any other number) represents `true` and 0 represents `false`
### Numbers
The number type represents real (double-precision floating-point) numbers.
We can write numeric constants with an optional decimal part, plus an optional decimal exponent. Examples of valid numeric constants are:
` 4     0.4     4.57e-3     0.3e12     5e+20`
Language supports numbers in hexadecimal that starts with `0X` or `0x`. Examples are: 
`0xFF 0X1AB 0x99`

## Expressions
### Arithmetic Operators
Language supports the usual set of arithmetic operations:
*addition, subtraction, multiplication, division*. It also supports *modulo* and *exponentiation*.
Using brackets alter precedence of calculations, for example:
*(1 + 2) * 3* results in 9 
### Unary operators
Supported *decrement, increment, unary minus.* (--, ++, -) in infix notation. 
### Logical operators
Lazarus provides the following relational operators.
`< > <= >= == !=`
### / Ternary operator
Language provides ternary operator for conditional expression calculation.
`<condition>? true expression : false expression`
true expression only evaluates when result of condition expression is true

## Identifiers

An identifier is a sequence of letters and digits. The first character must be a letter, the underscore _ counts as a letter. Upper and lower case letters are different. Identifiers may have any length.

## Comments
Line starting with  /* introduces a block comment, which terminates with the characters */ started with new line. 
Characters  // introduce a comment terminated with end of line.

## Control structures
TODO:
if [elseif] [else] end
while <condition> done

## System functions
Print an expression
> @ [expression]

## Reserved words
> "return", "while", "for", "done","if", "else", "elseif", "end", "and", "or"

## Type system
declaration
initialisation
type checking for binary and unary operations

numbers, bool, array, array of array ....
 