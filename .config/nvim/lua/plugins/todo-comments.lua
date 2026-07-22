return {
  "folke/todo-comments.nvim",
  event = "BufReadPost",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("todo-comments").setup({
      signs = false,
      highlight = {
        pattern = ".*<(KEYWORDS)\\s*:?",
      },
      search = {
        command = "rg",
        pattern = "\\b(KEYWORDS):?",
      },
    })
  end,
}
