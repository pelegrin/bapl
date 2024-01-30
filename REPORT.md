# Final Project Report: Lazarus

## Language Syntax

For language syntax and usage examples please check README.md file in root of repository

## New Features/Changes
Lazarus language has a different syntax from Selene. Lazarus is a strongly typed scripting language.

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

### Type system

### Simple Input/Output

### System library

### Functions
Closures, Assignment, return, parameters


In this section, describe the new features or changes that you have added to the programming language. This should include:

* Detailed explanation of each feature/change
* Examples of how they can be used
* Any trade-offs or limitations you are aware of

## Future

In this section, discuss the future of your language / DSL, such as deployability (if applicable), features, etc.

* What would be needed to get this project ready for production?
* How would you extend this project to do something more? Are there other features you’d like? How would you go about adding them?

## Self assessment

* Self assessment of your project: for each criteria described on the final project specs, choose a score (1, 2, 3) and explain your reason for the score in 1-2 sentences.
* Have you gone beyond the base requirements? How so?

## References

List any references used in the development of your language besides this courses, including any books, papers, or online resources.
