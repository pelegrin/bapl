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

Utils.printtable = printtable
Utils.printt = printt

return Utils

