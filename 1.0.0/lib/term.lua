local term = {}
local gpuAvailable, screenAvailable = false, false
local cursorX, cursorY = 1, 1
local cursorBlink = nil

local function toggleBlink()
  if term.isAvailable() then
    cursorBlink.state = not cursorBlink.state
    if cursorBlink.state then
      cursorBlink.alt = component.gpu.get(cursorX, cursorY)
      component.gpu.set(cursorX, cursorY, unicode.char(0x2588)) -- solid block
    else
      component.gpu.set(cursorX, cursorY, cursorBlink.alt)
    end
  end
end

-------------------------------------------------------------------------------

function term.clear()
  if term.isAvailable() then
    local w, h = component.gpu.getResolution()
    component.gpu.fill(1, 1, w, h, " ")
  end
  cursorX, cursorY = 1, 1
end

function term.clearLine()
  if term.isAvailable() then
    local w = component.gpu.getResolution()
    component.gpu.fill(1, cursorY, w, 1, " ")
  end
  cursorX = 1
end

function term.getCursor()
  return cursorX, cursorY
end

function term.setCursor(col, row)
  checkArg(1, col, "number")
  checkArg(2, row, "number")
  if cursorBlink and cursorBlink.state then
    toggleBlink()
  end
  cursorX = math.floor(col)
  cursorY = math.floor(row)
end

function term.getCursorBlink()
  return cursorBlink ~= nil
end

function term.setCursorBlink(enabled)
  checkArg(1, enabled, "boolean")
  if enabled then
    if not cursorBlink then
      cursorBlink = {}
      cursorBlink.id = event.timer(0.5, toggleBlink, math.huge)
      cursorBlink.state = false
    elseif not cursorBlink.state then
      toggleBlink()
    end
  elseif cursorBlink then
    event.cancel(cursorBlink.id)
    if cursorBlink.state then
      toggleBlink()
    end
    cursorBlink = nil
  end
end

function term.isAvailable()
  return gpuAvailable and screenAvailable
end

