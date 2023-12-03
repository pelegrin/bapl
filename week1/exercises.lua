-- Excersices from Programming in Lua book
-- 4.1
local a = [=[
 <![CDATA[
       Hello world
]]>
]=]

local b =  "<![CDATA[\n\z
       \t\t\tHello world\n\z
]]>"


print(a)
print(b)

-- 4.3

function insert(s, n, s1)
  return string.sub(s, 1, n)..s1..string.sub(s, n, -1)
end

--print(insert("hello world", 6, "super"))
assert(insert("hello world", 6, "super") == "hello super world")

-- 4.4
function utf8insert(s, n, s1)
  return string.sub(s, 1, utf8.offset(s, n))..s1..string.sub(s, utf8.offset(s,n), -1)
end

--print(utf8insert("привет мир", 7, "супер"))
assert(utf8insert("привет мир", 7, "супер") == "привет супер мир")

-- 4.5
function remove(s, n, l)
  return string.sub(s, 1, n - 1)..string.sub(s, n +  l, -1)
end

--print(remove("hello world", 7, 4))
assert(remove("hello world", 7, 4) == "hello d")


-- 4.7
function ispali(s)
  return s == string.reverse(s)
end

assert(ispali("step on no pets"))
assert(not ispali("banana"))

-- 5.4 an x^n + an-1 x^n-1 ... +a1x + a0

function polynom(a, x)
  r = 0
  for i = #a, 1, -1 do
    r = r + a[i] * x^(i - 1)
  end
  return r
end

--print(polynom({2,3,4}, 2)) 
assert (polynom({2,3,4}, 2) == 2 + 3 * 2 + 4 * 2^2 )


-- 5.8

function concat(l)
  s = ""
  for i = 1, #l do
    s = s..l[i]
  end
  return s
end


assert(concat({"hello", " ", "world"}) == "hello world")

a = {}
for i = 1, 10000 do
  a[i] = "hello "
end

t1 = os.clock()
table.concat(a)
t2 = os.clock()
print("library concat function executed in ".. (t2 - t1))

t1 = os.clock()
concat(a)
t2 = os.clock()
print("my concat function executed in ".. (t2 - t1))

-- Week 1 exercises
-- lpeg test

local lpeg = require "lpeg"
local p = lpeg.P("hello")

assert(lpeg.match(p, "hello world") == 6)
assert(lpeg.match(p, "some text") == nil)

-- 11 Matching summation

local d = lpeg.S(" 0123456789")^1 -- one or more digits and spaces
local s = lpeg.S(" +") -- + and spaces
p = d * s * d

assert(lpeg.match(p, "1+3") == 4, "summation without spaces")
assert(lpeg.match(p, "21+3") == 5, "summation without spaces")
assert(lpeg.match(p, "21+35") == 6, "summation without spaces")
assert(lpeg.match(p, "1 + 3") == 6, "summation with spaces before and after +")
assert(lpeg.match(p, "1  +3") == 6, "summation with spaces before +")
assert(lpeg.match(p, "1  +  3") == 8, "summation with more then one space before and after +")
assert(lpeg.match(p, "1-3") == nil, "- doesn't match")
assert(lpeg.match(p, "a+3") == nil, "only digits match in summation")
assert(lpeg.match(p, "1+a") == nil, "only digits match")
assert(lpeg.match(p, "1234") == nil, "digits without + result no match")

-- 13 Position capture

p = lpeg.C(d) * lpeg.Cp(s) * s * lpeg.C(d) * lpeg.Cp(s) * s * lpeg.C(d)

--print(lpeg.match(p, "12+13+25"))
local a1, a2, a3, a4, a5 = lpeg.match(p, "12+13+25")
-- assert correct result  12 3 13 6 25"
assert(a1 == "12", "return numerals and capture positions of plus")
assert(a2 == 3, "return numerals and capture positions of plus")
assert(a3 == "13", "return numerals and capture positions of plus")
assert(a4 == 6, "return numerals and capture positions of plus")
assert(a5 == "25", "return numerals and capture positions of plus")

-- 15 Matching the whole subject
p = p * -1

-- previous assert should work
local a1, a2, a3, a4, a5 = lpeg.match(p, "12+13+25")
-- assert correct result  12 3 13 6 25"
assert(a1 == "12", "return numerals and capture positions of plus")
assert(a2 == 3, "return numerals and capture positions of plus")
assert(a3 == "13", "return numerals and capture positions of plus")
assert(a4 == 6, "return numerals and capture positions of plus")
assert(a5 == "25", "return numerals and capture positions of plus")

assert(lpeg.match(p, "12+13+25-") == nil, "match the whole subject")  

-- 17 Adding an optional sign to numbers

local space = lpeg.S(" \n\t")^0 -- optional space
local numbers = lpeg.C(lpeg.S("+-")^0 * lpeg.R("09")^1)/tonumber * space -- signed number with any spaces after

assert(lpeg.match(numbers, "-12") == -12, "negative number")
assert(lpeg.match(numbers, "12") == 12, "positive number")
assert(lpeg.match(numbers, "-12   ") == -12, "negative number with spaces")

-- 18 Arithmetic expressions + 20 Adding more operators + 21 Parenthesized
local opA = lpeg.C(lpeg.S("+-")) * space
local opM = lpeg.C(lpeg.S("*/%")) * space
local opE = lpeg.C(lpeg.S("^")) * space
local openP = "(" * space
local closingP = ")" * space

function unfold(lst)
local r = lst[1]
  for i = 2, #lst, 2 do
      if lst[i] == "+" then
        r = r + lst[i + 1]
       elseif lst[i] == "-" then
         r = r - lst[i + 1]
       elseif lst[i] == "*" then
         r = r * lst[i + 1]
       elseif lst[i] == "/" then
         r = r / lst[i + 1]
       elseif lst[i] == "%" then
         r = r % lst[i + 1] 
       elseif lst[i] == "^" then
         r = r ^ lst[i + 1]
       else
         error("unknown operator")
       end  
  end
  return r
end  

local primary = lpeg.V("primary")
local term = lpeg.V("term")
local exponent = lpeg.V("exponent")
local exp = lpeg.V("exp")
local grammar = lpeg.P({"exp",  
  primary = numbers + openP * exp * closingP,
  exponent = space * lpeg.Ct(primary * (opE * primary)^0) / unfold,
  term = space * lpeg.Ct(exponent * (opM * exponent)^0) / unfold,
  exp = space * lpeg.Ct(term * (opA * term)^0) / unfold, 
})

-- tests
-- print(lpeg.match(sum, "-12"))
assert(lpeg.match(grammar, "-12") == -12)
assert(lpeg.match(grammar, "-12 * 2") == -24)
assert(lpeg.match(grammar, "-12 * 2 + 24 -1 ") == -1)
assert(lpeg.match(grammar, "-12 / 2 + 6  ") == 0)
assert(lpeg.match(grammar, "-12 / 2 + 6 *2  ") == 6)
assert(lpeg.match(grammar, "12 % 2") == 0)
assert(lpeg.match(grammar, "12 % 5") == 2)
assert(lpeg.match(grammar, "1 + 2 ^ 2 - 6 ") == -1)

-- test with parenthesis

assert(lpeg.match(grammar, "(3 + 2)^2") == 25)
assert(lpeg.match(grammar, "(3 + 2)^2 + 3%2 - 3 - 23") == 0)

  