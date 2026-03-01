-- setting this env will override all XDG paths
vim.env.LAZY_STDPATH = ".tests"
-- this will install lazy in your stdpath
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()
local dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
require("lazy.minit").repro({
  spec = {
    {
      name = "projmark",
      dir = dir,
      config = function()
        require("projmark").setup({
          data_file = dir .. "/cache.projmark.json",
        })
      end,
      lazy = false,
    },
  },
})
