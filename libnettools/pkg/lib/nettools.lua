local internet = require("internet")

local lib = {}

local function getFile(url)
  local data = ""
  local result, response = pcall(internet.request, url, nil, {["user-agent"]="PAMA/OpenComputers"})
  local result, reason = pcall(function()
    if not result then
      return false
    else
      for chunk in response do
        data = data .. chunk
      end
    end
  end)
  if not result then
    return false
  end
  return data
end

return lib
