local M = {}

function M.archive_all_done()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local ranges = {}
  for i = 0, #lines - 1 do
    local line = lines[i + 1]
    local todo_match = line:match("^(%*+)%s+DONE%s") or line:match("^(%*+)%s+CANCELED%s")
    if todo_match then
      local level = #todo_match
      local end_idx = #lines - 1
      for j = i + 1, #lines - 1 do
        local nl = lines[j + 1]
        if nl:match("^%*+%s") then
          local nlvl = #(nl:match("^(%*+)"))
          if nlvl <= level then
            end_idx = j - 1
            break
          end
        end
      end
      table.insert(ranges, { start = i, ["end"] = end_idx, level = level })
    end
  end

  local final = {}
  for _, r in ipairs(ranges) do
    local covered = false
    for _, f in ipairs(final) do
      if r.start >= f.start and r["end"] <= f["end"] then
        covered = true
        break
      end
    end
    if not covered then
      table.insert(final, r)
    end
  end

  if #final == 0 then
    vim.notify("No DONE/CANCELED headlines to archive", vim.log.levels.INFO)
    return
  end

  local archive_path = filepath .. "_archive"
  local archive_lines = {}
  for _, r in ipairs(final) do
    if #archive_lines > 0 then
      table.insert(archive_lines, "")
    end
    for l = r.start, r["end"] do
      table.insert(archive_lines, lines[l + 1])
    end
  end

  local existing = {}
  if vim.fn.filereadable(archive_path) == 1 then
    existing = vim.fn.readfile(archive_path)
  end

  local out = {}
  for _, l in ipairs(existing) do
    table.insert(out, l)
  end
  if #existing > 0 and existing[#existing] ~= "" then
    table.insert(out, "")
  end
  for _, l in ipairs(archive_lines) do
    table.insert(out, l)
  end
  vim.fn.writefile(out, archive_path)

  table.sort(final, function(a, b) return a.start > b.start end)
  for _, r in ipairs(final) do
    vim.api.nvim_buf_set_lines(bufnr, r.start, r["end"] + 1, false, {})
  end
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("write")
  end)

  vim.cmd("edit!")

  vim.notify(string.format("Archived %d headline(s) to %s", #final, vim.fn.fnamemodify(archive_path, ":t")), vim.log.levels.INFO)
end

return M
