return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Oil",
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    view_options = {
      show_hidden = true,
    },
    lsp_file_methods = { enabled = true, timeout_ms = 1000, autosave_changes = true },
    columns = { "icon" },
    float = { max_width = 0.3, max_height = 0.6, border = "rounded" },
    keymaps = {
      ["<C-h>"] = false,
      ["<M-h>"] = "actions.select_split",
    },
  },
  keys = {
    { "<leader>e", "<cmd>Oil<CR>", desc = "Oil file explorer" },
    {
      "<leader>fe",
      function() require("oil").open() end,
      desc = "Oil (root dir)",
    },
    {
      "<leader>fE",
      function() require("oil").open(vim.fn.expand("%:p:h")) end,
      desc = "Oil (current dir)",
    },
  },
}