function term.read(history)
  checkArg(1, history, "table", "nil")
  history = history or {}
  table.insert(history, "")
  local offset = term.getCursor() - 1
  local scrollX, scrollY = 0, #history - 1

  local function getCursor()
    local cx, cy = term.getCursor()
    return cx - offset + scrollX, 1 + scrollY
  end

  local function line()
    local cbx, cby = getCursor()
    return history[cby]
  end

  local function setCursor(nbx, nby)
    local w, h = component.gpu.getResolution()
    local cx, cy = term.getCursor()

    scrollY = nby - 1

    local ncx = nbx + offset - scrollX
    if ncx > w then
      local sx = nbx - (w - offset)
      local dx = math.abs(scrollX - sx)
      scrollX = sx
      component.gpu.copy(1 + offset + dx, cy, w - offset - dx, 1, -dx, 0)
      local str = unicode.sub(line(), nbx - (dx - 1), nbx)
      str = text.padRight(str, dx)
      component.gpu.set(1 + (w - dx), cy, str)
    elseif ncx < 1 + offset then
      local sx = nbx - 1
      local dx = math.abs(scrollX - sx)
      scrollX = sx
      component.gpu.copy(1 + offset, cy, w - offset - dx, 1, dx, 0)
      local str = unicode.sub(line(), nbx, nbx + dx)
      --str = text.padRight(str, dx)
      component.gpu.set(1 + offset, cy, str)
    end

    term.setCursor(nbx - scrollX + offset, cy)
  end

  local function copyIfNecessary()
    local cbx, cby = getCursor()
    if cby ~= #history then
      history[#history] = line()
      setCursor(cbx, #history)
    end
  end

  local function redraw()
    local cx, cy = term.getCursor()
    local bx, by = 1 + scrollX, 1 + scrollY
    local w, h = component.gpu.getResolution()
    local l = w - offset
    local str = unicode.sub(history[by], bx, bx + l)
    str = text.padRight(str, l)
    component.gpu.set(1 + offset, cy, str)
  end

  local function home()
    local cbx, cby = getCursor()
    setCursor(1, cby)
  end

  local function ende()
    local cbx, cby = getCursor()
    setCursor(unicode.len(line()) + 1, cby)
  end

  local function left()
    local cbx, cby = getCursor()
    if cbx > 1 then
      setCursor(cbx - 1, cby)
      return true -- for backspace
    end
  end

  local function right(n)
    n = n or 1
    local cbx, cby = getCursor()
    local be = unicode.len(line()) + 1
    if cbx < be then
      setCursor(math.min(be, cbx + n), cby)
    end
  end

  local function up()
    local cbx, cby = getCursor()
    if cby > 1 then
      setCursor(cbx, cby - 1)
      redraw()
      ende()
    end
  end

  local function down()
    local cbx, cby = getCursor()
    if cby < #history then
      setCursor(cbx, cby + 1)
      redraw()
      ende()
    end
  end

  local function delete()
    copyIfNecessary()
    local cbx, cby = getCursor()
    if cbx <= unicode.len(line()) then
      history[cby] = unicode.sub(line(), 1, cbx - 1) ..
                     unicode.sub(line(), cbx + 1)
      local cx, cy = term.getCursor()
      local w, h = component.gpu.getResolution()
      component.gpu.copy(cx + 1, cy, w - cx, 1, -1, 0)
      local br = cbx + (w - cx)
      local char = unicode.sub(line(), br, br)
      if not char or unicode.len(char) == 0 then
        char = " "
      end
      component.gpu.set(w, cy, char)
    end
  end

  local function insert(value)
    copyIfNecessary()
    local cx, cy = term.getCursor()
    local cbx, cby = getCursor()
    local w, h = component.gpu.getResolution()
    history[cby] = unicode.sub(line(), 1, cbx - 1) ..
                   value ..
                   unicode.sub(line(), cbx)
    local len = unicode.len(value)
    local n = w - (cx - 1) - len
    if n > 0 then
      component.gpu.copy(cx, cy, n, 1, len, 0)
    end
    component.gpu.set(cx, cy, value)
    right(len)
  end

  local function onKeyDown(char, code)
    term.setCursorBlink(false)
    if code == keyboard.keys.back then
      if left() then delete() end
    elseif code == keyboard.keys.delete then
      delete()
    elseif code == keyboard.keys.left then
      left()
    elseif code == keyboard.keys.right then
      right()
    elseif code == keyboard.keys.home then
      home()
    elseif code == keyboard.keys["end"] then
      ende()
    elseif code == keyboard.keys.up then
      up()
    elseif code == keyboard.keys.down then
      down()
    elseif code == keyboard.keys.enter then
      local cbx, cby = getCursor()
      if cby ~= #history then -- bring entry to front
        history[#history] = line()
        table.remove(history, cby)
      end
      return true, history[#history] .. "\n"
    elseif keyboard.isControlDown() then
      if code == keyboard.keys.d then
        if line() == "" then
          history[#history] = ""
          return true, nil
        end
      elseif code == keyboard.keys.c then
        history[#history] = ""
        return true, nil
      end
    elseif not keyboard.isControl(char) then
      insert(unicode.char(char))
    end
    term.setCursorBlink(true)
    term.setCursorBlink(true) -- force toggle to caret
  end

  local function onClipboard(value)
    copyIfNecessary()
    term.setCursorBlink(false)
    local cbx, cby = getCursor()
    local l = value:find("\n", 1, true)
    if l then
      history[cby] = unicode.sub(line(), 1, cbx - 1)
      redraw()
      insert(unicode.sub(value, 1, l - 1))
      return true, line() .. "\n"
    else
      insert(value)
      term.setCursorBlink(true)
      term.setCursorBlink(true) -- force toggle to caret
    end
  end

  local function cleanup()
    if history[#history] == "" then
      table.remove(history)
    end
    term.setCursorBlink(false)
    print()
  end

  term.setCursorBlink(true)
  while term.isAvailable() do
    local ok, name, address, charOrValue, code = pcall(event.pull)
    if not ok then
      cleanup()
      error("interrupted", 0)
    end
    if term.isAvailable() and -- may have changed since pull
       type(address) == "string" and
       component.isPrimary(address)
    then
      local done, result
      if name == "key_down" then
        done, result = onKeyDown(charOrValue, code)
      elseif name == "clipboard" then
        done, result = onClipboard(charOrValue)
      end
      if done then
        cleanup()
        return result
      end
    end
  end
  cleanup()
  return nil -- fail the read if term becomes unavailable
end

function term.write(value, wrap)
  if not term.isAvailable() then
    return
  end
  value = tostring(value)
  if unicode.len(value) == 0 then
    return
  end
  value = text.detab(value)
  local w, h = component.gpu.getResolution()
  if not w then
    return -- gpu lost its screen but the signal wasn't processed yet.
  end
  local blink = term.getCursorBlink()
  term.setCursorBlink(false)
  local function checkCursor()
    if cursorX > w then
      cursorX = 1
      cursorY = cursorY + 1
    end
    if cursorY > h then
      component.gpu.copy(1, 1, w, h, 0, -1)
      component.gpu.fill(1, h, w, 1, " ")
      cursorY = h
    end
  end
  for line, nl in value:gmatch("([^\r\n]*)([\r\n]?)") do
    while wrap and unicode.len(line) > w - (cursorX - 1) do
      local partial = unicode.sub(line, 1, w - (cursorX - 1))
      local wordWrapped = partial:match("(.*[^a-zA-Z0-9._])")
      if wordWrapped or unicode.len(partial) > w then
        partial = wordWrapped or partial
        line = unicode.sub(line, unicode.len(partial) + 1)
        component.gpu.set(cursorX, cursorY, partial)
      end
      cursorX = math.huge
      checkCursor()
    end
    if unicode.len(line) > 0 then
      component.gpu.set(cursorX, cursorY, line)
      cursorX = cursorX + unicode.len(line)
    end
    if unicode.len(nl) == 1 then
      cursorX = math.huge
      checkCursor()
    end
  end
  term.setCursorBlink(blink)
end

-------------------------------------------------------------------------------

local function onComponentAvailable(_, componentType)
  local wasAvailable = term.isAvailable()
  if componentType == "gpu" then
    gpuAvailable = true
  elseif componentType == "screen" then
    screenAvailable = true
  end
  if not wasAvailable and term.isAvailable() then
    computer.pushSignal("term_available")
  end
end

local function onComponentUnavailable(_, componentType)
  local wasAvailable = term.isAvailable()
  if componentType == "gpu" then
    gpuAvailable = false
  elseif componentType == "screen" then
    screenAvailable = false
  end
  if wasAvailable and not term.isAvailable() then
    computer.pushSignal("term_unavailable")
  end
end

_G.term = term

return function()
  event.listen("component_available", onComponentAvailable)
  event.listen("component_unavailable", onComponentUnavailable)
end
