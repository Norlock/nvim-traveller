# nvim-traveller
File manager inside Neovim

## Startup

Install using packer:
```lua
use {
  'norlock/nvim-traveller',
  requires = { {'nvim-lua/plenary.nvim'} }
}
```

Install using vim-plug:
```viml
Plug 'nvim-lua/plenary.nvim'
Plug 'norlock/nvim-traveller'
```

## Usage

lua:
```lua
local file_manager = require('nvim-traveller')

vim.keymap.set('n', '<leader>o', file_manager.open_navigation, {})
```
