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

Lua:
```lua
local traveller = require('nvim-traveller')

vim.keymap.set('n', '<leader>o', traveller.open_navigation, {})
```

Viml:
```viml
nnoremap <leader>o <cmd>lua require('nvim-traveller').open_navigation()<cr>
```
