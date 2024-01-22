local lu = require "luaunit"
local lang = require "llang"
local lpeg = require "lpeg"
local ut = require "utils"
local VM = require "vm"

function test_parse()
  local p = lang._parse
  lu.assertEquals(p(""), nil, "parse empty string")
  lu.assertEquals(p("0XFF"), {tag="number", ["type"]="number", val=255}, "parse a hexadecimal number")
  lu.assertEquals(p("-0X1B  "),  {e1={tag="number",  ["type"]="number", val=27}, op="-", tag="unop"}, "parse a negative hexadecimal number")
  lu.assertEquals(p("-0X  "), 1, "parse not complete hexadecimal number")
  lu.assertEquals(p("123 "), {tag = "number", val=123,  ["type"]="number"}, "parse a positive number")
  lu.assertEquals(p("-56  "), {e1={tag="number", val=56, ["type"]="number" }, op="-", tag="unop"}, "unary minus")  
  lu.assertEquals(p("--56  "), {e1={tag="number", val=56,  ["type"]="number"}, op="--", tag="unop"}, "parse decrement")  
  lu.assertEquals(p("--(-56)  "), {e1={e1={tag="number", val=56,  ["type"]="number"}, op="-", tag="unop"}, op="--", tag="unop"}, "parse decrement a negative number")  
  lu.assertEquals(p("-0.6   "), {e1={tag="number", val=0.6,  ["type"]="number"}, op="-", tag="unop"}, "parse a negative float number")  
  lu.assertEquals(p("-0.  "), 1, "parse incorrect decimal number")  
  lu.assertEquals(p("45.1226  "), {tag = "number", val=45.1226,  ["type"]="number"}, "parse a positive float number")  
  lu.assertEquals(p("-A  "), {e1={tag="var", val="A"}, op="-", tag="unop"}, "parse unary op with variable")  
  lu.assertEquals(p("1 + 3  "), {e1={tag="number", val=1,  ["type"]="number"}, e2={tag="number", val=3,  ["type"]="number"}, op="+", tag="binop",  ["type"]="number"}, "parse summation expression")  
  lu.assertEquals(p("1 < 3  "), {e1={tag="number", val=1,  ["type"]="number"}, e2={tag="number", val=3,  ["type"]="number"}, op="<", tag="binop",  ["type"]="number"}, "parse logical expression")  
  lu.assertEquals(p("1e-3  "), {tag="number", val=0.001,  ["type"]="number"}, "parse scientific notation")  
  lu.assertEquals(p("1.25e-3  "), {tag="number", val=0.00125,  ["type"]="number"}, "parse scientific notation with minus e and dot")  
  lu.assertEquals(p(" 625E12  "), {tag="number", val=6.25e+14,  ["type"]="number"}, "parse scientific notation with capital E")  
  lu.assertEquals(p("!1  "), {e1={tag="number", val=1,  ["type"]="number"}, op="!", tag="unop"}, "parse not operation")  
end

function test_varRef()
  local p = lang._parse
  lu.assertEquals(p("a"), {tag = "var", val = "a"}, "parse a single variable")
  lu.assertEquals(p("_a"), {tag = "var", val = "_a"}, "parse an underscore variable")
  lu.assertEquals(p("__a"), {tag = "var", val = "__a"}, "parse underscore underscore variable")
  lu.assertEquals(p("___a"), 1, "parse incorrect variable")
  lu.assertEquals(p("1a"), 1, "parse incorrect variable")
  lu.assertEquals(p("$a"), {tag = "ref", val = "a"}, "parse a reference")
  lu.assertEquals(p("a + b"), {e1={tag="var", val="a"}, e2={tag="var", val="b"}, op="+", tag="binop"}, "parse a variable exp")
  lu.assertEquals(p(" a = 0"), {exp={tag="number", val=0,  ["type"]="number"}, id={tag="var", val="a"}, tag="assign"}, "parse a variable exp")
  local exp = {
    exp={e1={tag="var", val="a"}, e2={tag="var", val="b"}, op="+", tag="binop"},
    id={tag="var", val="c"},
    tag="assign"
  }  
 lu.assertEquals(p(" c = a + b"), exp, "parse assignment expression")   
 local exp2 = {
    exp={e1={tag="number", val=1,  ["type"]="number"}, e2={tag="number", val=3,  ["type"]="number"}, op="*", tag="binop",  ["type"]="number"},
    id={tag="var", val="a"},
    tag="assign"
  }   
 lu.assertEquals(p("a = 1 * 3"), exp2, "parse multiplication expression")
end

function test_sequence()
  local p = lang._parse
  local exp = {
    s1={
        s1={
            exp={tag="number", type="number", val=0},
            id={tag="var", val="x"},
            tag="assign"
        },
        s2={
            exp={tag="number", type="number", val=0},
            id={tag="var", val="y"},
            tag="assign"
        },
        tag="seq"
    },
    s2={
        exp={tag="number", type="number", val=1},
        id={tag="var", val="z"},
        tag="assign"
    },
    tag="seq"
  }
  lu.assertEquals(p("x = 0, y = 0, z = 1"), exp, "parse sequence")
  lu.assertEquals(p("x = 0,,"), 1, "parse empty sequence")
  exp = {
    s1={
        exp={tag="number", type="number", val=0},
        id={tag="var", val="x"},
        tag="assign"
    },
    s2={
        exp={tag="number", type="number", val=0},
        id={tag="var", val="y"},
        tag="assign"
    },
    tag="seq"
  }
  lu.assertEquals(p("x = 0,,y = 0"), 1, "parse empty sequence")
