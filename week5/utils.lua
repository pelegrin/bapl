local Utils = {}

local function str_times(s, n)
  local out = s
  for i = 1, n do
    out = "\t".. out
  end  
  return out
end

local function printt(t, n)
  if type(t) ~= "table" then return "" end
  local out = str_times("{", n) .. "\n"
  for k,v in pairs(t) do
    out = out .. str_times("\t", n).. k .. ": " .. (type(v) ~= "table" and tostring(v) or printt(v, n + 1)) .. "\n"
  end
  out = out .. str_times("}", n) .. "\n"
  return out
end

local function printtable(t)
  print(printt(t, 0))
end

local function errorHandler(message, err)
  print("LZ2 ".. tostring(message).. " \n" .. " ".. tostring(err) .."\n")
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

function Stack()
  local self = {_ptr = 0}

  local function isempty()
      return self._ptr == 0
  end
  
  local function push(o)
    self._ptr = self._ptr + 1
    self[self._ptr] = o
  end

  local function pop()
    if isempty() then return nil end
    local res = self[self._ptr]
    self[self._ptr] = nil
    self._ptr = self._ptr - 1
    return res
  end
  
  local function printStack()
    printtable(self)
  end
  
  return {
    isempty = isempty,    
    push = push,
    pop = pop,
    printStack = printStack
  }
end

function List()
  local l = {}
  
  local function get(i)
    return l[i]
  end
  
  local function add(o)
    l[#l + 1] = o
  end
  
  local function elems()
    return #l
  end
  
  local function getAll()
    return l
  end  
  
  local function replace(o, i)
    l[i] = o
  end
  
  local function removeLast()
    local r = l[#l]
    l[#l] = nil
    return r
  end
  
  return {
    get = get,
    add = add,
    elems = elems,
    getAll = getAll,
    replace = replace,
    removeLast = removeLast
  }
end

local function Debug(flag)
  local isDebug = flag
  
  local function debug(f, msg)
    return isDebug and f(msg)
  end

  return {debug = debug}
end

function fileExists(path)
  local file = io.open(path, "rb")
  if file then file:close() end
  return file ~= nil
end

--[[
function readall(filename)
  local fh = io.open(filename, "rb")
  local contents = fh:read(_VERSION <= "Lua 5.2" and "*a" or "a")
  fh:close()
  return contents
end
--]]

Utils.printtable = printtable
Utils.printt = printt
Utils.Stack = Stack
Utils.List = List
Utils.errorHandler = errorHandler
Utils.syntaxErrorHandler = syntaxErrorHandler
Utils.Debug = Debug
Utils.fileExists = fileExists

return Utils

