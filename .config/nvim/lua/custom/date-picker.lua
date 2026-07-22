local M = {}

local function parse_natural(text)
  if not text or text == "" then return nil end
  local today = os.date("*t")
  local t = text:lower():gsub("^%s*(.-)%s*$", "%1")

  local y, m, d = t:match("^(%d%d%d%d)[%-/%s](%d%d)[%-/%s](%d%d)$")
  if y then return { year = tonumber(y), month = tonumber(m), day = tonumber(d) } end

  local m, d = t:match("^(%d%d)[%-/%s](%d%d)$")
  if m then return { year = today.year, month = tonumber(m), day = tonumber(d) } end

  if t:match("^todays?") or t == "." or t == "now" then
    return { year = today.year, month = today.month, day = today.day }
  end

  if t == "tomorrow" or t == "tom" then
    local dt = os.time({ year = today.year, month = today.month, day = today.day + 1 })
    return os.date("*t", dt)
  end

  if t == "yesterday" or t == "yest" then
    local dt = os.time({ year = today.year, month = today.month, day = today.day - 1 })
    return os.date("*t", dt)
  end

  local n = t:match("^in (%d+) days?$")
  if n then
    local dt = os.time({ year = today.year, month = today.month, day = today.day + tonumber(n) })
    return os.date("*t", dt)
  end
  n = t:match("^in (%d+) weeks?$")
  if n then
    local dt = os.time({ year = today.year, month = today.month, day = today.day + tonumber(n) * 7 })
    return os.date("*t", dt)
  end
  n = t:match("^in (%d+) months?$")
  if n then
    n = tonumber(n)
    local m = today.month + n
    local y = today.year
    while m > 12 do m = m - 12; y = y + 1 end
    while m < 1 do m = m + 12; y = y - 1 end
    local d = math.min(today.day, M.days_in_month(y, m))
    return { year = y, month = m, day = d }
  end

  local wdays = {
    monday = 1, mon = 1, tuesday = 2, tue = 2, tues = 2,
    wednesday = 3, wed = 3, weds = 3, thursday = 4, thu = 4, thur = 4, thurs = 4,
    friday = 5, fri = 5, saturday = 6, sat = 6, sunday = 7, sun = 7,
  }
  local function find_wday(name, dir)
    local target = wdays[name]
    if not target then return nil end
    local lua_wday = (today.wday + 5) % 7 + 1
    local diff = target - lua_wday
    if dir == "next" and diff <= 0 then diff = diff + 7 end
    if dir == "last" and diff >= 0 then diff = diff - 7 end
    if dir == "this" and diff < 0 then diff = diff + 7 end
    local dt = os.time({ year = today.year, month = today.month, day = today.day + diff })
    return os.date("*t", dt)
  end
  local p, name = t:match("^(%w+)%s+(%w+)$")
  if p and wdays[name] then
    local r = find_wday(name, p)
    if r then return r end
  end
  if wdays[t] then return find_wday(t, "next") end

  local mnames = {
    january = 1, jan = 1, february = 2, feb = 2, march = 3, mar = 3,
    april = 4, apr = 4, may = 5, june = 6, jun = 6,
    july = 7, jul = 7, august = 8, aug = 8, september = 9, sep = 9, sept = 9,
    october = 10, oct = 10, november = 11, nov = 11, december = 12, dec = 12,
  }
  local day_num, mname
  day_num, mname = t:match("^(%d+)%a+%s+(%w+)$")
  if not day_num then mname, day_num = t:match("^(%w+)%s+(%d+)%a+$") end
  if not day_num then day_num, mname = t:match("^(%d+)%s+(%w+)$") end
  if not day_num then mname, day_num = t:match("^(%w+)%s+(%d+)$") end
  if day_num and mname then
    local m = mnames[mname:lower()]
    if m then
      local d = tonumber(day_num)
      local y = today.year
      if m < today.month or (m == today.month and d < today.day) then y = y + 1 end
      return { year = y, month = m, day = d }
    end
  end

  if t == "next month" then
    local m = today.month + 1
    local y = today.year
    if m > 12 then m = 1; y = y + 1 end
    return { year = y, month = m, day = math.min(today.day, M.days_in_month(y, m)) }
  end
  if t == "last month" or t == "prev month" then
    local m = today.month - 1
    local y = today.year
    if m < 1 then m = 12; y = y - 1 end
    return { year = y, month = m, day = math.min(today.day, M.days_in_month(y, m)) }
  end

  return nil
end

function M.days_in_month(year, month)
  local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local d = days[month]
  if month == 2 then
    local leap = (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
    if leap then d = 29 end
  end
  return d
end

function M.parse(text)
  return parse_natural(text)
end

local function render_month(year, month, highlight)
  local lines = {}
  local header = os.date("%B %Y", os.time({ year = year, month = month, day = 1 }))
  table.insert(lines, "  " .. header)
  table.insert(lines, "  Mo Tu We Th Fr Sa Su")
  local first = os.date("*t", os.time({ year = year, month = month, day = 1 }))
  local start_col = (first.wday + 5) % 7
  local dim = M.days_in_month(year, month)
  local row = ""
  for i = 1, start_col do row = row .. "   " end
  for d = 1, dim do
    local is_hl = highlight and d == highlight.day and year == highlight.year and month == highlight.month
    local is_today = (d == os.date("*t").day and year == os.date("*t").year and month == os.date("*t").month)
    local str
    if is_hl then
      str = string.format("(%2d)", d)
    elseif is_today then
      str = string.format("[%2d]", d)
    else
      str = string.format(" %2d", d)
    end
    row = row .. str
    if (#row >= 20 and (start_col + d) % 7 == 0) or d == dim then
      table.insert(lines, row)
      row = ""
    end
  end
  return lines
end

local function show_calendar_float()
  local today = os.date("*t")
  local m1 = render_month(today.year, today.month, today)
  local ny, nm = today.year, today.month + 1
  if nm > 12 then nm = 1; ny = ny + 1 end
  local m2 = render_month(ny, nm)

  local lines = {}
  for _, l in ipairs(m1) do table.insert(lines, "  " .. l) end
  table.insert(lines, "")
  for _, l in ipairs(m2) do table.insert(lines, "  " .. l) end
  table.insert(lines, "")
  table.insert(lines, "  ───────────────────────────────────────────────")
  table.insert(lines, "  Examples: today | tomorrow | in 3 days")
  table.insert(lines, "  next monday | july 10 | 2026-12-25")
  table.insert(lines, "  ( ) = selected   [ ] = today")

  local w = 64
  local h = #lines + 2
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = w,
    height = h,
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
    row = math.max(0, math.floor((vim.o.lines - h) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Date Picker ",
  })
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  return buf, win
end

function M.pick(opts)
  opts = opts or {}
  local buf, win = show_calendar_float()
  vim.cmd("redraw")
  local input = vim.fn.input("Date (natural lang, Enter=today): ")
  pcall(vim.api.nvim_win_close, win, true)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.cmd("redraw")

  if input and input ~= "" then
    local result = parse_natural(input)
    if not result then
      vim.notify("Could not parse: " .. input, "warn", { title = "Date Picker" })
    end
    return result
  end

  local t = os.date("*t")
  return { year = t.year, month = t.month, day = t.day }
end

return M
