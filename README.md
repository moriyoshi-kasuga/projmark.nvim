# projmark.nvim

Project-scoped marks for Neovim.

`a-z` marks are stored per project root and persisted to disk, while uppercase marks and special marks keep default Vim behavior.

## Installation

lazy.nvim:

```lua
{
  "moriyoshi-kasuga/projmark.nvim",
  opts = {}
}
```

## Configuration

Default options:

```lua
require("projmark").setup({
  data_file = vim.fn.stdpath("data") .. "/projmark.json",
  project_root_order = { "git", "lsp" },
})
```

## Usage

- `ma`: set project mark `a`
- `'a`: jump to project mark `a`
- `dma`: delete project mark `a`

## Project root detection

Resolved in `project_root_order` priority:

1. Git root (`.git`)
2. LSP `root_dir`