end


function test_compile_assignment()
  local ip = lang.Interpreter()
  ip.interpret("number x")
  local l = ip.interpret("x = 0 ")
  lu.assertEquals(#l, 4, "compile assignment returns not empty list")
  lu.assertEquals(l[1], "push", "compile push code")
  lu.assertEquals(l[2], 0, "compile constant 0")
  lu.assertEquals(l[3], "store", "compile store code")
  lu.assertEquals(l[4], 1, "compile constant 1")
end

-- test if in interactive mode
function test_compile_if()
  local ip = lang.Interpreter()
  ip.interpret("number x, x = 0, if x < 3 ")
  ip.interpret("@x")
  local l = ip.interpret("end")
  lu.assertEquals(#l, 19, "compile assignment and if statement")
  lu.assertEquals(l[1], "init", "declare x")
  lu.assertEquals(l[2], 1, "declare x")
  lu.assertEquals(l[3], "number", "declare x")
  lu.assertEquals(l[4], "push", "compile push code")
  lu.assertEquals(l[5], 0, "compile constant 0")
  lu.assertEquals(l[6], "store", "compile store code")
  lu.assertEquals(l[7], 1, "compile constant 1")
  lu.assertEquals(l[8], "load", "compile x < 3")
  lu.assertEquals(l[9], 1, "compile x < 3")
  lu.assertEquals(l[10], "push", "compile x < 3")
  lu.assertEquals(l[11], 3, "compile x < 3")
  lu.assertEquals(l[12], "lt", "compile x < 3")
  lu.assertEquals(l[13], "jmpz", "compile if")
  lu.assertEquals(l[14], 5, "fixed address in interactive mode")  
  lu.assertEquals(l[15], "load", "load x")  
  lu.assertEquals(l[16], 1, "load x")  
  lu.assertEquals(l[17], "syscall", "print")  
  lu.assertEquals(l[18], 1, "print")  
  lu.assertEquals(l[19], "noop", "end of if control statement")  
end

function test_compile_and()
  local ip = lang.Interpreter()
  local l = ip.interpret(" 1 & 2 ")
  lu.assertEquals(#l, 7, "compile logical and with shortcut")
  lu.assertEquals(l[1], "push", "compile push code")
  lu.assertEquals(l[2], 1, "compile constant 1")
  lu.assertEquals(l[3], "jmpzp", "compile jmpzp (and shortcut)")
  lu.assertEquals(l[4], 3, "compile jump relative address")
  lu.assertEquals(l[5], "push", "compile push code")
  lu.assertEquals(l[6], 2, "compile constant 2")
  lu.assertEquals(l[7], "noop", "compile jump address")  
end

function test_compile_array()
  local ip = lang.Interpreter()
  local l = ip.interpret("[number] y[1 + 3]")
  --[[
        1: push
        2: 1
        3: push
        4: 3
        5: add
        6: init
        7: 1
        8: [number]
  --]]
  lu.assertEquals(#l, 8, "compile array declaration")
  lu.assertEquals(l[1], "push", "compile push code")
  lu.assertEquals(l[2], 1, "compile constant 1")
  lu.assertEquals(l[3], "push", "compile push code")
  lu.assertEquals(l[4], 3, "compile constant 3")
  lu.assertEquals(l[5], "add", "compile add")
  lu.assertEquals(l[6], "init", "declaration code")
  lu.assertEquals(l[7], 1, "compile address in memory")
  lu.assertEquals(l[8], "[number]", "compile type symbol")  
end

function test_syntax_error()
  local p = lang._parse
  local res, actualErr = p("a%")
  local expErr = { line = "a%", position = 2 }
  lu.assertEquals(res, 1, "AST from syntax error")
--  lu.assertEquals(actualErr, expErr, "error object contains syntax error position")
end

function test_comments()
  local p = lang._parse
  lu.assertEquals(p("5 // 4"), {tag="number", type = "number", val=5}, "test end of line comments")
end

function test_true_false()
  local stack = ut.Stack()
  local vm = VM(stack, {})
  lu.assertEquals(vm._tOf(1 < 2), 1, " 1 < 2")
  lu.assertEquals(vm._tOf(2 > 1), 1, " 2 > 1")
  lu.assertEquals(vm._tOf(2 > 6), 0, " 2 > 6")
end

function test_boolean()
  local ip = lang.Interpreter()
  local stack = ut.Stack()
  local vm = VM(stack, {})
  local l = ip.interpret("true")
  vm.run(l)
  lu.assertEquals(stack.pop(), lang.TRUE, "evaluate true")
  local l = ip.interpret("false")
  vm.run(l)
  lu.assertEquals(stack.pop(), lang.FALSE, "evaluate false")

end

os.exit( lu.LuaUnit.run() )