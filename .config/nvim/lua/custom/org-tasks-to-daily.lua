local M = {}

local function today_str()
  return os.date("%Y-%m-%d")
end

local function strip_date_info(title)
  title = title:gsub(" 📅", "")
  title = title:gsub(" ⚠️ DEADLINE", "")
  title = title:gsub("%s*`[^`]+`$", "")
  title = title:gsub("%s+$", "")
  return title
end

local function now_ts()
  return os.date("%Y-%m-%d %a %H:%M")
end

local function get_org_files()
  local vault = "/mnt/shared/Obsidian/ZaWaruto"
  local patterns = {
    vault .. "/org/**/*.org",
    vault .. "/Private/200 Tasks/**/*.org",
  }
  local files = {}
  for _, pattern in ipairs(patterns) do
    local iter = vim.fn.glob(pattern, false, true)
    for _, f in ipairs(iter) do
      if not f:match("_archive") then
        files[f] = true
      end
    end
  end
  local result = {}
  for f in pairs(files) do
    table.insert(result, f)
  end
  table.sort(result)
  return result
end

function M.collect_tasks()
  local today = today_str()
  local files = get_org_files()
  local tasks = {}

  for _, filepath in ipairs(files) do
    local lines = vim.fn.readfile(filepath)
    if not lines then goto continue end

    local current_headline = nil
    local current_level = nil
    local current_scheduled = nil
    local current_deadline = nil

    for _, line in ipairs(lines) do
      local stars, text = line:match("^(%*+)%s+(.*)")
      if stars then
        if current_headline and (current_scheduled == today or current_deadline == today) then
          table.insert(tasks, {
            headline = current_headline,
            level = current_level,
            scheduled = current_scheduled,
            deadline = current_deadline,
            file = filepath,
          })
        end
        current_headline = text
        current_level = #stars
        current_scheduled = nil
        current_deadline = nil
      elseif current_headline then
        local sched = line:match("SCHEDULED:%s*<(%d%d%d%d%-%d%d%-%d%d)")
        if sched then
          current_scheduled = sched
        end
        local dead = line:match("DEADLINE:%s*<(%d%d%d%d%-%d%d%-%d%d)")
        if dead then
          current_deadline = dead
        end
      end
    end

    if current_headline and (current_scheduled == today or current_deadline == today) then
      table.insert(tasks, {
        headline = current_headline,
        level = current_level,
        scheduled = current_scheduled,
        deadline = current_deadline,
        file = filepath,
      })
    end
    ::continue::
  end

  return tasks
end

