local Utils = {}

local function printtable(t)
  if type(t) ~= "table" then print "" return "" end
  local out = "{" .. "\n"
  for k,v in pairs(t) do
    out = out .. "\t".. k .. ": " .. tostring(v) .. "\n"
  end
  out = out .. "}" .. "\n"
  print(out)
  return out
end

Utils.printtable = printtable

return Utils

