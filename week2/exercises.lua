-- manually execute stack-machine programm
--[[
push 4
push 2
push 24
push 21
sub
mult
add

-- push 4
4
-- push 2
2
4
-- push 24
24
2
4
-- push 21
21
24
2
4
-- sub
-3
2
4
-- mult
-6
4
-- add
-2

(21 - 24) * 2 + 4
--]]

-- Repetition problem

local lpeg = require "lpeg"

local p1 = #lpeg.P("A")^3 * lpeg.P("A")^-3 * -lpeg.P("A")
local p2 = lpeg.P("A") * lpeg.P("A") * lpeg.P("A") * -lpeg.P("A")         
-- infinite loop
local p = lpeg.P"."^-1
--local p3 = #p^0 * p^0 * -p
local p4 = p * -p
print(p1:match("AAA"))
print(p2:match("AAA"))
--print(p3:match(".")) error
print(p4:match(".."))


--[[
subject: "hello!hello!hello"
pattern: .*!
lazy match: "hello!"
greedy match: "hello!hello!"
--]]
local subject = "hello!hello!hello"
local lmatch = "hello!"
local gmatch = "hello!hello!"
local s1 = lpeg.C(lpeg.R("az")^1 * "!")
local s2 = lpeg.C((lpeg.R("az")^1 * "!")^2)
print(s1:match(subject))
print(s2:match(subject))
assert(s1:match(subject) == lmatch)
assert(s2:match(subject) == gmatch)

--multiple comparasion
-- 1 < 2 < 3 < 2 .. --> (1 < 2) and (2 < 3) and (3 < 2) --> true and true and false --> false
-- 2 < 1 < 3 < 4 ..