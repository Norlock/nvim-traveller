# nvim-traveller
A file manager inside Neovim. 

### What makes this file manager different than others?

I want to put the emphasis on multi-project use, having a polished experience. I use it as a plugin
that inverts my workflow. I open Neovim first, travel to directories and open files or terminals at the
desired location. 

https://github.com/Norlock/nvim-traveller/assets/7510943/44c0982d-0cb9-479f-823e-7ef574a215ab

## Features
- [x] Fast navigation through directories
- [x] Open files in buffer/tab/split/vsplit
- [x] Open a Neovim terminal tab with the navigated directory 
- [x] Open a real terminal with the navigated directory 
- [x] Create files or directories with one command
- [x] Delete directories or files
- [x] Easy to cancel navigation or commands
- [x] Move or rename an item
- [x] Follows symlinks
- [x] Toggle hidden files
- [x] Use git rm if possible
- [x] Use git mv if possible
- [x] Telescope integration with directories
- [x] Opening terminal at desired location
- [x] Change cwd to git root if possible (optional)
- [x] Change cwd to traveller (optional)
- [x] Navigate to home directory with a hotkey
- [x] Being able to select items
- [x] Selection feedback window in the bottom
- [x] Resize windows if needed
  - [ ] Create min width / min height
- [x] Help menu in popup
- [ ] Custom keymapping
- [ ] Custom directory for telescope global search
- [x] Docs
- [ ] Open binaries with open
- [ ] Optional: FZF/(Other fuzzy file searcher)  if there is demand for it
- [ ] Optional: being able to pass stringed cmds "test file.lua"
- [ ] Optional: Support for Windows (if there is demand for it)

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
-- sync_cwd flag is useful for plugin compatibility if you work with multiple projects
traveller.setup({ replace_netrw = true, sync_cwd = true })

vim.keymap.set('n', '-', traveller.open_navigation, {})

-- Really fast navigation through directories with traveller compatibility
vim.keymap.set('n', '<leader>d', traveller.open_telescope_search, silent_options) 
```

Viml:
```viml
nnoremap - <cmd>lua require('nvim-traveller').open_navigation()<cr>
nnoremap <leader>d <cmd>lua require('nvim-traveller').open_telescope_search()<cr>
```

- When navigation is openend press ? for more info
