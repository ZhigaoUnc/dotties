return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "julianolf/nvim-dap-lldb",
    "nvim-neotest/nvim-nio",
  },
  keys = {
    { "<leader>d", ":DapNew<CR>", desc = "DAP new" },
    { "<C-b>", ":DapToggleBreakpoint<CR>", desc = "Toggle breakpoint" },
  },
  config = function()
    local dap, dapui = require("dap"), require("dapui")

    require("dap-lldb").setup()
    require("dapui").setup()
    require("nvim-dap-virtual-text").setup()

    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
  end,
}
