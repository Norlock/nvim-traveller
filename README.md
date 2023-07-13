# nvim-traveller
A file manager inside Neovim. I used dirvish mostly for navigating files, but
had problems with quickly cancelling navigation or I couldn't open files in tab. Most other navigators are either bloated or don't provide the necessary tools for your project

## Features
- [x] Fast navigation through directories
- [x] Open files in buffer/tab/split/vsplit
- [x] Open a terminal tab into the navigated directory 
- [x] Create files or directories
- [x] Delete directories or files
- [x] Easily to cancel navigation
- [x] Move / rename a file or directory
- [x] Follows symlinks

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

