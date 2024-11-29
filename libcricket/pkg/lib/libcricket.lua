local lib = {}

function lib.splitFirst(data, sep)
  checkArg(1, data, "string")
  checkArg(2, sep, "string")
  local index = data:find(sep)
  return data:sub(1, index - 1), data:sub(index + 1, data:len())
end

function lib.splitLast(data, sep)
  checkArg(1, data, "string")
  checkArg(2, sep, "string")
  local index = data:match("^.*()/")
  return data:sub(1, index - 1), data:sub(index + 1, data:len())
end

function lib.dirname(path)
  checkArg(1, path, "string")
  local index = path:match("^.*()/")
  local dir = path:sub(1, index - 1)
  local file = path:sub(index + 1, path:len())
  return dir, file
end

local function makeDirs(file)
  local dirname = pattern.dirname(file)
  local path = ""
  if file:sub(1,1) == "/" then path = "/" end

  for segment in dirname:gmatch("[^/\\]+") do
    path = path .. segment .. "/"
    local success, _, err = fs.makeDirectory(path)

    if not success then
      --
    end
  end
end


return lib
