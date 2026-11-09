-- Clipboard for nvim in an smv machine (linked into nvim's site/plugin by shell-setup).
-- The machine has no system clipboard, so the + and * registers use the same file as the
-- pbcopy and pbpaste stand-ins in /opt/smv/bin, and copies also go to the Mac with OSC 52.
if vim.g.clipboard ~= nil then
  return
end

local file = vim.fn.expand("~/.cache/smv-clipboard")
local osc52 = require("vim.ui.clipboard.osc52")

local function copy(reg)
  local send = osc52.copy(reg)
  return function(lines)
    vim.fn.mkdir(vim.fs.dirname(file), "p")
    local f = assert(io.open(file, "wb"))
    -- nvim ends a line-wise copy with an empty line, so the file ends in a newline
    f:write(table.concat(lines, "\n"))
    f:close()
    send(lines)
  end
end

local function paste()
  local f = io.open(file, "rb")
  if not f then
    return {}
  end
  local text = f:read("*a")
  f:close()
  return vim.split(text, "\n", { plain = true })
end

vim.g.clipboard = {
  name = "smv",
  copy = { ["+"] = copy("+"), ["*"] = copy("*") },
  paste = { ["+"] = paste, ["*"] = paste },
}
