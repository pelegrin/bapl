local lpeg = require "lpeg"

local lang = {}

local function valueOf(p)
  if not tostring(p):match("lpeg") then return nil end
  return lpeg.C(p)
end

local function node(num)
  return {tag = "number", val = num}
end

local function number(n)
  return node(tonumber(n))
end

local function hex(n)  
  return node(tonumber(n, 16))
end

--[[
**** Frontend
--]]

-- Convert a list {n1, "+", n2, "+", n3, ...} into a tree
-- {...{ op = "+", e1 = {op = "+", e1 = n1, n2 = n2}, e2 = n3}...}
local function foldBin(lst)
  local tree = lst[1]
  for i = 2, #lst, 2 do
    tree = { tag = "binop", e1 = tree, op = lst[i], e2 = lst[i + 1] }
  end  
  return tree
end

local function foldUn(lst)
  return { tag = "unop", op = lst[1], e1 = lst[2]}
end

-- return AST of Lazarus language
  local loc = lpeg.locale()
  local space = loc.space^0
  local sign = lpeg.S("-+")^-1
  local h = lpeg.S("aAbBcCdDeEfF") 
  local x = lpeg.S("xX")
  local floats = loc.digit^1 * "." * loc.digit^1 / number * space
  local scientific = loc.digit^1* ("." * loc.digit^1 + loc.digit^0 )* lpeg.S("eE") * lpeg.P("-")^0 * loc.digit^1 / number * space
  local decimals = loc.digit^1 / number * (-x) * space
  local hexes = "0" * x * lpeg.C((h + loc.digit)^1) / hex * space
  local numerals = hexes + scientific + floats + decimals
  local opA = lpeg.C(lpeg.S("+-")) * space
  local opM = lpeg.C(lpeg.S("*/%")) * space
  local opE = lpeg.C(lpeg.S("^")) * space  
  local opC = lpeg.C(lpeg.P("<=") + ">=" + "==" + "!=" + "<" + ">") * space
  local opUn = lpeg.C(lpeg.P("--") + "++" + "-" + "+")
  local openP = "(" * space
  local closingP = ")" * space

  local unary = lpeg.V("unary")
  local primary = lpeg.V("primary")
  local term = lpeg.V("term")
  local exponent = lpeg.V("exponent")
  local exp = lpeg.V("exp")
  local logic = lpeg.V("logic")
  local grammar = lpeg.P({"logic",
  primary = numerals + openP * logic * closingP,
  unary = space * lpeg.Ct(opUn * primary) /foldUn + primary,    
  exponent = space * lpeg.Ct(unary * (opE * unary)^0) / foldBin,
  term = space * lpeg.Ct(exponent * (opM * exponent)^0) / foldBin,
  exp = space * lpeg.Ct(term * (opA * term)^0) / foldBin, 
  logic = space * lpeg.Ct(exp * (opC * exp)^0) / foldBin
  })
  grammar = space * grammar * -1
local function parse(input)
  return grammar:match(input) or {}
end

--[[
**** Backend
--]]

local function addCode(state, op)
  local code = state.code
  code[#code + 1] = op
end

local ops = {["+"] = "add", ["-"] = "sub",
             ["*"] = "mul", ["/"] = "div", ["^"] = "exp", ["%"] = "rem",
             ["<="] = "lq", [">="] = "gq", ["=="] = "eq", ["!="] = "nq", ["<"] = "lt", [">"] = "gt",
             ["--"] = "dec", ["++"] = "inc", ["-"] = "minus", ["+"] = "plus"
             }
           
local function codeExp(state, ast)
  if ast.tag == "number" then
    addCode(state, "push")
    addCode(state, ast.val)
  elseif ast.tag == "binop" then
    codeExp(state, ast.e1)
    codeExp(state, ast.e2)
    addCode(state, ops[ast.op])
  elseif ast.tag == "unop" then
    codeExp(state, ast.e1)
    addCode(state, ops[ast.op])
  else error("invalid tree")
   end    
end

-- compile AST
local function compile(ast)
  local state = {code = {}}
  codeExp(state, ast)
  return state.code
end

--- export functions

lang.parse = parse
lang.valueOf = valueOf
lang.compile = compile

return lang