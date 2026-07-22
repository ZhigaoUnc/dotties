return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = "markdown",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    preset = "obsidian",
    render_modes = { "n" },
    heading = {
      enabled = true,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      signs = { "󰫎 " },
      position = "overlay",
      width = "block",
    },
    bullet = {
      enabled = true,
      icons = { "•", "◦", "▪", "▫" },
    },
    checkbox = {
      enabled = true,
      unchecked = { icon = "󰄱 " },
      checked = { icon = " " },
      custom = {
        todo = { raw = "[-]", rendered = "⬛ ", highlight = "RenderMarkdownTodo" },
      },
    },
    anti_conceal = { enabled = false },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    local function blend(fg, bg, alpha)
      local fr, fg_, fb = tonumber(fg:sub(1, 2), 16), tonumber(fg:sub(3, 4), 16), tonumber(fg:sub(5, 6), 16)
      local br, bg_, bb = tonumber(bg:sub(1, 2), 16), tonumber(bg:sub(3, 4), 16), tonumber(bg:sub(5, 6), 16)
      local r = math.floor(fr * alpha + br * (1 - alpha))
      local g = math.floor(fg_ * alpha + bg_ * (1 - alpha))
      local b = math.floor(fb * alpha + bb * (1 - alpha))
      return string.format("#%02x%02x%02x", r, g, b)
    end
    local function apply_heading_colors()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local bg_hex = normal.bg and string.format("#%06x", normal.bg)
      if not bg_hex then return end

      local fgs = {}
      for i = 1, 6 do
        local hl = vim.api.nvim_get_hl(0, { name = "@markup.heading." .. i .. ".markdown", link = false })
        local fg = hl and hl.fg
        if not fg then
          hl = vim.api.nvim_get_hl(0, { name = "@markup.heading." .. i, link = false })
          fg = hl and hl.fg
        end
        fgs[i] = fg
      end

      local distinct = true
      for i = 2, 6 do
        if not fgs[i] or (fgs[i - 1] and fgs[i] == fgs[i - 1]) then
          distinct = false
          break
        end
      end

      if not distinct then
        local base_fg = fgs[1] or normal.fg or 0xcccccc
        local r = math.floor(base_fg / 65536) % 256
        local g = math.floor(base_fg / 256) % 256
        local b = base_fg % 256

        local rn, gn, bn = r / 255, g / 255, b / 255
        local cx = math.max(rn, gn, bn)
        local cn = math.min(rn, gn, bn)
        local delta = cx - cn
        local h = 0
        if delta > 0 then
          if cx == rn then
            h = 60 * (((gn - bn) / delta) % 6)
          elseif cx == gn then
            h = 60 * (((bn - rn) / delta) + 2)
          else
            h = 60 * (((rn - gn) / delta) + 4)
          end
        end
        local s = cx > 0 and (delta / cx) or 0
        local v = cx

        for i = 1, 6 do
          local hi = (h + (i - 1) * 30) % 360
          local hi_i = math.floor(hi / 60)
          local f = (hi / 60) - hi_i
          local p = v * (1 - s)
          local q = v * (1 - f * s)
          local t = v * (1 - (1 - f) * s)
          local rc, gc, bc
          if hi_i == 0 then rc, gc, bc = v, t, p
          elseif hi_i == 1 then rc, gc, bc = q, v, p
          elseif hi_i == 2 then rc, gc, bc = p, v, t
          elseif hi_i == 3 then rc, gc, bc = p, q, v
          elseif hi_i == 4 then rc, gc, bc = t, p, v
          else rc, gc, bc = v, p, q
          end
          local fg_hex = string.format("#%02x%02x%02x", math.floor(rc * 255), math.floor(gc * 255), math.floor(bc * 255))
          vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i, { fg = fg_hex })
          vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = blend(fg_hex:sub(2), bg_hex:sub(2), 0.12) })
          vim.api.nvim_set_hl(0, "@markup.heading." .. i .. ".markdown", { fg = fg_hex })
        end
      else
        for i = 1, 6 do
          local fg_hex = string.format("#%06x", fgs[i])
          vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i, { fg = fg_hex })
          vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = blend(fg_hex:sub(2), bg_hex:sub(2), 0.12) })
          vim.api.nvim_set_hl(0, "@markup.heading." .. i .. ".markdown", { fg = fg_hex })
        end
      end
    end
    apply_heading_colors()
    vim.api.nvim_set_hl(0, "RenderMarkdownDash", { link = "Comment" })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("RenderMarkdownTheme", { clear = true }),
      callback = apply_heading_colors,
    })
  end,
}
