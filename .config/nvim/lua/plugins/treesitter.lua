return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
  config = function()
    local parsers = {
      "bash", "c", "cpp", "css", "diff", "glsl", "html", "javascript",
      "json", "lua", "luadoc", "markdown", "markdown_inline", "python",
      "query", "regex", "rust", "svelte", "toml", "tsx", "typescript",
      "vim", "vimdoc", "xml", "yaml", "zig",
    }

    local installed = require("nvim-treesitter").get_installed()
    local to_install = vim.tbl_filter(function(lang)
      return not vim.tbl_contains(installed, lang)
    end, parsers)
    if #to_install > 0 then
      require("nvim-treesitter").install(to_install)
    end

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if lang and vim.treesitter.language.add(lang) then
          pcall(vim.treesitter.start, args.buf)
        end
      end,
    })
  end,
}
