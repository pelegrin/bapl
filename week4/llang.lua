local lpeg = require "lpeg"
local ut = require "utils"

local lang = {}

--[[
-- LPeg Debug function
local function I (msg)
  return lpeg.P(function () print(msg); return true end)
end
--]]

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
  
local space = lpeg.V("space")

local function T(t)
  return t * space
end

local maxmatch = 0
local bCommentStarted = false
local bCommentEnded = false

local loc = lpeg.locale()

local sign = lpeg.S("-+")^-1
local h = lpeg.S("aAbBcCdDeEfF") 
local x = lpeg.S("xX")
local sym = lpeg.R("az", "AZ")

-- numericals
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
local variable = (sym^1 + T"_" * T"_"^-1 * sym^1) * loc.alnum^0 / nodeVar * space
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

local comments = "//" * (lpeg.P(1) - "\n")^0
local bcommentS = "/*" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentStarted = true; return true end)
local bcommentE = "*/" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentEnded = true; return true end)

local grammar = lpeg.P({"prog",
  prog = space * bcommentS^-1 * bcommentE^-1 * statements * -1,    
  statements = space * lpeg.Ct(statement * (T"," * (statement + ""))^0)/ foldSts,    
  statement = space * id * T"=" * logic /nodeAssign + pr * logic/nodeSys + logic,    
  primary = numerals + T"(" * logic * T")" + id,
  unary = space * lpeg.Ct(opUn * primary) /foldUn + primary,    
  exponent = space * lpeg.Ct(unary * (opE * unary)^0) / foldBin,
  term = space * lpeg.Ct(exponent * (opM * exponent)^0) / foldBin,
  exp = space * lpeg.Ct(term * (opA * term)^0) / foldBin, 
  logic = space * lpeg.Ct(exp * (opC * exp)^0) / foldBin,
  space = (loc.space + comments)^0 * lpeg.P(function (_, p)  maxmatch = p ;return true end)            
})

local ops = {["+"] = "add", ["-"] = "sub",
             ["*"] = "mul", ["/"] = "div", ["^"] = "exp", ["%"] = "rem",
             ["<="] = "lq", [">="] = "gq", ["=="] = "eq", ["!="] = "nq", ["<"] = "lt", [">"] = "gt",
             ["--"] = "dec", ["++"] = "inc", ["-"] = "minus"
             }
           

local function Interpreter(v)
  local vars = v or {}
  local nvars = v and #v or 0
  local list = ut.List()
  
  local function parse(input)
    if input == nil or input == "" then return nil, nil end
    local ast = grammar:match(input)
    if bCommentEnded then bCommentEnded = false; bCommentStarted = false; return nil, nil end
    if bCommentStarted then return nil, nil end
    if ast == nil then return nil, {line = input, position = maxmatch - 1} end
    return  ast, nil
  end
    
  local function addCode(op)
    list.add(op)
  end

  local function getVar(id)
    local num = vars[id]
    if not num then error("Undefined variable " ..tostring(id)) end
    return num
  end
  
  local function store(id)
    local num = vars[id]
    if not num then
      num = nvars + 1
      vars[id] = num
      nvars = num
    end  
    return num
  end

  
  local function codeExp(ast)
    if ast.tag == "number" then
      addCode("push")
      addCode(ast.val)
    elseif ast.tag == "var" then
      addCode("load")
      addCode(getVar(ast.val))
    elseif ast.tag == "ref" then
      addCode("loadg")
      addCode(getVar(ast.val))
    elseif ast.tag == "binop" then
      codeExp(ast.e1)
      codeExp(ast.e2)
      addCode(ops[ast.op])
    elseif ast.tag == "unop" then
      codeExp(ast.e1)
      addCode(ops[ast.op])
    else error("invalid tree")
    end    
  end

  
  local function codeStatement(ast)
    if ast.tag == "assign" then
      codeExp(ast.exp)
      addCode("store")
      addCode(store(ast.id))    
    elseif ast.tag == "seq" then
      if ast.s2 == nil then return codeStatement(ast.s1) end
      codeStatement(ast.s1)
      codeStatement(ast.s2)
    elseif ast.tag == "sys" then
      codeExp(ast.exp)
      addCode("syscall")
      addCode(ast.code)
    else codeExp(ast)
    end    
  end

  local function syntaxErrorHandler(err) 
    local errMsg = ""
    if err.position == 0 then 
      errMsg = err.line .. " (beginig of line)"
    else
      errMsg = string.sub(err.line, 1, err.position -1) .. "["  .. string.sub(err.line, err.position, err.position + 1)  .. "]" .. " (at position: " .. err.position .. ")"
    end
    print("LZ1 Syntax error in line: " .. errMsg)
  end

  local function compile(line)
    list = ut.List()
    local status, ast, err = pcall(parse, line)
    if (err ~= nil) then syntaxErrorHandler(err); return {}, err end
    if ast ~= nil then
          status, err = pcall(codeStatement, ast)
          if not status then ut.errorHandler("Compilation error in line: ".. line .. "\n" ..err); return {}, err end
    end
    return list.getAll()
  end
    
  return {
    compile = compile,
    _parse = parse -- expose for tests only
  }
end

local function VM()
  -- Lazarus reserved words
  local syscalls = { ["1"] = function (exp) print(tostring(exp)) end }
  -- internal data structures
  local stack = ut.Stack()
  local mem = {}
  
  local function tOf(b)
    return b and 1 or 0
  end

  
  local function run(code)
    local pc = 1
    while pc <= #code do
      if code[pc] == "push" then
        pc = pc + 1
        stack.push(code[pc])
      elseif code[pc] == "load" then
         pc = pc + 1
         stack.push(mem[code[pc]])
      elseif code[pc] == "store" then
         pc = pc + 1
         mem[code[pc]] = stack.pop()
      elseif code[pc] == "syscall" then
         pc = pc + 1        
         opcode = code[pc]
         syscalls[opcode](stack.pop())
      elseif code[pc] == "add" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 + op2)
      elseif code[pc] == "sub" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 - op2)
      elseif code[pc] == "mul" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 * op2)
      elseif code[pc] == "div" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 / op2)
       elseif code[pc] == "exp" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 ^ op2)
       elseif code[pc] == "rem" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(op1 % op2)
      elseif code[pc] == "lq" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 <= op2))
       elseif code[pc] == "gq" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 >= op2))
       elseif code[pc] == "eq" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 == op2))
       elseif code[pc] == "nq" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 ~= op2))
       elseif code[pc] == "lt" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 < op2))
       elseif code[pc] == "gt" then
        local op2 = stack.pop()
        local op1 = stack.pop()
        stack.push(tOf(op1 > op2))
       elseif code[pc] == "dec" then
         local op = stack.pop()
         stack.push(op - 1)
       elseif code[pc] == "inc" then
         local op = stack.pop()
         stack.push(op + 1)
      elseif code[pc] == "minus" then
        stack.push(-stack.pop())
      else
        error("LAZ0 unkown op code:" .. code[pc])
      end    
      pc = pc + 1
    end
  end
  
  local function printStack()
    stack.printStack()
  end
  
  local function printMemory()
    ut.printtable(mem)
  end
    
  return {
      run = run,
      printStack = printStack,
      printMemory = printMemory
  }
end

--- export functions

lang._parse = Interpreter()._parse -- expose for tests only
lang.Interpreter = Interpreter
lang.VM = VM

return lang