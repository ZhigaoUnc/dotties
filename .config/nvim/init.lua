
vim.cmd([[set mouse=]])
vim.cmd([[set noswapfile]])
vim.cmd([[hi @lsp.type.number gui=bold]])
vim.opt.winborder = "rounded"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.showtabline = 1
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.cursorcolumn = false
vim.opt.ignorecase = true
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.undofile = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.g.have_nerd_font = true
vim.g.mapleader = " "

-- lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "kanagawa" } },
  checker = { enabled = true },
})

-- ── Keymaps ──────────────────────────────────────────────────
local map = vim.keymap.set

-- session (global, named)
local session_dir = vim.fn.stdpath("data") .. "/sessions"
vim.fn.mkdir(session_dir, "p")

local function session_path(name)
  return session_dir .. "/" .. name:gsub("/", "_") .. ".vim"
end

local function session_list()
  local sessions = {}
  for f in vim.fs.dir(session_dir) do
    if f:match("%.vim$") then
      table.insert(sessions, f:gsub("%.vim$", ""))
    end
  end
  table.sort(sessions)
  return sessions
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

map("n", "<leader>ss", function()
  vim.ui.input({ prompt = "Session name: " }, function(name)
    if not name or name == "" then return end
    vim.cmd("mksession! " .. vim.fn.fnameescape(session_path(name)))
    notify("Session saved: " .. name)
  end)
end, { desc = "Save session" })

map("n", "<leader>sl", function()
  local sessions = session_list()
  if #sessions == 0 then
    notify("No saved sessions", vim.log.levels.WARN)
    return
  end
  vim.ui.select(sessions, { prompt = "Load session:" }, function(choice)
    if not choice then return end
    vim.cmd.source(vim.fn.fnameescape(session_path(choice)))
    notify("Session loaded: " .. choice)
  end)
end, { desc = "Load session" })

map("n", "<leader>sd", function()
  local sessions = session_list()
  if #sessions == 0 then
    notify("No saved sessions", vim.log.levels.WARN)
    return
  end
  vim.ui.select(sessions, { prompt = "Delete session:" }, function(choice)
    if not choice then return end
    vim.fn.delete(session_path(choice))
    notify("Session deleted: " .. choice)
  end)
end, { desc = "Delete session" })

-- lsp autocompletion
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("my.lsp", {}),
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    if client:supports_method("textDocument/completion") then
      local chars = {}
      for i = 32, 126 do table.insert(chars, string.char(i)) end
      client.server_capabilities.completionProvider.triggerCharacters = chars
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})

vim.cmd([[set completeopt+=menuone,noselect,popup]])

vim.lsp.enable({
  "lua_ls","tinymist","pyright",
})

-- tsx/jsx filetype
vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = "*.jsx,*.tsx",
  group = vim.api.nvim_create_augroup("TS", { clear = true }),
  callback = function() vim.cmd([[set filetype=typescriptreact]]) end,
})

local function open_current_html()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Preview requires a saved HTML file", vim.log.levels.ERROR)
    return
  end
  vim.cmd.update()
  vim.system({ "xdg-open", path })
end

local function preview_current_file()
  local ft = vim.bo.filetype
  if ft == "typst" then
    vim.cmd.TypstPreview()
  elseif ft == "html" then
    open_current_html()
  else
    vim.notify("No preview action for: " .. ft, vim.log.levels.WARN)
  end
end

local ls = function() return require("luasnip") end

map({ "n", "v" }, "y", '"+y', { desc = "Yank to system clipboard" })
map("n", "Y", '"+Y', { desc = "Yank line to system clipboard" })
map({ "i", "s" }, "<C-e>", function() ls().expand_or_jump(1) end, { silent = true })
map({ "i", "s" }, "<C-J>", function() ls().jump(1) end, { silent = true })
map({ "i", "s" }, "<C-K>", function() ls().jump(-1) end, { silent = true })
map({ "n", "t" }, "<Leader>t", "<Cmd>botright split<CR> <Cmd>term<CR>i")
map({ "n", "t" }, "<Leader>x", "<Cmd>tabclose<CR>")


vim.cmd([[
  nnoremap g= g+|
  nnoremap gK @='ddkPJ'<cr>
  xnoremap gK <esc><cmd>keeppatterns '<,'>-global/$/normal! ddpkJ<cr>
  noremap! <c-r><c-d> <c-r>=strftime('%F')<cr>
  noremap! <c-r><c-t> <c-r>=strftime('%T')<cr>
  noremap! <c-r><c-f> <c-r>=expand('%:t')<cr>
  noremap! <c-r><c-p> <c-r>=expand('%:p')<cr>
  xnoremap <expr> . "<esc><cmd>'<,'>normal! ".v:count1.'.<cr>'
]])

