local lpeg = require "lpeg"
local ut = require "utils"

local lang = {}

-- TODO: Refine. For compiled files 
--[[
local opCode = { ['push'] =    0x01,
  ['load'] =    0x02,
  ['store'] =   0x03,
  ['syscall'] = 0x04,
  ['getglobal'] = 0x05,
  ['setglobal'] = 0x06,
  ---
  ['add'] =   0x10,
  ['sub'] =   0x11,
  ['mul'] =   0x12,
  ['div'] =   0x13,
  ['exp'] =   0x14,
  ['rem'] =   0x15,
  ['lq'] =    0x16,
  ['gq'] =    0x17,
  ['eq'] =    0x18,
  ['nq'] =    0x19,
  ['lt'] =    0x1A,
  ['gt'] =    0x1B,
  ['dec'] =   0x1C,
  ['inc'] =   0x1D,
  ['minus'] = 0x1E,
  ['not'] =   0x1F  
}
--]]

--[[
-- LPeg Debug function
local function I (msg)
  return lpeg.P(function () print(msg); return true end)
end
--]]

local function Interpreter(v, debug)  
  local vars = v or {}
  local nvars = v and #v or 0
  local code = ut.List()
  local jmpAddress = ut.List() -- list of addresses marks the address to jmp from cycle or if statement
  local cAddress = ut.List() -- list of addresses marks the condition of cycle, to this address should jump at end of cycle
  local buffer = ut.List() -- code buffer for interactive mode and processing control structures
  
  -- Debug facilities
  local isDebug = debug or false
  local d = ut.Debug(isDebug)
  
  -- Parser
  local function node(tag, ...)
    local labels = table.pack(...)
    return function (...)
      local params = table.pack(...)
      local t = {}
      if type(tag) == "table" then
        for k,v in pairs(tag) do t[k] = v end
      else
        t["tag"] = tag -- for backward compatibility
       end 
      for i, v in ipairs(labels) do
        t[v] = params[i]
        if tag == "var" and v == "val" then
          -- in variable case, get type from vars
          t["type"] = (vars[params[i]] or {})["type"]
        end  
      end    
      return t
    end  
  end

  local function nodeSys(exp)
    return {tag = "sys", code = "1", exp = exp}
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

  -- numericals
  local floats = loc.digit^1 * "." * loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * space
  local scientific = loc.digit^1* ("." * loc.digit^1 + loc.digit^0 )* lpeg.S("eE") * lpeg.P("-")^0 * loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * space
  local decimals = loc.digit^1 / tonumber / node({tag = "number", ["type"] = "number"}, "val") * (-x) * space
  local hexes = "0" * x * lpeg.C((h + loc.digit)^1) / hex / node({tag = "number", ["type"] = "number"}, "val") * space
  local numerals = hexes + scientific + floats + decimals

  local reserved = {"return", "while", "for", "done","if", "else", "elseif", "end", "and", "or", "true", "false", "number", "bool"}

  local types = lpeg.C(T"number" + T"bool")

  local opA = lpeg.C(lpeg.S("+-")) * space -- addition/substraction
  local opM = lpeg.C(lpeg.S("*/%")) * space -- multiplication/division
  local opE = lpeg.C(lpeg.S("^")) * space   -- exponent
  local opC = lpeg.C(lpeg.P("<=") + ">=" + "==" + "!=" + "<" + ">" + "&" + "|") * space -- comparasion
  local opUn = lpeg.C(lpeg.P("--") + "++" + "-" + "+" + "!") -- unary operators
  local variable = (sym^1 + T"_" * T"_"^-1 * sym^1) * loc.alnum^0 / node("var", "val") * space
  local ref = lpeg.S("$") * (sym^1 * loc.alnum^0 / node("ref", "val") ) * space
  local id = variable + ref
  local pr = lpeg.P("@")
  local unary = lpeg.V("unary")
  local primary = lpeg.V("primary")
  local ternary = lpeg.V("ternary")
  local term = lpeg.V("term")
  local exponent = lpeg.V("exponent")
  local subexpression = lpeg.V("subexpression")
  local expression = lpeg.V("expression")
  local statement = lpeg.V("statement")
  local statements = lpeg.V("statements")
  local bool = (lpeg.P"true" + lpeg.P"false") / node({tag = "bool", ["type"] = "bool"}, "val") * space
  
  local declaration = types * id * space

  local comments = "//" * (lpeg.P(1) - "\n")^0
  local bcommentS = "/*" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentStarted = true; return true end)
  local bcommentE = "*/" * (lpeg.P(1))^0 * lpeg.P(function(_,_) bCommentEnded = true; return true end)

  local grammar = lpeg.P({"prog",
    prog = space * bcommentS^-1 * bcommentE^-1 * statements * -1,    
    statements = space * lpeg.Ct(statement * (T"," * (statement + ""))^0)/ foldSts,    
    statement = T"if" * expression / node("if", "cond") 
              + T"elseif" * expression / node("elseif", "cond") 
              + T"else"/ node("else")
              + T"end"/node("end")
              + T"while" * expression / node("while", "cond")
              + T"done"/node("done")
              + declaration / node("declaration", "type", "id")
              + id * T"=" * (ternary + expression) / node("assign", "id", "exp")
              + pr * expression / nodeSys
              + ternary
              + expression,    
    primary = numerals 
              + bool
              + T"(" * expression * T")"
              + id,
    unary = lpeg.Ct(opUn * primary) /foldUn + primary,    
    exponent = lpeg.Ct(unary * (opE * unary)^0) / foldBin,
    term = lpeg.Ct(exponent * (opM * exponent)^0) / foldBin,
    subexpression = lpeg.Ct(term * (opA * term)^0) / foldBin,
    ternary = lpeg.Ct(expression * T"?" * expression * T":" * expression) / foldTernary,
    expression = lpeg.Ct(subexpression * (opC * subexpression)^0) / foldBin,
    space = (loc.space + comments)^0 * lpeg.P(function (_, p)  maxmatch = p ;return true end)            
  })

  local ops = {["+"] = "add", ["-"] = "sub",
               ["*"] = "mul", ["/"] = "div", ["^"] = "exp", ["%"] = "rem",
               ["<="] = "lq", [">="] = "gq", ["=="] = "eq", ["!="] = "nq", ["<"] = "lt", [">"] = "gt",
               ["&"] = "and", ["|"] = "or"
             }    
  local unops = {["--"] = "dec", ["++"] = "inc", ["-"] = "minus", ["!"] = "not"
            }
            
  local TRUE = 1
  local FALSE = 0
  
  
  
  -- fix element in list at position stored in the end of jmpAddress with dif with address o
  local function fixAddress(o)
    local adr = jmpAddress.removeLast()
    if adr == nil then error("Closing end/done without begining if/while") end
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
    if input == nil or input == "" then return nil, nil end
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
  
  -- Checks if id belongs to reserved words
  local function Rw(id)
    for _, r in ipairs(reserved) do
      if id == r then return true end    
    end  
    return false
  end
  
  local function checkType(t1, t2)
    if t2 ~= nil and t1 ~= nil and string.gsub(t1, " ","") ~= string.gsub(t2, " ", "")  then
      error("Type checking error. Expected " .. string.gsub(t1, " ", "") .. " but get " .. string.gsub(t2, " ",""))
    end
  end

  -- Get global variable structure
  local function getVar(id)
    if Rw(id) then error("Variable "..tostring(id) .. " is a reserved word") end
    local v = vars[id]
    if not v then error("Undefined variable " ..tostring(id)) end
    return v
  end
  
  -- Init global variable, returns index in list
  local function init(id, t)
    local s = vars[id]
    if s then 
      checkType(s["type"], t)
      return s.val
    end
    num = nvars + 1
    vars[id] = {val = num, ["type"] = t}
    nvars = num
    return num
  end
  
  -- Store global variable, returns index in list
  local function store(id)
    local s = vars[id]
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
    elseif ast.tag == "bool" then
      checkType("bool", t)
      addCode("push")
      addCode(ast.val == "true" and TRUE or FALSE)
    elseif ast.tag == "var" then
      addCode("load")
      addCode(getVar(ast.val).val)
    elseif ast.tag == "ref" then
      addCode("loadg")
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
    elseif ast.tag == "ternary" then
      codeExp(ast.cond, t)
      addCode("jmpz")
      addCode(0)
      local adr = code.lastPosition()
      codeExp(ast.e1, t)
      addCode("jmp")
      addCode(0)
      local adr2 = code.lastPosition()
      addCode("noop")
      local fixAddr = code.lastPosition() - adr     
      code.replace(fixAddr, adr)
      codeExp(ast.e2, t)
      addCode("noop")
      fixAddr = code.lastPosition() - adr     
      code.replace(fixAddr, adr2)  
    elseif ast.tag == "binop" then
      checkType(ast.e1.type, ast.e2.type)
      checkType(ast.e1.type, t)
      checkType(ast.e2.type, t)
      codeExp(ast.e1, t or ast.e1.type)
      codeExp(ast.e2, t or ast.e2.type)
      addCode(ops[ast.op])
    elseif ast.tag == "unop" then
      codeExp(ast.e1, t)
      addCode(unops[ast.op])
    else error("invalid tree")
    end    
  end

  -- Codify Statement
  local function codeStatement(ast)
    if ast.tag == "declaration" then
      addCode("init")
      addCode(init(ast.id.val, ast.type))
      addCode(ast.type) -- type as string for now, change to number later
    elseif ast.tag == "assign" then
      checkType(ast.id.type, ast.exp.type)
      codeExp(ast.exp)
      addCode("store")
      addCode(store(ast.id.val))    
    elseif ast.tag == "seq" then
      if ast.s2 == nil then return codeStatement(ast.s1) end
      codeStatement(ast.s1)
      codeStatement(ast.s2)
    elseif ast.tag == "sys" then
      codeExp(ast.exp)
      addCode("syscall")
      addCode(ast.code)
    elseif ast.tag == "while" then
      cAddress.add(code.lastPosition()) -- Jump at the start of condition
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "if" then
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix 
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "elseif" then
      fixAddress(code.lastPosition()) -- jump just before condition execution
      codeExp(ast.cond)
      addCode("jmpz")
      addCode(0) -- jump address to fix 
      jmpAddress.add(code.lastPosition())
    elseif ast.tag == "else" then
      addCode("jmp")
      addCode(0)
      local adr = code.lastPosition()
      fixAddress(adr)
      jmpAddress.add(adr)
    elseif ast.tag == "end" then
      addCode("noop")
      fixAddress(code.lastPosition()) 
    elseif ast.tag == "done" then
     addCode("jmp")
     addCode(getCycleCondAddr() - (code.lastPosition() + 1))
     addCode("noop")
     fixAddress(code.lastPosition()) 
    else codeExp(ast)
    end    
  end

  --runs in interactive mode
  local function interpret(line)
    code = ut.List()
    if not buffer.isEmpty() then code.add(buffer); buffer.clear() end
    local status, ast, err = pcall(parse, line)
    if (err ~= nil) then ut.syntaxErrorHandler(err); return {}, err end
    if ast ~= nil then
          d.debug(print, "AST")
          d.debug(ut.printtable, ast)
          status, err = pcall(codeStatement, ast)
          if not status then
            ut.errorHandler("Compilation error in line: ".. line .. "\n" ..err)
            return {}, err
          end
    end
    -- control structure is not finished
    if jmpAddress.lastPosition() > 0 or cAddress.lastPosition() > 0 then 
      buffer.add(code)
      d.debug(print, "Buffer Code List")
      d.debug(ut.printtable, buffer.getAll())
      return nil, nil
    end
    if not buffer.isEmpty() then
      buffer.add(code)
      local r = buffer.getAll()
      buffer.clear()
      return r
    end  
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
      if ast ~= nil then
          d.debug(print, "AST line: ".. l .."\n")
          d.debug(ut.printtable, ast)
          status, err = pcall(codeStatement, ast)
          if not status then
            ut.errorHandler("Compilation error in line ".. l .. ": " .. line .. "\n" .. err)
            return {}, err
          end          
      end
      l = l + 1
      line = fh:read("*line")
    end
    fh:close()
    
    if jmpAddress.lastPosition() > 0 then error("if statement without closing end") end
    if cAddress.lastPosition() > 0 then error("while statement without closing done") end        
    return code.getAll()
  end
  
  local function printVars()
    ut.printtable(vars)
  end
  
  return {
    interpret = interpret,
    interpretf = interpretf,
    printVars = printVars,
    _parse = parse -- expose for tests only
  }
