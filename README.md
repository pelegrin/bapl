# Environment

## Prerequisites (to change)
1. Install Lua 5.1 or newer
2. Install LuaRocks
3. Install LPeg
4. (Optional) To run test cases, install luaunit

## Compile and run Lazarus source code file
For example: 
>./lazarus numbers.lz

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
