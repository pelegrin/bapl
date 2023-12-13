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
  lu.assertEquals(p("-0X  "), {}, "parse not complete hexadecimal number")
  lu.assertEquals(p("123 "), {tag = "number", val=123}, "parse a positive number")
  lu.assertEquals(p("-56  "), {tag = "number", val=-56}, "parse a negative number")  
  lu.assertEquals(p("--56  "), {e1={tag="number", val=56}, op="--", tag="unop"}, "parse decrement")  
  lu.assertEquals(p("--(-56)  "), {e1={tag="number", val=-56}, op="--", tag="unop"}, "parse decrement a negative number")  
  lu.assertEquals(p("-0.6   "), {tag = "number", val=-0.6}, "parse a negative float number")  
  lu.assertEquals(p("-0.  "), {}, "parse incorrect decimal number")  
  lu.assertEquals(p("45.1226  "), {tag = "number", val=45.1226}, "parse a positive float number")  
  lu.assertEquals(p("-A  "), {}, "parse incorrect number")  
  lu.assertEquals(p("1 + 3  "), {e1={tag="number", val=1}, e2={tag="number", val=3}, op="+", tag="binop"}, "parse summation expression")  
  lu.assertEquals(p("1 < 3  "), {e1={tag="number", val=1}, e2={tag="number", val=3}, op="<", tag="binop"}, "parse logical expression")  
  lu.assertEquals(p("1e-3  "), {tag="number", val=0.001}, "parse scientific notation")  
  lu.assertEquals(p("1.25e-3  "), {tag="number", val=0.00125}, "parse scientific notation with minus e and dot")  
  lu.assertEquals(p(" 625E12  "), {tag="number", val=6.25e+14}, "parse scientific notation with capital E")  
end


os.exit( lu.LuaUnit.run() )