local lu = require "luaunit"

TestSubstring = {}

local function getSubstring(cmd)
  local f = io.popen(cmd)
  local result = f:read("l")
  f:close()
  result = string.gsub(result, "^lazarus line:21 > ", "")
  return result
end

function TestSubstring:test_positive_substring()
  local cmd1 = [[
  echo "@sub('Hello', 3)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd1), "Hel", "first 3 symbols from string")
  local cmd2 = [[
  echo "@sub('Hello', 4)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd2), "Hell", "first 4 symbols from string")
  local cmd3 = [[
  echo "@sub('Hello', 5)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd3), "Hello", "first 5 symbols from string")
  local cmd4 = [[
  echo "@sub('Hello', 6)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd4), "Hello", "substring with more then lenght returns whole string")
  local cmd5 = [[
  echo "@sub('Hello', 0)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd5), "Hello", "substring with 0 number returns whole string")
end

function TestSubstring:test_negative_substring() -- returns substring from the end
  local cmd1 = [[
  echo "@sub('Hello', -2)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd1), "lo", "last 2 symbols from string")
  local cmd2 = [[
  echo "@sub('Hello', -3)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd2), "llo", "last 3 symbols from string")
  local cmd3 = [[
  echo "@sub('Hello', -4)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd3), "ello", "last 4 symbols from string")
  local cmd4 = [[
  echo "@sub('Hello', -5)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd4), "Hello", "whole string")
  local cmd5 = [[
  echo "@sub('Hello', -6)"| ./lazarus -i systemlib/substring.lz
  ]]
  lu.assertEquals(getSubstring(cmd5), "Hello", "whole string")
end

os.exit( lu.LuaUnit.run() )