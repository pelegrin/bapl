local lu = require "luaunit"

local ut = require "utils"


function test_printtable_with_not_a_table()
  lu.assertEquals(ut.printtable("a"), "") --print not a table returns empty string
end

function test_printtable_with_list()
local expected = "{\n\t1: a\n\t2: b\n}\n"
lu.assertEquals(ut.printtable({"a","b"}), expected)
end

function test_printtable_with_table()
local expected = "{\n\tx: a\n\ty: b\n}\n"
lu.assertEquals(ut.printtable({x="a",y="b"}), expected)
end

os.exit( lu.LuaUnit.run() )