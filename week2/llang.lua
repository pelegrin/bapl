local lpeg = require "lpeg"

local lang = {}

local function valueOf(p)
  if not tostring(p):match("lpeg") then return nil end
  return lpeg.C(p)
end

local function node(num)
  return {tag = "number", val = num}
end

local function decimal(n)
  return node(tonumber(n))
end

local function hex(n)  
  return node(tonumber(string.gsub(string.gsub(n, "0X", ""), "0x", ""), 16))
end

--[[
**** Frontend
--]]


-- return AST of Lazarus language
local function parse(input)
  local loc = lpeg.locale()
  local h = lpeg.S("aAbBcCdDeEfF") 
  local x = lpeg.S("xX")
  local decimals = lpeg.S("-+")^0 * loc.digit^1 / decimal * loc.space^0
  local hexes = lpeg.S("-+")^0 * "0" * x * (h + loc.digit)^1 / hex * loc.space^0
  local numerals = hexes + decimals


  return numerals:match(input) or {}
end

--[[
**** Backend
--]]

-- compile AST
local function compile(ast)
  if ast.tag == "number" then
    return {"push", ast.val}
   end 
end

--- export functions

lang.parse = parse
lang.valueOf = valueOf
lang.compile = compile

return lang