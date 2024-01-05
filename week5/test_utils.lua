local lu = require "luaunit"

local ut = require "utils"


function test_printtable_with_not_a_table()
  lu.assertEquals(ut.printt("a",0), "") --print not a table returns empty string
end

function test_printtable_with_list()
local expected = "{\n\t1: a\n\t2: b\n}\n"
lu.assertEquals(ut.printt({"a","b"},0), expected)
end

--[[
function test_printtable_with_table()
local expected = "{\n\tx: a\n\ty: b\n}\n"
lu.assertEquals(ut.printt({x="a",y="b"},0), expected)
end
--]]

function test_stack() 
  local s = ut.Stack()
  lu.assertEquals(s.isempty(), true, "new Stack is empty")
  local o = {hello = "world"}
  s.push(o)
  lu.assertEquals(s.isempty(), false, "Stack with pushed object is not empty")
  actual = s.pop()
  lu.assertEquals(actual, o, "poped objecet from Stack is expected")
  lu.assertEquals(s.isempty(), true, "after pop Stack is empty")
  lu.assertEquals(s.pop(), nil, "empty Stack returns nil")
end

function test_list()
  local l = ut.List()
  lu.assertEquals(l.elems(), 0, "empty list has 0 elements")
  local o = "hello"
  l.add(o)
  lu.assertEquals(l.elems(), 1, "added element in list")
  lu.assertEquals(l.get(1), o, "get element from list")
  local w = "world"
  l.replace(w, 1)
  lu.assertEquals(l.get(1), w, "replace element in list")
end
os.exit( lu.LuaUnit.run() )