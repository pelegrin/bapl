local lpeg = require "lpeg"
local ut = require "utils"

local lang = {}

local function valueOf(p)
  if not tostring(p):match("lpeg") then return nil end
  return lpeg.C(p)
end

local function nodeAssign(id, exp)
  return {tag = "assign", id = id.val, exp = exp}
end


local function nodeVar(v)
  return {tag = "var", val = v}
end

local function nodeRef(r)
  return {tag = "ref", val = r}
end

local function nodeSys(exp)
  return {tag = "sys", code = "1", exp = exp}
end

local function nodeNum(num)
  return {tag = "number", val = num}
end

local function number(n)
  return nodeNum(tonumber(n))
end

local function hex(n)  
  return nodeNum(tonumber(n, 16))
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

-- Convert a list {st1, ",", st2, "," st3, ...} into a tree
local function foldSts(lst)
  local tree = lst[1]
  for i = 2, #lst do
    tree = { tag = "seq", s1 = tree, s2 = lst[i] }
  end  
  return tree
end

local function foldUn(lst)
  local op = lst[1]
  local val = lst[2]
  if op == "+" then return val end -- folding of unary plus
  return { tag = "unop", op = op, e1 = val}
end

-- return AST of Lazarus language
  local loc = lpeg.locale()
  local space = loc.space^0
  local sign = lpeg.S("-+")^-1
  local h = lpeg.S("aAbBcCdDeEfF") 
  local x = lpeg.S("xX")
  local sym = lpeg.R("az", "AZ")
  local sep = lpeg.S(",")
  local underscore = lpeg.S("_")
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
  local opAssign = lpeg.S("=") * space
  local openP = "(" * space
  local closingP = ")" * space
  local variable = (sym^1 + underscore * underscore^-1 * sym^1) * loc.alnum^0 / nodeVar * space
  local ref = lpeg.S("$") * (sym^1 * loc.alnum^0 / nodeRef) * space
  local id = variable + ref
  local pr = space * lpeg.P("@")
  local unary = lpeg.V("unary")
  local primary = lpeg.V("primary")
  local term = lpeg.V("term")
  local exponent = lpeg.V("exponent")
  local exp = lpeg.V("exp")
  local logic = lpeg.V("logic")
  local statement = lpeg.V("statement")
  local statements = lpeg.V("statements")
  local grammar = lpeg.P({"statements",
  statements = space * lpeg.Ct(statement * (sep * (statement + ""))^0)/ foldSts,    
  statement = space * id * opAssign * logic /nodeAssign + pr*logic/nodeSys + logic,    
  primary = numerals + openP * logic * closingP + id,
  unary = space * lpeg.Ct(opUn * primary) /foldUn + primary,    
  exponent = space * lpeg.Ct(unary * (opE * unary)^0) / foldBin,
  term = space * lpeg.Ct(exponent * (opM * exponent)^0) / foldBin,
  exp = space * lpeg.Ct(term * (opA * term)^0) / foldBin, 
  logic = space * lpeg.Ct(exp * (opC * exp)^0) / foldBin
  })
  grammar = space * grammar * -1
local function parse(input)
  return grammar:match(input) or nil
end

--[[
**** Backend
--]]

local function toVar(frame, id)
  local num = frame.vars[id]
  if not num then
    num = #frame.vars + 1
    frame.vars[id] = num
  end  
  return num
end

local function fromVar(frame, id)
  local num = frame.vars[id]
  if not num then error("Undefined variable " ..tostring(id)) end
  return num
end

local function addCode(state, op)
  local code = state.code
  code[#code + 1] = op
end

local ops = {["+"] = "add", ["-"] = "sub",
             ["*"] = "mul", ["/"] = "div", ["^"] = "exp", ["%"] = "rem",
             ["<="] = "lq", [">="] = "gq", ["=="] = "eq", ["!="] = "nq", ["<"] = "lt", [">"] = "gt",
             ["--"] = "dec", ["++"] = "inc", ["-"] = "minus"
             }
           
local function codeExp(frame, state, ast)
  if ast.tag == "number" then
    addCode(state, "push")
    addCode(state, ast.val)
  elseif ast.tag == "var" then
    addCode(state, "load")
    addCode(state, fromVar(frame, ast.val))
  elseif ast.tag == "ref" then
    addCode(state, "loadg")
    addCode(state, fromVar(frame,ast.val))
  elseif ast.tag == "binop" then
    codeExp(frame, state, ast.e1)
    codeExp(frame, state, ast.e2)
    addCode(state, ops[ast.op])
  elseif ast.tag == "unop" then
    codeExp(frame, state, ast.e1)
    addCode(state, ops[ast.op])
  else error("invalid tree")
   end    
end

local function codeStatement(frame, state, ast)
  if ast.tag == "assign" then
    codeExp(frame, state, ast.exp)
    addCode(state, "store")
    addCode(state, toVar(frame, ast.id))    
  elseif ast.tag == "seq" then
    if ast.s2 == nil then return codeStatement(state, ast.s1) end
    codeStatement(frame, state, ast.s1)
    codeStatement(frame, state, ast.s2)
  elseif ast.tag == "sys" then
    codeExp(frame, state, ast.exp)
    addCode(state, "syscall")
    addCode(state, ast.code)
  else codeExp(frame, state, ast)
  end    
end


-- compile AST
local function compile(frame, ast)
  local state = {code = {}}
  codeStatement(frame, state, ast)
  return state.code
end

--- export functions

lang.parse = parse
lang.valueOf = valueOf
lang.compile = compile

return lang