return {
  "L3MON4D3/LuaSnip",
  dependencies = { "rafamadriz/friendly-snippets" },
  build = (not vim.fn.has("win32")) and "make install_jsregexp" or nil,
  event = "InsertEnter",
  opts = { history = true, updateevents = "TextChanged,TextChangedI" },
  config = function(_, opts)
    require("luasnip").config.set_config(opts)
    require("luasnip.loaders.from_vscode").lazy_load()
    vim.keymap.set({ "i", "s" }, "<C-e>", function() require("luasnip").expand_or_jump(1) end, { silent = true })
    vim.keymap.set({ "i", "s" }, "<C-J>", function() require("luasnip").jump(1) end, { silent = true })
    vim.keymap.set({ "i", "s" }, "<C-K>", function() require("luasnip").jump(-1) end, { silent = true })
  end,
}
