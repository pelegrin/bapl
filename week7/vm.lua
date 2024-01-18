local ut = require "utils"

-- Lazarus VM
local function VM(stack, mem, debug)  
  -- Lazarus VM built-in functions  
  local function sysprint(exp)
    if type(exp) == "table" then
      print("Array")
      ut.printtable(exp)
    else  
      print(tostring(exp))
    end  
  end  
  local syscalls = { ["1"] = sysprint }
  -- internal data structures
  local isDebug = debug or false
  local d = ut.Debug(isDebug)

  local function tOf(b)
    return b and 1 or 0
  end
  
  local function revTof(b)
    return b and 0 or 1
  end
  
  local function getIndx(m)
    s = stack.pop() -- get size from stack
    s = math.tointeger(s)
    if not s or s <= 0 then error(m) end          
    return s
  end
  
  local function buildfunc(code, counter)
        counter = counter + 1
        local n = counter
        counter = counter + 1
        local m = counter
        counter = counter + 1
        mem[code[n]] = {["type"] = "func", params = code[m], forward = nil, rettype = code[counter]}
        counter = counter + 1
        local funccode = ut.List()
        while code[counter] ~= "endf" do
          if code[counter] == "funcdef" then
            counter = buildfunc(code, counter)
          else
            funccode.add(code[counter])
          end
          counter = counter + 1            
        end
        mem[code[n]].code = funccode.getAll()
        return counter
  end

  local function run(code)
    local pc = 1
    while pc <= #code do
      if code[pc] == "funcdef" then        
        pc = buildfunc(code, pc)        
      elseif code[pc] == "funcfdef" then
        pc = pc + 1
        local n = pc
        pc = pc + 1
        mem[code[n]] = {["type"] = "func", forward = true, rettype = code[pc]}
      elseif code[pc] == "call" then
        pc = pc + 1
        local adr = code[pc]
        local funccode = mem[adr].code
        local forward = mem[adr].forward
        if not funccode and not forward then error("Function is not initialized") end
        local numofparams = mem[adr].params or 0
        local i = numofparams
        local m = {}
        ut.copyTable(mem, m)
        -- add parameters in memory with minus indecies
        while i > 0 do
          m[-i] = {val = stack.pop()}
          i = i - 1
        end
        local vm = VM(stack, m, debug)
        stack.push(vm.run(funccode)) -- push return value on stack
        --closure implementation
        --copy memory back, only if return value of type func        
        if mem[adr].rettype == "func" then ut.copyTable(m, mem) end
      elseif code[pc] == "ret" then return stack.pop() -- return top of the stack
      elseif code[pc] == "push" then
        pc = pc + 1
        stack.push(code[pc])
      elseif code[pc] == "load" then
         pc = pc + 1
         local v = (mem[code[pc]] or {}).val
         if v == nil then
           local t = (mem[code[pc]] or {})["type"]
           if t ~= "func" then error("Variable is not initialized") end
           stack.push(code[pc]) -- function reference on stack
         else
           stack.push(v)
         end         
      elseif code[pc] == "init" then
        pc = pc + 1
        num = pc
        pc = pc + 1        
        local t = code[pc]
        local s = nil
        if ut.isArrayType(t) then s = getIndx("Size must be a positive number") end
        mem[code[num]] = {["type"] = t, ["size"] = s}
      elseif code[pc] == "storeat" then
        -- top of stack index in array, and after that value
        local i = getIndx("Index must be a positive number")
        local v = stack.pop()
        pc = pc + 1
        local size = mem[code[pc]].size
        if (i > size) then
          error("Index " .. tostring(i) .. " is out of range. Must be <= " .. tostring( size))
        end
        local a = mem[code[pc]].val or {}
        a[i] = v
        mem[code[pc]].val = a
      elseif code[pc] == "loadat" then
        local i = getIndx("Index must be a positive number")
        pc = pc + 1
        local size = mem[code[pc]].size
        if (i > size) then
          error("Index " .. tostring(i) .. " is out of range. Must be <= " .. tostring( size))
        end
        local v = mem[code[pc]].val[i]
        if v == nil then error("Element is not initialized at index ".. i) end -- TODO: Return NULL value instead
        stack.push(v)
      elseif code[pc] == "store" then
         pc = pc + 1
         local v = mem[code[pc]]
         if v["type"] == "func" then
           local ref = stack.pop()
           v.code = mem[ref].code -- copy code to referenced function
           v.params = mem[ref].params
           v.rettype = mem[ref].rettype
         else  
          v.val = stack.pop()
         end 
      elseif code[pc] == "syscall" then
         pc = pc + 1        
         opcode = code[pc]
         syscalls[tostring(opcode)](stack.pop())
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

return VM