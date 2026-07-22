local data = vim.fn.stdpath("data")
local lazy_dir = data .. "/lazy"
local home = vim.fn.expand("~")
vim.opt.swapfile = false
vim.cmd("set rtp+=" .. home .. "/projects/org-gcal-sync")
vim.cmd("set rtp+=" .. lazy_dir .. "/plenary.nvim")

vim.env.GCAL_ORG_SYNC_CLIENT_ID = os.getenv("GCAL_ORG_SYNC_CLIENT_ID")
vim.env.GCAL_ORG_SYNC_CLIENT_SECRET = os.getenv("GCAL_ORG_SYNC_CLIENT_SECRET")

local vault = "/mnt/shared/Obsidian/ZaWaruto"
require("org-gcal-sync").setup({
  org_dirs = { vault .. "/org", vault .. "/Private/200 Tasks" },
  auto_sync_on_save = false,
  background_sync_interval = 0,
  show_sync_status = false,
  calendars = {
    "primary",
    "444dcb53fe85c6bff902e0ba61de73806133cab53e0a1f4cf54bac29c3060085@group.calendar.google.com",
    "71c5648b3c2c912ed8aed36ab1ae2d4b97523234a95205151d63940aa50d49fc@group.calendar.google.com",
  },
  calendar_import_targets = {
    ["444dcb53fe85c6bff902e0ba61de73806133cab53e0a1f4cf54bac29c3060085@group.calendar.google.com"] = vault .. "/org/tasks_Personal.org",
    ["71c5648b3c2c912ed8aed36ab1ae2d4b97523234a95205151d63940aa50d49fc@group.calendar.google.com"] = vault .. "/org/tasks_Work.org",
  },
  sync_recurring_events = true,
})

local utils = require("org-gcal-sync.utils")
local mode = _G.SYNC_MODE or "sync"

if mode == "export_single" then
  local filepath = _G.SYNC_FILE
  if filepath and filepath ~= "" then
    pcall(utils.export_single_file, filepath)
  end
elseif mode == "import" then
  pcall(utils.import_gcal)
elseif mode == "export" then
  pcall(utils.export_org)
elseif mode == "delete_event" then
  local filepath = _G.SYNC_FILE
  local line = tonumber(_G.SYNC_LINE) or 1
  if filepath and filepath ~= "" and line > 0 then
    pcall(utils.delete_event_by_file, filepath, line)
  end
elseif mode == "batch_delete" then
  pcall(utils.batch_delete_events, {
    keyword = _G.SYNC_KEYWORD,
    file = _G.SYNC_FILE,
  })
else
  pcall(utils.sync)
end

pcall(vim.cmd, "qall!")
