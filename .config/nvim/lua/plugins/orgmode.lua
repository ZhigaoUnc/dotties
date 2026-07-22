return {
  "nvim-orgmode/orgmode",
  event = "VeryLazy",
  ft = "org",
  config = function()
    local vault = "/mnt/shared/Obsidian/ZaWaruto"

    require("orgmode").setup({
      org_agenda_files = {
        vault .. "/org/**/*",
        vault .. "/Private/200 Tasks/**/*",
      },
      org_default_notes_file = vault .. "/org/refile.org",
      mappings = {
        prefix = "<leader>o",
      },
      org_hide_emphasis_markers = true,
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function()
        vim.opt_local.conceallevel = 2
        vim.opt_local.concealcursor = "nc"
      end,
    })
  end,
}
