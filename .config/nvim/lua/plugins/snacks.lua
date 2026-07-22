return {
  "folke/snacks.nvim",
  lazy = false,
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.hidden = true

    opts.image = opts.image or {}
    opts.image.resolve = function(file, src)
      local vault = "/mnt/shared/Obsidian/ZaWaruto"
      local candidates = {
        vim.fs.joinpath(vault, "zawaruto-assets/attachments", src),
        vim.fs.joinpath(vault, src),
        vim.fs.joinpath(vim.fs.dirname(file), src),
      }
      for _, c in ipairs(candidates) do
        if vim.fn.filereadable(c) == 1 then
          return c
        end
      end
    end

    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}

    local header_lines = {
      "██████╗  █████╗ ██╗██████╗ ██╗   ██╗    ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗",
      "██╔══██╗██╔══██╗██║██╔══██╗╚██╗ ██╔╝    ██║  ██║██╔══██╗██║     ██║     ██╔════╝",
      "██████╔╝███████║██║██████╔╝ ╚████╔╝     ███████║███████║██║     ██║     ███████╗",
      "██╔══██╗██╔══██║██║██╔══██╗  ╚██╔╝      ██╔══██║██╔══██║██║     ██║     ╚════██║",
      "██████╔╝██║  ██║██║██║  ██║   ██║       ██║  ██║██║  ██║███████╗███████╗███████║",
      "╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝",
      " ",
      " ",
    }

    local function hex_to_rgb(hex)
      hex = hex:gsub("#", "")
      return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end

    local function blend(hex1, hex2, ratio)
      local r1, g1, b1 = hex_to_rgb(hex1)
      local r2, g2, b2 = hex_to_rgb(hex2)
      return string.format(
        "#%02x%02x%02x",
        math.floor(r1 + (r2 - r1) * ratio + 0.5),
        math.floor(g1 + (g2 - g1) * ratio + 0.5),
        math.floor(b1 + (b2 - b1) * ratio + 0.5)
      )
    end

    local function theme_color(hl_group, fallback)
      local hl = vim.api.nvim_get_hl(0, { name = hl_group, link = false })
      if hl and hl.fg then
        return string.format("#%06x", hl.fg)
      end
      return fallback
    end

    local snacks_dashboard = require("snacks").dashboard
    snacks_dashboard.sections.header = function()
      return function(_self)
        local start_color = theme_color("@keyword", "#a6d18a")
        local end_color = "#ffffff"
        local line_count = #header_lines
        for i = 1, line_count do
          local ratio = (i - 1) / math.max(line_count - 1, 1)
          vim.api.nvim_set_hl(0, "DashboardGradient" .. i, { fg = blend(start_color, end_color, ratio) })
        end
        local items = {}
        for i, line in ipairs(header_lines) do
          items[i] = { text = { { line, hl = "DashboardGradient" .. i } }, align = "center" }
        end
        return items
      end
    end

    opts.dashboard.sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }

    return opts
  end,
  -- stylua: ignore
  keys = {
    -- Top Pickers & Explorer
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
    -- git
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Git Log Line" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
    { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git Log File" },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
    -- search
    { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
    { "<leader>s/", function() Snacks.picker.search_history() end, desc = "Search History" },
    { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
    { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
    { "<leader>si", function() Snacks.picker.icons() end, desc = "Icons" },
    { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
    { "<leader>sp", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
    { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undotree" },
    { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
    -- LSP
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
    { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
    { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
    { "gai", function() Snacks.picker.lsp_incoming_calls() end, desc = "C[a]lls Incoming" },
    { "gao", function() Snacks.picker.lsp_outgoing_calls() end, desc = "C[a]lls Outgoing" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
  },
}