for i = 1, 8 do
  map({ "n", "t" }, "<Leader>" .. i, "<Cmd>tabnext " .. i .. "<CR>")
end

local opts = { noremap = true, silent = true }
map("n", "yag", ":%y<CR>", opts)
map("n", "vag", "ggVG", opts)
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)
map("n", "<ESC>", ":nohlsearch<CR>", opts)
map("n", "gl", "$", { desc = "Jump: End of line" })

map({ "n", "v", "x" }, "<leader>r", ":edit!<CR>", { desc = "Reload current file" })
map({ "n", "v", "x" }, "<leader>v", "<Cmd>edit $MYVIMRC<CR>", { desc = "Edit init.lua" })
map({ "n", "v", "x" }, "<leader>n", ":norm ", { desc = "Enter norm command" })
map({ "n", "v", "x" }, "<leader>O", "<Cmd>restart<CR>", { desc = "Restart Neovim" })
map({ "n", "v", "x" }, "<C-s>", [[:s/\V]], { desc = "Substitute in selection" })
map({ "n", "v", "x" }, "<leader>i", [[<Cmd>tabedit .gitignore<CR>]], { desc = "Edit .gitignore" })
map({ "n", "v", "x" }, "<leader>lf", vim.lsp.buf.format, { desc = "Format current buffer" })
map("n", "<leader>p", preview_current_file, { desc = "Preview current file" })
map("n", "<leader>gx", function() vim.ui.open(vim.fn.expand("%")) end, { desc = "Open file in default app" })
map("n", "<M-n>", "<cmd>resize +2<CR>")
map("n", "<M-e>", "<cmd>resize -2<CR>")
map("n", "<M-i>", "<cmd>vertical resize +5<CR>")
map("n", "<M-m>", "<cmd>vertical resize -5<CR>")
map("n", "<leader>c", "1z=", { desc = "Fix spelling" })
map("n", "<C-q>", ":copen<CR>", { silent = true })
map("n", "<leader>w", "<Cmd>update<CR>", { desc = "Write buffer" })
map("n", "<leader>q", "<Cmd>:quit<CR>", { desc = "Quit buffer" })
map("n", "<leader>Q", "<Cmd>:wqa<CR>", { desc = "Quit all and write" })
map("n", "<leader>a", ":edit #<CR>", { desc = "Alternate buffer" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- ── Orgmode ───────────────────────────────────────────────────
map("n", "<leader>of", function()
  require("snacks").picker.files({ cwd = "/mnt/shared/Obsidian/ZaWaruto", ft = "org" })
end, { desc = "Find org files" })
map("n", "<leader>os", function()
  require("snacks").picker.grep({ cwd = "/mnt/shared/Obsidian/ZaWaruto", glob = "*.org" })
end, { desc = "Search org file contents" })
map("n", "<leader>oz", function()
  require("custom.org-archive").archive_all_done()
end, { desc = "Archive all DONE headlines" })

-- ── GCal ──────────────────────────────────────────────────────
local worker = require("custom.org-tasks-to-daily")
map("n", "<leader>ogs", function()
  worker.run_worker({ mode = "sync" })
end, { desc = "Sync org ↔ GCal (background)" })
map("n", "<leader>ogi", function()
  worker.run_worker({ mode = "import" })
end, { desc = "Import GCal → org" })
map("n", "<leader>oge", function()
  worker.run_worker({ mode = "export" })
end, { desc = "Export org → GCal" })
map("n", "<leader>ogD", function()
  local filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  worker.run_worker({ mode = "delete_event", file = filepath, line = cursor_line })
end, { desc = "Delete GCal event for headline" })
map("n", "<leader>ogB", function()
  local filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local confirm = vim.fn.confirm("Delete ALL GCal events in this file?", "&Yes\n&No", 2)
  if confirm == 1 then
    worker.run_worker({ mode = "batch_delete", file = filepath })
  end
end, { desc = "Batch delete all GCal events in file" })

-- ── Insert / Tasks ────────────────────────────────────────────
map("n", "<leader>ir", function()
  require("custom.org-tasks-to-daily").populate_daily_note()
end, { desc = "Insert today's org tasks into daily note" })
map("n", "<leader>is", function()
  require("custom.org-tasks-to-daily").sync_completions()
end, { desc = "Sync completed tasks to org files" })
