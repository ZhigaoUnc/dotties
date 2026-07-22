return {
  "ZeGentlemen/org-gcal-sync",
  ft = "org",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-orgmode/orgmode",
  },
  keys = {
    { "<leader>oga", "<cmd>OrgGcalAuth<CR>", desc = "GCal auth" },
    { "<leader>ogd", "<cmd>OrgGcalDashboard<CR>", desc = "GCal sync dashboard" },
    { "<leader>ogl", "<cmd>OrgGcalListCalendars<CR>", desc = "List GCal calendars" },
    { "<leader>ogK", "<cmd>OrgGcalStripIds<CR>", desc = "Strip GCAL_IDs" },
  },
  config = function()
    local client_id = os.getenv("GCAL_ORG_SYNC_CLIENT_ID")
    local client_secret = os.getenv("GCAL_ORG_SYNC_CLIENT_SECRET")
    if not client_id or not client_secret then
      vim.notify("org-gcal-sync: Set GCAL_ORG_SYNC_CLIENT_ID and GCAL_ORG_SYNC_CLIENT_SECRET env vars", vim.log.levels.ERROR)
    end
    vim.env.GCAL_ORG_SYNC_CLIENT_ID = client_id
    vim.env.GCAL_ORG_SYNC_CLIENT_SECRET = client_secret

    local vault = "/mnt/shared/Obsidian/ZaWaruto"
    require("org-gcal-sync").setup({
      org_dirs = {
        vault .. "/org",
        vault .. "/Private/200 Tasks",
      },
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

    local auto_sync_timer = nil
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.org",
      callback = function()
        local filepath = vim.fn.expand("%:p")
        if auto_sync_timer then
          auto_sync_timer:stop()
          auto_sync_timer:close()
        end
        auto_sync_timer = vim.defer_fn(function()
          auto_sync_timer = nil
          require("custom.org-tasks-to-daily").run_worker({ mode = "export_single", file = filepath })
        end, 500)
      end,
      desc = "Auto-sync org file to GCal on save via worker",
    })

    local sync_interval = 15 * 60 * 1000
    local sync_timer = vim.uv.new_timer()
    sync_timer:start(sync_interval, sync_interval, vim.schedule_wrap(function()
      local has_org = false
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_name(bufnr):match("%.org$") then
          has_org = true
          break
        end
      end
      if has_org then
        require("custom.org-tasks-to-daily").run_worker({ mode = "sync" })
      end
    end))

    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        sync_timer:stop()
        sync_timer:close()
      end,
    })
  end,
}
