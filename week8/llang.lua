local lpeg = require "lpeg"
local ut = require "utils"
local systemlib = require "systemlib"

local lang = {}


-- LPeg Debug function
local function I (msg)
  return lpeg.P(function () io.write(msg); return true end)
end


local TRUE = true
local FALSE = false
  
local function Interpreter(debug)  
  local vars = {}
  system = {}
  for k,v in pairs(systemlib.interpreter) do
    system[k] = v
  end  
  vars["$"] = system
  local nvars = 0
  local params = ut.List()
  -- stores function name when declaration happened, empty when no active function declaration
  -- layout: { 1: id, cAddress = List() copy from global scope, jmpAddress = List() copy from global scope
  local fdeclared = ut.List()
  local code = ut.List()
  local jmpAddress = ut.List() -- list of addresses marks the address to jmp from cycle or if statement
  local cAddress = ut.List() -- list of addresses marks the condition of cycle, to this address should jump at end of cycle
  local buffer = ut.List() -- code buffer for interactive mode and processing control structures
  local scope = ut.List()
  scope.add("main")
  --[[
  -- special structure that keeps declaration for one processing line for rollback
    using in case of compilation error in sequence.    
  --]]
  local declared = ut.List()   
  --Remove declared variables from vars structure
  local function rollback_declared()
    local i = 0
    for _,v in ipairs(declared.getAll()) do
      (vars[v.scope])[v.id] = nil
      i = i + 1
    end
    nvars = nvars - i
    declared.clear()
    params.clear()
  end  
    
  -- Debug facilities
  local isDebug = debug or false
  local d = ut.Debug(isDebug)
  
  -- Type system functions
   
  -- Allow types for unary operator
  local opAllowTypes = {
    ["#"] = {"[number]", "[bool]", "[func]", "string"},
    ["--"] = {"number"},
    ["++"] = {"number"},
    ["-"] = {"number"},
    ["+"] = {"number", "string"},
    ["!"] = {"bool"},
    ["indx"] = {"[number]", "[bool]", "[func]", "[string]", "string"}
  }
    
  local function checkType(t1, t2, m)
    if t2 ~= nil and t1 ~= nil and string.gsub(t1, " ","") ~= string.gsub(t2, " ", "")  then
      error(m or "" .. "Type checking error. Expected " .. string.gsub(t1, " ", "") .. " but get " .. string.gsub(t2, " ",""))
    end
  end
  
  local function isAllowTypeForOp(op, t)
    local allowedTyped = opAllowTypes[op]
    if not allowedTyped or not t then return true end -- if missing information, dont do type checks
    for _,v in ipairs(allowedTyped) do
      if v == t then return true end
    end
      error("Type checking error. Expected one of " .. table.concat(allowedTyped, ", ") .. " but get " .. tostring(t))
  end
  
  -- Check parameter in func definition TODO: type checking
  local function checkParams(id, t)
    for i,v in ipairs(params.getAll()) do
      if v.id == id then 
        checkType(t, v.type) 
        return {val = -i }
      end
    end
    return nil
  end

  -- Reserved words
  local reserved = {
    "return", "while", "for", "done", "elseif", "if", "else" , "end", "and", "or", "true", "false", "number", "bool", "string", "func"
    }
  
    -- Checks if id belongs to reserved words
  local function Rw(id)
    for _, r in ipairs(reserved) do
      if id == r then return true end    
    end  
    return false
  end  

      -- Get global variable structure
  local function getVar(id, t)
    if Rw(id) then error("Variable "..tostring(id) .. " is a reserved word") end
    local s = checkParams(id, t)
    if s then return s end
    
    --get all scopes where variable is visible
    local scopes = scope.getAll()
    -- search from last to first
    local v
    for i = #scopes, 1, -1 do
      v = (vars[scopes[i]] or {})[id]
      if v then break end
    end
    if not v then 
      --check system scope
      v = vars["$"][id]
      if not v then error("Undefined variable " ..tostring(id)) end
    end
    return v
  end

  -- Parser part
  
  --[[
  -- Generic node function
  -- allows set tree elements if pass table in tag parameter
  -- sending a type information like this
  --]]
  local function node(tag, ...)
    local labels = table.pack(...)
    return function (...)
      local p = table.pack(...)
      local t = {}
      if type(tag) == "table" then
        for k,v in pairs(tag) do t[k] = v end
      else
        t["tag"] = tag -- for backward compatibility
       end 
      for i, v in ipairs(labels) do
        t[v] = p[i]
        if tag == "var" and v == "val" then
          -- in variable case, get type from vars
          t["type"] = ( (vars[scope.getLast()] or {})[p[i]] or {})["type"]
          if not t["type"] then
            --get type from func parameter
            for _,pr in ipairs(params.getAll()) do
              if t["val"] == pr["id"] then
                t["type"] = pr["type"]
                break
              end
            end
          end
        end
        if tag == "getidx" and v == "id" then 
          -- in case of array get type from id table
          local idxType = (t[v])["type"] or ""
          t["type"] = string.gsub(idxType, "[%[%]]", "")
        end
      end    
      return t
    end  
  end
  
  local function hex(n)  
    return tonumber(n, 16)
  end

  -- Convert a list {n1, "+", n2, "+", n3, ...} into a tree
  -- {...{ op = "+", e1 = {op = "+", e1 = n1, n2 = n2}, e2 = n3}...}
  local function foldBin(lst)
    local tree = lst[1]
    for i = 2, #lst, 2 do
      tree = { tag = "binop", e1 = tree, op = lst[i], e2 = lst[i + 1], ["type"] = tree.type }
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
  
  -- create sequence from declaration and assignment
  local function tostatements(ast)
    local declaration = ast.declaration
    ast.declaration = nil
    local assignment = ast
    assignment.id = declaration.id
    local r = {}
    r.tag = "seq"
    r.s1 = declaration
    r.s2 = assignment
    return r
  end
  
  -- Convert a function defenition 
  local function foldFunc(lst)
    tree = { tag = "funcdef" , ["type"] = lst[1], id = lst[2].val, size = lst[2].size, params = {}}
    local p = 1
    for i = 3, #lst, 2 do
      if type(lst[i]) == "table" then
        tree.params.default = lst[i]
      else
        tree.params[p] = { ["type"] = lst[i], id = lst[i + 1].val }  
      end
      p = p + 1
    end
    return tree
  end
  
  local function foldFuncCall(lst)
    tree = { tag = "call", id = lst[1], params = {}}
    local p = 1
    for i = 2, #lst do
      tree.params[p] = lst[i]  
      p = p + 1
    end
    -- find declaration in scope and check params
    -- if call using not all parameter adding default expression if exists
    local scopes = scope.getAll()
    for i = #scopes, 1, -1 do   
      varsInScope = vars[scopes[i]]
      if varsInScope then 
        for k,v in pairs(varsInScope) do
          if k == tree.id.val then
            if v.forward or not v.params then goto done end -- forward declaration is not supported with default parameters
            -- check number of parameters and default
            if (v.params - #tree.params) == 1 then tree.params[#tree.params + 1] = v.default end
            goto done
          end
        end
      end
    end
    ::done::
    return tree
  end  
    
  
  local function foldForwardFunc(lst)
    return { tag = "funcfdef" , ["type"] = lst[1], id = lst[2].val, size = lst[2].size}
  end
  
  -- Convert a list {cond, true expression, false expression} into a tree
  local function foldTernary(lst)
    return { tag = "ternary", cond = lst[1], e1 = lst[2], e2 = lst[3] }
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
  
  local alpha = lpeg.R("AZ", "az")
  local digit = lpeg.R("09")
  local alphanum = alpha + digit
  
  local function Res(t)
    return t * -alphanum * space
  end

  -- Numericals
  local floats = loc.digit^1 * "." * loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * space
  local scientific = loc.digit^1* ("." * loc.digit^1 + loc.digit^0 )* lpeg.S("eE") * lpeg.P("-")^0 * loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * space
  local decimals = loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * (-x) * space
  local hexes = "0" * x * lpeg.C((h + loc.digit)^1) / hex / node({tag = "number", ["type"] = "number"}, "val") * space
  local numerals = hexes + scientific + floats + decimals
  
  -- Strings
  local literals = lpeg.P("'") * (lpeg.P(1) - lpeg.P("'"))^0 * lpeg.P("'") / node({tag = "literals", ["type"] = "string"}, "val") * space
  
  local prTypes = lpeg.P"number" + "bool" + "func" + "string"
  local array = ("[" * prTypes * "]") -- (lpeg.P"[" * "]")^-1 *
  
  local opA = lpeg.C(lpeg.S("+-")) * space -- addition/substraction
  local opM = lpeg.C(lpeg.S("*/%")) * space -- multiplication/division
  local opE = lpeg.C(lpeg.S("^")) * space   -- exponent
  local opC = lpeg.C(lpeg.P("<=") + ">=" + "==" + "!=" + "<" + ">") * space -- comparasion
  local opL = lpeg.C(lpeg.P("&&") + "||") * space -- AND and OR
  local opUn = lpeg.C(lpeg.P("--") + "++" + "-" + "+" + "!" + "#") -- unary operators
  local variable = (sym^1 + T"_" * T"_"^-1 * sym^1) * loc.alnum^0 / node("var", "val") * space
  local ref = lpeg.S("$") * (sym^1 * loc.alnum^0 / node("ref", "val") ) * space
  local id = variable + ref
  local sys = lpeg.C(lpeg.P"@" + "->")
  local unary = lpeg.V("unary")
  local primary = lpeg.V("primary")
  local ternary = lpeg.V("ternary")
  local term = lpeg.V("term")
  local exponent = lpeg.V("exponent")
  local additionsubstraction = lpeg.V("additionsubstraction")
  local comparison = lpeg.V("comparison")
  local expression = lpeg.V("expression")
  local types = lpeg.V("types")
  local statement = lpeg.V("statement")
  local statements = lpeg.V("statements")
  
  local bool = (lpeg.P"true" + lpeg.P"false") / node({tag = "bool", ["type"] = "bool"}, "val") * space
  
  local idx = T"[" * expression * T"]"
  local declaration = types * id * idx^-1 * space
  -- syntactic sugar, union declaration and assignment
  local initialization = declaration /node("declaration", "type", "id", "size") * T"=" * (ternary + expression) / node("assign", "declaration", "exp")
  
  local setvar = id * T"=" * (ternary + expression) / node("assign", "id", "exp")
  
  local setindex = id * idx * T"=" * (ternary + expression) / node("setidx", "id", "indx", "exp")
  local indexed = id * idx / node("getidx", "id", "indx")                   
  local assignment = setindex + setvar
  
  local comments = "//" * (lpeg.P(1) - "\n")^0 
  local bcommentS = "/*" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentStarted = true; return true end)
  local bcommentE = "*/" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentEnded = true; return true end)
  
  local funcdef = lpeg.V("funcdef")
  local funcall = lpeg.V("funcall")  

  local grammar = lpeg.P({"prog",
    prog = space * funcdef + space * ternary + space * statements * -1 + space * bcommentS^-1 * bcommentE^-1,
    statements = lpeg.Ct(statement * (T"," * (statement))^0) / foldSts,    
    statement = Res"return" * expression / node("return", "val")
              + Res"if" * expression / node("if", "cond") 
              + Res"else"/ node("else")
              + Res"elseif" * expression / node("elseif", "cond") 
              + Res"end"/node("end")
              + Res"while" * expression / node("while", "cond")
              + Res"done"/node("done")
              + initialization / tostatements
              + declaration / node("declaration", "type", "id", "size")
              + assignment
              + sys * expression / node("sys", "opcode", "exp")
              + expression,
    primary = numerals
              + literals
              + bool
              + funcall
              + T"(" * expression * T")"
              + indexed
              + id,
    unary = lpeg.Ct(opUn * primary) /foldUn + primary,    
    exponent = lpeg.Ct(unary * (opE * unary)^0) / foldBin,
    term = lpeg.Ct(exponent * (opM * exponent)^0) / foldBin,
    additionsubstraction = lpeg.Ct(term * (opA * term)^0) / foldBin,
    comparison = lpeg.Ct(additionsubstraction * (opC * additionsubstraction)^0) / foldBin,  
    expression = lpeg.Ct(comparison * (opL * comparison)^0) / foldBin,
    ternary = lpeg.Ct(expression * T"?" * statement  * T":" * statement) / foldTernary,
    space = (lpeg.S(" \t\n") + comments)^0
                  * lpeg.P(function (_, p)
                            maxmatch = math.max(maxmatch, p);
                            return true
                          end),    
    types = lpeg.C(array + prTypes) * space,
    funcdef = lpeg.Ct(types * Res"func" * id * T"(" * (types * id)^-1 * (T"," * types * id)^0 * (T"=" * expression)^-1 * T")") / foldFunc
             + lpeg.Ct(types * Res"func" * id ) / foldForwardFunc,
    funcall = lpeg.Ct(id * T"(" * expression ^-1 * (T"," * expression)^0 * T")") / foldFuncCall
  })

  local ops = {["+"] = "add", ["-"] = "sub",
               ["*"] = "mul", ["/"] = "div", ["^"] = "exp", ["%"] = "rem",
               ["<="] = "lq", [">="] = "gq", ["=="] = "eq", ["!="] = "nq", ["<"] = "lt", [">"] = "gt",
               ["&&"] = "and", ["||"] = "or"
             }    
  local unops = {["--"] = "dec", ["++"] = "inc", ["-"] = "minus", ["!"] = "not", ["#"] = "size",
          }              
   
   local systemfunc = {["@"] = 1, ["->"] = 2}
  
  -- fix element in list at position stored in the end of jmpAddress with dif with address o
  local function fixAddress(o, adr)
    if adr == nil then error("Closing end without begining") end
    o = o - adr
    code.replace(o, adr)
  end  
  
  local function getCycleCondAddr()
    local adr = cAddress.removeLast()
    if adr == nil then error("Closing done without begining while") end
    return adr
  end
  
  -- Parse input string
  local function parse(input)
    if input == nil or input == "" or string.gsub(input, "%s" , "") == "" then return nil, nil end
    local ast = grammar:match(input)
    if bCommentEnded then bCommentEnded = false; bCommentStarted = false; return nil, nil end
    if bCommentStarted then return nil, nil end
    if ast == nil then return nil, {line = input, position = maxmatch - 1} end
    return  ast, nil
  end
  
  -- Add op code to global list
  local function addCode(op)
    code.add(op)
  end
        
  -- TODO: merge with checkType
  local function checkAssignType(id, t2)    
    if t2 == nil or id == nil then return end
    local v = getVar(id.val, t2) 
    if not v or not v.type then return end
    if string.gsub(v.type, "[%[%]]","") ~= string.gsub(t2, " ", "")  then
      error("Type checking error. Expected " .. string.gsub(v.type, "[%[%]]", "") .. " but get " .. string.gsub(t2, " ",""))
    end
  end    
  
  -- Declare global variable or function, returns index in list
  local function init(id, t, size, p, rettype, forward)
    local cscope = scope.getLast()
    local s = (vars[cscope] or {})[id]
    if s and not s.forward then 
      error("id with name " .. id .." already defined")
    elseif s and s.forward then
      --full declaration      
      if p then
        vars[cscope][id].params = #p
        if p.default then vars[cscope][id].default = p.default; p.default = nil end
        params.clear()
        for _,v in ipairs(p) do
          params.add(v)
        end        
      end
      s.forward = nil
      return s.val, params.getAll()
    end
    if ut.isArrayType(t) and not size then
      error("Array size must be specified in declaration")
    end  
    if size then
      checkType("number", size.type, "Array size must be a number\n")
    end  
    num = nvars + 1
    if not vars[cscope] then vars[cscope] = {} end -- create scope if not exist
    vars[cscope][id] = {val = num, ["type"] = t, forward = forward, scope = cscope, name = id}    
    if rettype then vars[cscope][id].rettype = rettype end
    nvars = num
    declared.add({id = id, scope = cscope})
    if p then
      if p.default then vars[cscope][id].default = p.default; p.default = nil end
      vars[cscope][id].params = #p
      params.clear()
      for _,v in ipairs(p) do
        params.add(v)
      end
    end
    return num, params.getAll()
  end    
    
  -- Store global variable, returns index in list
  local function store(id)
    local s = getVar(id)
    if not s then error("Variable "..tostring(id) .. " is not declared") end
    return s.val
  end
  
  -- Codify expression 
  -- ast - AST
  -- t - type of expression for type checking
  local function codeExp(ast, t)
    if ast.tag == "number" then
      checkType("number", t)
      addCode("push")
      addCode(ast.val)
    elseif ast.tag == "literals" then
      checkType("string", t)
      addCode("push")
      local s = string.gsub(ast.val, "^'", "")
      s = string.gsub(s, "'$", "")
      addCode(s)
    elseif ast.tag == "bool" then
      checkType("bool", t)
      addCode("push")
      addCode(ast.val == "true" and TRUE or FALSE)
    elseif ast.tag == "getidx" then
      checkType("number", ast.indx.type, "Array index must be a number\n")
      local v = getVar(ast.id.val)
      local t = v.type or ast.type
      isAllowTypeForOp("indx", t)
      codeExp(ast.indx, ast.indx.type)
      addCode("loadat")
      addCode(v.val)
    elseif ast.tag == "call" then
      local record = getVar(ast.id.val)
      local astp = #ast.params or 0
      local fp = record.params
      if not record.forward and fp and fp ~= astp then
        error("Function ".. tostring(record.name) .. " must have " .. tostring(fp) .. " params but called with " .. tostring(astp))
      end
      --push parameters on stack in reverse order 
      if astp > 0 then
        for i = astp, 1, -1  do
          codeExp(ast.params[i])
         end
      end
       addCode("call")
   --  if not record.code then error("Function ".. tostring(ast.id.val) .. " is not initialized") end
       addCode(record.val) 
    elseif ast.tag == "var" then
      addCode("load")
      addCode(getVar(ast.val).val)
    elseif ast.tag == "ref" then
      addCode("loadref")
      addCode(getVar(ast.val).val)
    elseif ast.tag == "binop" and ops[ast.op] == "and" then
      codeExp(ast.e1, t)
      addCode("jmpzp")
      addCode(0) -- jump address to fix
      local adr = code.lastPosition()
      codeExp(ast.e2, t)
      addCode("noop")
      local fixAddr = code.lastPosition() - adr
      code.replace(fixAddr, adr)
    elseif ast.tag == "binop" and ops[ast.op] == "or" then
      codeExp(ast.e1, t)
      addCode("jmpnzp")
      addCode(0) -- jump address to fix
      local adr = code.lastPosition()
      codeExp(ast.e2, t)
      addCode("noop")
      local fixAddr = code.lastPosition() - adr
      code.replace(fixAddr, adr)      
    elseif ast.tag == "binop" then
      isAllowTypeForOp(ast.op, ast.e1.type)
      isAllowTypeForOp(ast.op, ast.e2.type)
      isAllowTypeForOp(ast.op, t)
      checkType(ast.e1.type, ast.e2.type)
      checkType(ast.e1.type, t)
      checkType(ast.e2.type, t)
      codeExp(ast.e1, t or ast.e1.type)
      codeExp(ast.e2, t or ast.e2.type)
      addCode(ops[ast.op])
    elseif ast.tag == "unop" then
      t = t or ast.e1.type
      isAllowTypeForOp(ast.op, t)
      codeExp(ast.e1, t)
      addCode(unops[ast.op])
    else 
      ut.printtable(ast)
      error("invalid tree")
    end    
  end

  -- Codify Statement
  local function codeStatement(ast)
    if ast.tag == "funcdef" then
      local v, p = init(ast.id, "func", ast.size, ast.params, ast.type)
      fdeclared.add({ast.id, jmpAddress = jmpAddress, cAddress = cAddress, scope = scope.getLast()}) -- keep cycles and if jumps from main code
      scope.add(ast.id)
      if ast.size then
        codeExp(ast.size) -- push size number on stack
      end
      addCode("funcdef")
      --if fdeclared.lastPosition() > 0 then error("Another function is declaring, not allowed nested declaration") end
      jmpAddress = ut.List(); cAddress = ut.List()
      jmpAddress.add(code.lastPosition())
      addCode(v) -- number of function in memory
      addCode(#p) -- number of parameters
      addCode(ast.type) -- return type for functions
    elseif ast.tag == "funcfdef" then
      local v, p = init(ast.id, "func", ast.size, {}, ast.type, true)
      if ast.size then
        codeExp(ast.size) -- push size number on stack
      end
      addCode("funcfdef")
      addCode(v) -- number of function in memory
      addCode(ast.type) -- return type for functions
    elseif ast.tag == "return" then 
      local df = fdeclared.getLast()
      local v = vars[df.scope]
      df = df and v[df[1]] -- get function id from scope
      if not df then error("Return statement without function declaration") end 
      checkType(df.rettype, ast.val.type)
      codeExp(ast.val)
      addCode("ret")
    elseif ast.tag == "declaration" then
      local v = init(ast.id.val, ast.type, ast.size)
      if ast.size then
        codeExp(ast.size) -- push size number on stack
      end  
      addCode("init")
      addCode(v)
      addCode(ast.type) -- type as string for now, change to number later
    elseif ast.tag == "setidx" then
      checkAssignType(ast.id, ast.exp.type)
      checkType("number", ast.indx.type, "Array index must be a number\n")
      codeExp(ast.exp)
      codeExp(ast.indx)
      addCode("storeat") -- top of stack index in array, and after that value
      addCode(store(ast.id.val))
    elseif ast.tag == "assign" then
      checkAssignType(ast.id, ast.exp.type)
      codeExp(ast.exp, ast.exp.type)
      addCode("store")
      addCode(store(ast.id.val))    
    elseif ast.tag == "seq" then
      if ast.s2 == nil then return codeStatement(ast.s1) end
      codeStatement(ast.s1)
      codeStatement(ast.s2)
    elseif ast.tag == "sys" then
      codeExp(ast.exp)
      addCode("syscall")
      addCode(systemfunc[ast.opcode])
    elseif ast.tag == "while" then
      cAddress.add(code.lastPosition()) -- Jump at the start of condition
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "ternary" then
      codeExp(ast.cond, t)
      addCode("jmpz")
      addCode(0)
      local adr = code.lastPosition()
      codeStatement(ast.e1, t)
      addCode("jmp")
      addCode(0)
      local adr2 = code.lastPosition()
      addCode("noop")
      local fixAddr = code.lastPosition() - adr     
      code.replace(fixAddr, adr)
      codeStatement(ast.e2, t)
      addCode("noop")
      fixAddr = code.lastPosition() - adr     
      code.replace(fixAddr, adr2)  
    elseif ast.tag == "if" then
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix 
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "elseif" then
      fixAddress(code.lastPosition(), jmpAddress.removeLast()) -- jump just before condition execution
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix 
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "else" then
      addCode("jmp")
      addCode(0)
      local adr = code.lastPosition()
      fixAddress(adr, jmpAddress.removeLast())
      jmpAddress.add(adr)
    elseif ast.tag == "end" then
      addCode("noop")
      local adr = jmpAddress.removeLast()
      if fdeclared.getLast() ~= nil and jmpAddress.lastPosition() == 0 then
        -- end of function declaration
        addCode("endf")
        local g = fdeclared.removeLast()
        --restore addresses from previous scope
        jmpAddress = g.jmpAddress 
        cAddress = g.cAddress
        local funccode = code.getSection(adr, code.lastPosition())
        vars[g.scope][g[1]].code = funccode
        scope.removeLast()
        params.clear()
      else 
        fixAddress(code.lastPosition(), adr)
      end  
    elseif ast.tag == "done" then
     addCode("jmp")
     addCode(getCycleCondAddr() - (code.lastPosition() + 1))
     addCode("noop")
     fixAddress(code.lastPosition(), jmpAddress.removeLast()) 
    else codeExp(ast)
    end    
  end

  --runs in interactive mode
  local function interpret(line)
    code = ut.List()
    if not buffer.isEmpty() then code.add(buffer); buffer.clear() end
    local status, ast, err = pcall(parse, line)
    if (err ~= nil) then ut.syntaxErrorHandler(err); return {}, err end
    if type(ast) == "number" then ut.syntaxErrorHandler({line = line, position = ast}); return {}, nil end
    if ast ~= nil then
          d.debug(print, "AST")
          d.debug(ut.printtable, ast)
          status, err = pcall(codeStatement, ast)
          if not status then
            ut.errorHandler("Compilation error in line: ".. line .. "\n" ..err)
            --rollback declarations
            rollback_declared()
            return {}, err
          end
    end
    -- control structure or function declarataion is not finished
    if jmpAddress.lastPosition() > 0 or cAddress.lastPosition() > 0 or fdeclared.lastPosition() > 0 then 
      buffer.add(code)
      d.debug(print, "Buffer Code List")
      d.debug(ut.printtable, buffer.getAll())
      return nil, nil
    end
    if not buffer.isEmpty() then
      buffer.add(code)
      local r = buffer.getAll()
      buffer.clear()
      declared.clear()
      return r
    end  
    declared.clear()
    return code.getAll()
  end    
  
  local function interpretf(path)
    code = ut.List()    
    local fh = io.open(path, "rb")
    local l = 1
    local line = fh:read("*line")    
    
    while line do 
      local status, ast, err = pcall(parse, line)
      if (err ~= nil) then ut.syntaxErrorHandler(err); return {}, err end
      if type(ast) == "number" then
        ut.syntaxErrorHandler({line = line, position = ast})
        os.exit(1)
      elseif ast ~= nil then
          d.debug(print, "AST line: ".. l)
          d.debug(ut.printtable, ast)
          status, err = pcall(codeStatement, ast)
          d.debug(print, "Internal variables")
          d.debug(ut.printtable, vars)
          if not status then
            ut.errorHandler("Compilation error in line ".. l .. ": " .. line .. "\n" .. err)
            -- rollback declaration
            rollback_declared()
            return {}, err
          end          
      end
      l = l + 1
      line = fh:read("*line")
    end
    fh:close()    
    if fdeclared.lastPosition() > 0 then
      rollback_declared()
      error("function declaration without return statement")
     end 
    if jmpAddress.lastPosition() > 0 then
      rollback_declared()
      error("if statement without closing end")
    end
    if cAddress.lastPosition() > 0 then
      rollback_declared()
      error("while statement without closing done")
    end        
    declared.clear()
    fdeclared.clear()
    return code.getAll()
  end
  
  local function printVars()
    ut.printtable(vars)
    --[[
    print"Function in process of declaration"
    ut.printtable(fdeclared.getAll())
    --]]
  end
  
  local function printFrame()
    ut.printtable(params.getAll())
  end
  
  local function printBuff()
    ut.printtable(buffer.getAll())
  end
  
  return {
    interpret = interpret,
    interpretf = interpretf,
    printVars = printVars,
    printFrame = printFrame,
    printBuff = printBuff,
    _parse = parse -- expose for tests only
  }
end

--- export functions

lang._parse = Interpreter()._parse -- expose for tests only
lang.Interpreter = Interpreter
lang.TRUE = TRUE
lang.FALSE = FALSE

return lang