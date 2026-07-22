return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  keys = {
    { "<leader>mf", "<cmd>Obsidian quick_switch<CR>", desc = "Find notes" },
    { "<leader>ms", "<cmd>Obsidian search<CR>", desc = "Search note contents" },
    { "<leader>mo", "<cmd>Obsidian open<CR>", desc = "Open note in Obsidian" },
    { "<leader>mO", "<cmd>Obsidian follow_link<CR>", desc = "Open [[link]] at point" },
    { "<leader>mn", "<cmd>Obsidian new<CR>", desc = "New note" },
    { "<leader>mN", "<cmd>Obsidian new_from_template<CR>", desc = "New note from template" },
    { "<leader>mt", "<cmd>Obsidian today<CR>", desc = "Today's daily" },
    { "<leader>my", "<cmd>Obsidian yesterday<CR>", desc = "Yesterday's daily" },
    { "<leader>mM", "<cmd>Obsidian tomorrow<CR>", desc = "Tomorrow's daily" },
    { "<leader>md", "<cmd>Obsidian dailies<CR>", desc = "Browse dailies" },
    { "<leader>mD", function()
      local picked = require("custom.date-picker").pick()
      if picked then
        local path = string.format("/mnt/shared/Obsidian/ZaWaruto/100 Inbox/Daily Notes/%04d-%02d-%02d.md", picked.year, picked.month, picked.day)
        vim.cmd("edit " .. path)
      end
    end, desc = "Open daily note for date" },
    { "<leader>mb", "<cmd>Obsidian backlinks<CR>", desc = "Backlinks" },
    { "<leader>mL", "<cmd>Obsidian links<CR>", desc = "Outgoing links" },
    { "<leader>mp", "<cmd>Obsidian paste_img<CR>", desc = "Paste image" },
    { "<leader>mT", "<cmd>Obsidian template<CR>", desc = "Insert template" },
    { "<leader>ml", "<cmd>Obsidian link<CR>", desc = "Insert [[link]]" },
    { "<leader>mr", "<cmd>Obsidian rename<CR>", desc = "Rename note" },
    { "<leader>me", "<cmd>Obsidian extract_note<CR>", desc = "Extract selection to new note" },
    { "<leader>mx", "<cmd>Obsidian toggle_checkbox<CR>", desc = "Toggle checkbox" },
    { "<leader>mc", "<cmd>Obsidian check<CR>", desc = "Check checkbox" },
    { "<leader>mg", "<cmd>Obsidian tags<CR>", desc = "Browse tags" },
    { "<leader>mk", "<cmd>Obsidian bookmarks<CR>", desc = "Browse bookmarks" },
    { "<leader>mC", "<cmd>Obsidian toc<CR>", desc = "Table of contents" },
    { "<leader>mF", "<cmd>Obsidian footnotes<CR>", desc = "Footnotes" },
    { "<leader>mu", "<cmd>Obsidian unique_note<CR>", desc = "Unique note" },
    { "<leader>mw", "<cmd>Obsidian workspace<CR>", desc = "Workspace" },
    { "<leader>mh", "<cmd>Obsidian help<CR>", desc = "Help" },
    { "<leader>mH", "<cmd>Obsidian helpgrep<CR>", desc = "Help grep" },
    { "<leader>mz", "<cmd>Obsidian sync<CR>", desc = "Sync notes" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "ZaWaruto",
        path = "/mnt/shared/Obsidian/ZaWaruto",
      },
    },
    daily_notes = {
      folder = "100 Inbox/Daily Notes",
      date_format = "%Y-%m-%d",
    },
    templates = {
      folder = "_templates",
      date_format = "%Y-%m-%d",
    },
    attachments = {
      folder = "zawaruto-assets/attachments",
    },
    completion = {
      min_chars = 2,
    },
    picker = {
      name = "snacks.picker",
    },
    ui = {
      enable = false,
    },
    checkbox = {
      order = { " ", "-", "x" },
    },
    note_id_func = function(title)
      return require("obsidian.builtin").title_id(title)
    end,
    callbacks = {},
  },
}
