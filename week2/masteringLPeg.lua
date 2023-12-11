local lpeg = require "lpeg"

function printtable(t)
  if type(t) ~= "table" then print "" end
  local out = "{" .. "\n"
  for k,v in pairs(t) do
    out = out .. "\t".. k .. ": " .. tostring(v) .. "\n"
  end
  print (out .. "}" .. "\n")
end

printtable({a="hello", "exp", "some number"})




printtable(lpeg.locale())


function valueOf(p)
  if not tostring(p):match("lpeg") then return nil end
  return lpeg.C(p)
end


local loc = lpeg.locale()

--print (valueOf(loc.digit):match("5"))


local num  = lpeg.P "-" ^-1 * lpeg.R "09"^1

--print (valueOf(num):match("-56")) 

local opt = lpeg.P"."^-1

-- search a symbol

local searchA = (1 - lpeg.P("A") )^1 * lpeg.Cp() * "A"

 assert(searchA:match("hellAou After") == 5)
--print(searchA:match("hellAou After"))

-- identifiers matching
local reserved = (lpeg.P("if") + "then" + "while" + "end" ) * -loc.alnum
local id = (loc.alpha * loc.alnum^0) - reserved
--print(id:match("1iffy"))
--print (id:match("iffy"))
assert(id:match("iffy") == 5)
assert(id:match("if") == nil)
assert(id:match("1iffy") == nil)
assert(id:match("iffy1") == 6)
assert(id:match("i") == 2)
--print(id:match("i"))


