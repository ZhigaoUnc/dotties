return {
  "rebelot/kanagawa.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("kanagawa").setup({
      background = {
        dark = "dragon",
      },
      colors = {
        theme = {
          all = {
            ui = {
              bg_gutter = "none",
            },
          },
        },
      },
      transparent = true,
    })
    vim.cmd.colorscheme("kanagawa")
  end,
}
