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
  lu.assertEquals(p(""), nil, "parse empty string")
  lu.assertEquals(p("0XFF"), {tag = "number", val=255}, "parse a hexadecimal number")
  lu.assertEquals(p("-0X1B  "), {e1={tag="number", val=27}, op="-", tag="unop"}, "parse a negative hexadecimal number")
  lu.assertEquals(p("-0X  "), nil, "parse not complete hexadecimal number")
  lu.assertEquals(p("123 "), {tag = "number", val=123}, "parse a positive number")
  lu.assertEquals(p("-56  "), {e1={tag="number", val=56}, op="-", tag="unop"}, "unary minus")  
  lu.assertEquals(p("--56  "), {e1={tag="number", val=56}, op="--", tag="unop"}, "parse decrement")  
  lu.assertEquals(p("--(-56)  "), {e1={e1={tag="number", val=56}, op="-", tag="unop"}, op="--", tag="unop"}, "parse decrement a negative number")  
  lu.assertEquals(p("-0.6   "), {e1={tag="number", val=0.6}, op="-", tag="unop"}, "parse a negative float number")  
  lu.assertEquals(p("-0.  "), nil, "parse incorrect decimal number")  
  lu.assertEquals(p("45.1226  "), {tag = "number", val=45.1226}, "parse a positive float number")  
  lu.assertEquals(p("-A  "), {e1={tag="var", val="A"}, op="-", tag="unop"}, "parse unary op with variable")  
  lu.assertEquals(p("1 + 3  "), {e1={tag="number", val=1}, e2={tag="number", val=3}, op="+", tag="binop"}, "parse summation expression")  
  lu.assertEquals(p("1 < 3  "), {e1={tag="number", val=1}, e2={tag="number", val=3}, op="<", tag="binop"}, "parse logical expression")  
  lu.assertEquals(p("1e-3  "), {tag="number", val=0.001}, "parse scientific notation")  
  lu.assertEquals(p("1.25e-3  "), {tag="number", val=0.00125}, "parse scientific notation with minus e and dot")  
  lu.assertEquals(p(" 625E12  "), {tag="number", val=6.25e+14}, "parse scientific notation with capital E")  
end

function test_varRef()
  local p = lang.parse
  lu.assertEquals(p("a"), {tag = "var", val = "a"}, "parse a single variable")
  lu.assertEquals(p("_a"), {tag = "var", val = "_a"}, "parse an underscore variable")
  lu.assertEquals(p("__a"), {tag = "var", val = "__a"}, "parse underscore underscore variable")
  lu.assertEquals(p("___a"), nil, "parse incorrect variable")
  lu.assertEquals(p("1a"), nil, "parse incorrect variable")
  lu.assertEquals(p("$a"), {tag = "ref", val = "a"}, "parse a reference")
  lu.assertEquals(p("a + b"), {e1={tag="var", val="a"}, e2={tag="var", val="b"}, op="+", tag="binop"}, "parse a variable exp")
  lu.assertEquals(p(" a = 0"), {exp={tag = "number", val = 0}, id="a", tag="assign"}, "parse a variable exp")
  local exp = {
    exp={e1={tag="var", val="a"}, e2={tag="var", val="b"}, op="+", tag="binop"},
    id="c",
    tag="assign"
  }  
 lu.assertEquals(p(" c = a + b"), exp, "parse assignment expression")   
 local exp2 = {
    exp={e1={tag="number", val=1}, e2={tag="number", val=3}, op="*", tag="binop"},
    id="a",
    tag="assign"
  }   
 lu.assertEquals(p("a = 1 * 3"), exp2, "parse multiplication expression")
end



os.exit( lu.LuaUnit.run() )