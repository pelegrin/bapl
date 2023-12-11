local lu = require "luaunit"
local lang = require "llang"
local lpeg = require "lpeg"

function test_valueOf()
  local loc = lpeg.locale()
  lu.assertEquals(lang.valueOf(loc.digit):match("5"), "5", "capture a digit")
  lu.assertEquals(lang.valueOf("some string"), nil, "accepts lpeg pattern as input")
end

function test_parse()
  local p = lang.parse
  lu.assertEquals(p(""), {}, "parse empty string")
  lu.assertEquals(p("a"), {}, "parse a symbol")
  lu.assertEquals(p("0XFF"), {tag = "number", val=255}, "parse a hexadecimal number")
  lu.assertEquals(p("-0X1B  "), {tag = "number", val=-27}, "parse a negative hexadecimal number")
  lu.assertEquals(p("-0X  "), {tag = "number", val=0}, "parse not complete hexadecimal number")
  lu.assertEquals(p("123 "), {tag = "number", val=123}, "parse a positive number")
  lu.assertEquals(p("-56  "), {tag = "number", val=-56}, "parse a negative number")  
  lu.assertEquals(p("-A  "), {}, "parse incorrect number")  
end


os.exit( lu.LuaUnit.run() )