function M.populate_daily_note()
  local tasks = M.collect_tasks()

  local date_str = today_str()
  local daily_dir = "/mnt/shared/Obsidian/ZaWaruto/100 Inbox/Daily Notes"
  local daily_file = daily_dir .. "/" .. date_str .. ".md"

  if vim.fn.filereadable(daily_file) ~= 1 then
    vim.notify("Daily note not found: " .. daily_file, vim.log.levels.WARN)
    return
  end

  local lines = vim.fn.readfile(daily_file)
  if not lines then
    vim.notify("Cannot read daily note", vim.log.levels.ERROR)
    return
  end

  local start_marker = "<!-- tasks-populated:start -->"
  local end_marker = "<!-- tasks-populated:end -->"

  local task_lines = {}
  if #tasks == 0 then
    table.insert(task_lines, start_marker)
    table.insert(task_lines, "<!-- no tasks due today -->")
    table.insert(task_lines, end_marker)
  else
    table.sort(tasks, function(a, b)
      local da = a.deadline or a.scheduled or ""
      local db = b.deadline or b.scheduled or ""
      if da == db then
        return (a.headline or "") < (b.headline or "")
      end
      return da < db
    end)
    table.insert(task_lines, start_marker)
    for _, t in ipairs(tasks) do
      local status = t.headline:match("^DONE%s") or t.headline:match("^CANCELED%s")
      if not status then
        local todo = t.headline:match("^(%u+)%s+")
        local title = todo and t.headline:sub(#todo + 2) or t.headline
        title = title:gsub("%s+$", "")
        local tag_list = title:match("^(.+):([%w_@#]+):$")
        local tag = tag_list and tag_list:match(":(%w[%w_@#]*)$")
        if tag then
          title = tag_list:sub(1, -(#tag + 3))
        end
        local file_short = vim.fn.fnamemodify(t.file, ":t:r")
        local date_info = ""
        if t.deadline == today_str() then
          date_info = " ⚠️ DEADLINE"
        elseif t.scheduled == today_str() then
          date_info = " 📅"
        end
        table.insert(task_lines, "- [ ] " .. title .. date_info .. "  `" .. file_short .. "`")
      end
    end
    table.insert(task_lines, end_marker)
  end

  local start_idx, end_idx = nil, nil
  for i, line in ipairs(lines) do
    if line:match("^" .. vim.pesc(start_marker) .. "$") then
      start_idx = i
    elseif line:match("^" .. vim.pesc(end_marker) .. "$") then
      end_idx = i
      break
    end
  end

  local section_header = "## Tasks Due Today"
  local section_idx = nil
  for i, line in ipairs(lines) do
    if line:match("^## %s*Tasks Due Today%s*$") then
      section_idx = i
      break
    end
  end

  if start_idx and end_idx then
    local before = {}
    for i = 1, start_idx - 1 do table.insert(before, lines[i]) end
    local after = {}
    for i = end_idx + 1, #lines do table.insert(after, lines[i]) end
    lines = before
    for _, l in ipairs(task_lines) do table.insert(lines, l) end
    for _, l in ipairs(after) do table.insert(lines, l) end
  elseif section_idx then
    local before = {}
    for i = 1, section_idx do table.insert(before, lines[i]) end
    local after = {}
    for i = section_idx + 1, #lines do table.insert(after, lines[i]) end
    lines = before
    for _, l in ipairs(task_lines) do table.insert(lines, l) end
    for _, l in ipairs(after) do table.insert(lines, l) end
  else
    table.insert(lines, "")
    table.insert(lines, section_header)
    for _, l in ipairs(task_lines) do table.insert(lines, l) end
  end

  -- Remove trailing blank lines after end marker
  local cleaned = {}
  local after_end = false
  for i, line in ipairs(lines) do
    if after_end then
      if line ~= "" then
        after_end = false
        table.insert(cleaned, line)
      end
    else
      table.insert(cleaned, line)
      if line:match("^" .. vim.pesc(end_marker) .. "$") then
        after_end = true
      end
    end
  end

  vim.fn.writefile(cleaned, daily_file)

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_name(bufnr) == daily_file then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("edit!")
      end)
      break
    end
  end

  local count = #tasks
  vim.notify("Populated " .. count .. " task" .. (count ~= 1 and "s" or "") .. " in daily note", vim.log.levels.INFO)
end

function M.sync_completions()
  local date_str = today_str()
  local daily_dir = "/mnt/shared/Obsidian/ZaWaruto/100 Inbox/Daily Notes"
  local daily_file = daily_dir .. "/" .. date_str .. ".md"

  if vim.fn.filereadable(daily_file) ~= 1 then
    vim.notify("Daily note not found", vim.log.levels.WARN)
    return
  end

  local lines = vim.fn.readfile(daily_file)
  if not lines then return end

  local start_marker = "<!-- tasks-populated:start -->"
  local end_marker = "<!-- tasks-populated:end -->"
  local in_block = false
  local checked_tasks = {}

  for _, line in ipairs(lines) do
    if line:match("^" .. vim.pesc(start_marker) .. "$") then
      in_block = true
    elseif line:match("^" .. vim.pesc(end_marker) .. "$") then
      break
    elseif in_block then
      local title = line:match("^%s*%- %[x%]%s+(.*)")
      if title and not title:match("^<!--") then
        local clean = strip_date_info(title)
        local file_short = title:match("`([^`]+)`$")
        table.insert(checked_tasks, { title = clean, file = file_short })
      end
    end
  end

  if #checked_tasks == 0 then
    vim.notify("No checked tasks to sync", vim.log.levels.INFO)
    return
  end

  local vault = "/mnt/shared/Obsidian/ZaWaruto"
  local synced = 0

  for _, task in ipairs(checked_tasks) do
    local filepath = vault .. "/org/" .. task.file .. ".org"
    local alt_path = vault .. "/Private/200 Tasks/" .. task.file .. ".org"
    local fp = (vim.fn.filereadable(filepath) == 1) and filepath
            or (vim.fn.filereadable(alt_path) == 1) and alt_path
            or nil
    if not fp then
      local found = vim.fn.glob(vault .. "/**/" .. task.file .. ".org", false, true)
      if #found > 0 then fp = found[1] end
    end

    if not fp then
      vim.notify("Can't find org file for: " .. task.file, vim.log.levels.WARN)
      goto next_task
    end

    local org_lines = vim.fn.readfile(fp)
    if not org_lines then goto next_task end

    local search = task.title:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local headline_idx = nil
    local headline_text = nil

    for i, org_line in ipairs(org_lines) do
      local stars, text = org_line:match("^(%*+)%s+(.*)")
      if stars then
        local todo = text:match("^(%u+)%s+")
        local h_title = todo and text:sub(#todo + 2) or text
        h_title = h_title:gsub("%s+$", "")
        local tag_list = h_title:match("^(.+):([%w_@#]+):$")
        local tag = tag_list and tag_list:match(":(%w[%w_@#]*)$")
        if tag then
          h_title = tag_list:sub(1, -(#tag + 3))
        end
        h_title = h_title:gsub("%s+$", "")
        if h_title == task.title then
          headline_idx = i
          headline_text = text
          break
        end
      end
    end

    if not headline_idx then
      vim.notify("Could not find headline: " .. task.title, vim.log.levels.WARN)
      goto next_task
    end

    local new_lines = {}
    local ts = now_ts()
    local inserted_closed = false
    local replaced_closed = false
    for i, org_line in ipairs(org_lines) do
      if i == headline_idx then
        local new_line = org_line:gsub("^(%*+)%s+", "%1 DONE ", 1)
        new_line = new_line:gsub("^(%*+ DONE )TODO ", "%1")
        table.insert(new_lines, new_line)
      elseif i == headline_idx + 1 then
        if org_line:match("^%s*CLOSED:%s*%[") then
          table.insert(new_lines, "  CLOSED: [" .. ts .. "]")
          replaced_closed = true
        else
          table.insert(new_lines, "  CLOSED: [" .. ts .. "]")
          table.insert(new_lines, org_line)
          inserted_closed = true
        end
      else
        table.insert(new_lines, org_line)
      end
    end
    if not inserted_closed and not replaced_closed then
      table.insert(new_lines, "  CLOSED: [" .. ts .. "]")
    end

    vim.fn.writefile(new_lines, fp)

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_name(bufnr) == fp then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("edit!")
        end)
        break
      end
    end

    synced = synced + 1
    ::next_task::
  end

  -- Re-populate to update daily note (checked → unchecked for completed)
  M.populate_daily_note()

  vim.notify("Synced " .. synced .. " task" .. (synced ~= 1 and "s" or "") .. " to org files", vim.log.levels.INFO)
end

local _syncing = false

function M.run_worker(opts)
  if _syncing then
    vim.notify("Sync already in progress", vim.log.levels.WARN)
    return
  end

  opts = opts or {}
  local mode = opts.mode or "sync"
  local filepath = opts.file
  local keyword = opts.keyword
  local line = opts.line

  local labels = {
    sync = "full sync",
    export = "export",
    import = "import",
    export_single = "single file export",
    batch_delete = "batch delete",
  }
  local label = labels[mode] or mode
  vim.notify("🔄 Starting background " .. label .. "...", vim.log.levels.INFO)
  _syncing = true

  local nvim_cmd = vim.v.progpath or "nvim"
  local config_dir = vim.fn.stdpath("config")
  -- kickstart config lives alongside main, detect by plugin location
  local kickstart_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

  local args = { nvim_cmd, "--headless", "-u", "NONE" }
  args[#args+1] = "-c"
  args[#args+1] = "lua _G.SYNC_MODE=[[" .. mode .. "]]"
  if filepath then
    args[#args+1] = "-c"
    args[#args+1] = "lua _G.SYNC_FILE=[[" .. filepath .. "]]"
  end
  if keyword then
    args[#args+1] = "-c"
    args[#args+1] = "lua _G.SYNC_KEYWORD=[[" .. keyword .. "]]"
  end
  if line then
    args[#args+1] = "-c"
    args[#args+1] = "lua _G.SYNC_LINE=" .. tostring(line)
  end
  args[#args+1] = "-c"
  args[#args+1] = "luafile " .. kickstart_dir .. "/lua/custom/gcal_sync_worker.lua"

  local timeout = vim.defer_fn(function()
    if _syncing then
      _syncing = false
      vim.notify("⚠️ " .. label .. " timed out (60s)", vim.log.levels.WARN)
    end
  end, 60000)

  local job_id = vim.fn.jobstart(args, {
    on_stderr = vim.schedule_wrap(function(_, data)
      if data and #data > 0 then
        _G._last_sync_err = table.concat(data, "\n")
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code)
      _syncing = false
      timeout:stop()
      timeout:close()
      if exit_code == 0 then
        vim.notify("✅ " .. label .. " complete!", vim.log.levels.INFO)
        vim.cmd("checktime")
      else
        local err = _G._last_sync_err or ""
        vim.notify("❌ " .. label .. " failed:\n" .. err:sub(1, 200), vim.log.levels.ERROR)
        _G._last_sync_err = nil
      end
    end),
  })

  if job_id <= 0 then
    _syncing = false
    timeout:stop()
    timeout:close()
    vim.notify("❌ Failed to spawn worker", vim.log.levels.ERROR)
  end
end

function M.background_gcal_sync(filepath)
  return M.run_worker({ mode = filepath and "export_single" or "sync", file = filepath })
end

return M