end

-- TODO: Compile source file to binary ready to be executed by VM
local function Compiler()
    
  local function compile(path)
    local savepath = string.gsub(path, ".lz$", ".lzc")
    local ip = Interpreter()
    local buffer = ip.interpretf(path)
    if buffer ~= nil then ut.printtable(buffer) end
    --[[
    local fc = io.open(savepath, "wb")
    for _v in ipairs(buffer) do
      print(v)
      io:write(v, "\n")
    end
    fc.close()  
    --]]
  end
  
  return {
    compile = compile
  }
end

-- Lazarus VM
local function VM(debug)
  -- Lazarus VM built-in functions
  local syscalls = { ["1"] = function (exp) print(tostring(exp)) end }
  -- internal data structures
  local stack = ut.Stack()
  local mem = {}
  local isDebug = debug or false
  local d = ut.Debug(isDebug)

  local function tOf(b)
    return b and 1 or 0
  end
  
  local function revTof(b)
    return b and 0 or 1
  end

  local function run(code)
    local pc = 1
    while pc <= #code do
      d.debug(stack.printStack)
      if code[pc] == "push" then
        pc = pc + 1
        stack.push(code[pc])
      elseif code[pc] == "load" then
         pc = pc + 1
         local v = mem[code[pc]].val
         if v == nil then error("Variable is not initialized")  end
         stack.push(v)
      elseif code[pc] == "init" then
        pc = pc + 1
        num = pc
        pc = pc + 1        
        mem[code[num]] = {["type"] = code[pc]}
      elseif code[pc] == "store" then
         pc = pc + 1
         mem[code[pc]].val = stack.pop()
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
      elseif code[pc] == "not" then
        stack.push( revTof(stack.pop()) )
      elseif code[pc] == "jmpz" then
        pc = pc + 1
        local jmpDelta = code[pc]
        local cond = stack.pop()
        if (cond == 0 or nil) then pc = pc + jmpDelta end
      elseif code[pc] == "jmp" then
        pc = pc + 1
        local jmpDelta = code[pc]
        pc = pc + jmpDelta
      elseif code[pc] == "jmpzp" then
        --[[
        Checks whether the value on the top of the stack is zero.
        If so, it jumps to a given address without popping the top value,
        otherwise, it pops the top value and continues without jumping
        --]]
        pc = pc + 1
        local jmpDelta = code[pc]
        local v = stack.pop()
        if (v == 0) then
          --jump without pop top of the stack
          stack.push(v)
          pc = pc + jmpDelta
        end
      elseif code[pc] == "jmpnzp" then
         --[[
        Checks whether the value on the top of the stack is not zero.
        If so, it jumps to a given address without popping the top value,
        otherwise, it pops the top value and continues without jumping
        --]]
        pc = pc + 1
        local jmpDelta = code[pc]
        local v = stack.pop()
        if (v ~= 0) then
          --jump without pop top of the stack
          stack.push(v)
          pc = pc + jmpDelta
        end
      elseif code[pc] == "noop" then
        -- do nothing
      else
        error("LAZ0 unkown op code:" .. code[pc])
      end    
      pc = pc + 1
    end
    return stack.pop() -- return top of the stack
  end
  
  -- Debug functions
  local function printStack()
    stack.printStack()
  end
  
  local function printMemory()
    ut.printtable(mem)
  end
    
  return {
      run = run,
      printStack = printStack,
      printMemory = printMemory,
      _tOf = tOf -- for tests
  }
end

--- export functions

lang._parse = Interpreter()._parse -- expose for tests only
lang.Interpreter = Interpreter
lang.VM = VM
lang.Compiler = Compiler
lang.TRUE = TRUE
lang.FALSE = FALSE

return lang