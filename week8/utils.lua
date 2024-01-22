local Utils = {}

local function str_times(s, n)
  local out = s
  for i = 1, n do
    out = "\t".. out
  end  
  return out
end

local function printt(t, n)
  if type(t) ~= "table" and type(t) ~= "list" then return "" end
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
--  os.exit(1)
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

-- deep copy implementation
local function copyTable(source, dest)
  for i,v in pairs(source) do
    if type(v) == "table" then      
      dest[i] = {}
      copyTable(v, dest[i])
     else       
       dest[i] = v
     end
  end
end  

-- only copy existing keys in destination from source, effectevly updating values in dest table
local function updateTable(source, dest)
  for i,v in pairs(source) do
    if dest[i] then 
      if type(v) == "table" then
        updateTable(v, dest[i])
      else
        dest[i] = v
      end 
    end
  end
end

function Stack(l)
  local self = l or {_ptr = 0}

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
    print("Stack")
    printtable(self)
  end
  
  local function copy()
    local r = {}
    copyTable(self, r)
    return Stack(r)
  end

  return {
    isempty = isempty,    
    push = push,
    pop = pop,
    copy = copy,
    printStack = printStack
  }
end

function List()
  local l = {}
  local list_metatable = {}
  list_metatable.__index = list_metatable
  
  local function get(i)
    return l[i]
  end
  
  --mimic list type  
  local original_type = type  -- saves `type` function
  type = function( obj )
    local otype = original_type( obj )
    if  otype == "table" and getmetatable( obj ) == list_metatable then
        return "list"
    end
    return otype
  end
  local function add(o)
    if type(o) == "list" then
      for _,v in ipairs(o.getAll()) do
        l[#l + 1] = v 
      end 
    else  
      l[#l + 1] = o
    end
  end
    
  local function lastPosition()
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
  
  local function getSection(from, to)
    if from <= 0 or to > lastPosition() then error("Section from list is out of range from " .. tostring(from) .. " to " .. tostring(to)) end
    if from > to then error"Upper bound should be more then lower bound" end
    local r = {}
    local p = 1
    for i = from, to do
      r[p] = l[i]
      p = p + 1
    end
    return r
  end
  
  local function cutSection(from, to)
    local sec = getSection(from, to)
    local p = from
    local last = #l
    for i = from, last do
      if i <= to then 
        l[i] = nil
      else
         l[p] = l[i]
         l[i] = nil
         p = p + 1
      end
     end 
     return sec
   end  
  
  local function getLast()
    return l[#l]
  end
  
  local function isEmpty()
    return #l == 0
  end
  
  local function clear()
    l = {}
  end
    
  return setmetatable ({
    get = get,
    add = add,
    lastPosition = lastPosition,
    getLast = getLast,
    getAll = getAll,
    replace = replace,
    getSection = getSection,
    cutSection = cutSection,
    removeLast = removeLast,
    isEmpty = isEmpty,
    clear = clear
  }, list_metatable)
  
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


function readall(filename)
  local fh = io.open(filename, "rb")
  local contents = fh:read(_VERSION <= "Lua 5.2" and "*a" or "a")
  fh:close()
  return contents
end

local function isArrayType(t)
  if not t then return false end
  return string.find(t, "%[")
end
  

Utils.printtable = printtable
Utils.printt = printt
Utils.Stack = Stack
Utils.List = List
Utils.errorHandler = errorHandler
Utils.syntaxErrorHandler = syntaxErrorHandler
Utils.Debug = Debug
Utils.fileExists = fileExists
Utils.readall = readall
Utils.isArrayType = isArrayType
Utils.copyTable = copyTable
Utils.updateTable = updateTable

return Utils

