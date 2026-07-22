return {
  "rcarriga/nvim-notify",
  event = "VeryLazy",
  config = function()
    local notify = require("notify")
    notify.setup({
      top_down = false,
      max_width = 50,
      render = "minimal",
      stages = "static",
    })
    vim.notify = notify
  end,
}
