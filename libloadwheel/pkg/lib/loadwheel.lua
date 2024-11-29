local thread = require("thread")
local term = require("term")

local lib = {}

function lib.start(msg)
  checkArg(1, msg, "string")
  local x, y = term.getCursor()
  
  local t = thread.create(function()
    term.setCursorBlink(false)
    io.stdout:write("[ ]: ".. msg)
    while true do
      term.setCursor(x + 1, y)
      io.stdout:write("-")
      os.sleep(0.25)
      term.setCursor(x + 1, y)
      io.stdout:write("\\")
      os.sleep(0.25)
      term.setCursor(x + 1, y)
      io.stdout:write("|")
      os.sleep(0.25)
      term.setCursor(x + 1, y)
      io.stdout:write("/")
      os.sleep(0.25)
    end
  end)
  term.setCursor(1, y + 1)
  return t, x, y
end

function lib.stop(t, x, y, status)
  t:kill()
  local oldx, oldy = term.getCursor()
  term.setCursor(x + 1, y)
  if status then
    io.stdout:write("O")
  else
    io.stdout:write("X")
  end
  term.setCursor(oldx, oldy)
  return
end

return lib
