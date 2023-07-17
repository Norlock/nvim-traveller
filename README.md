# nvim-traveller
A file manager inside Neovim. I used dirvish mostly for navigating files, but
had problems with quickly cancelling navigation or I couldn't open files in tab. Most other navigators are either bloated or don't provide the necessary tools for my needs.

What makes this file manager different than others?

I want to put the emphasis on having a polished experience, and make it a file
manager good for multi-project use, that means:

- Tries to avoid difficult key combinations as much as possible
- Very quickly toggle help menu with: ?
- Being able to use fuzzy file search or use other plugins at location
- Good integration with terminal
- Git commands if possible
- Change cwd to git root cleanly

https://github.com/Norlock/nvim-traveller/assets/7510943/44c0982d-0cb9-479f-823e-7ef574a215ab

## Features
- [x] Fast navigation through directories
- [x] Open files in buffer/tab/split/vsplit
- [x] Open a terminal tab into the navigated directory 
- [x] Create files or directories
- [x] Delete directories or files
- [x] Easy to cancel navigation or commands
- [x] Move / rename a file or directory
- [x] Follows symlinks
- [x] Toggle hidden files
- [x] Use git rm if possible
- [x] Use git mv if possible
- [x] Telescope integration in directory
- [x] Change cd to git root if possible
- [x] Navigate to home directory hotkey
- [ ] Resize windows if needed
- [ ] Help menu in popup
- [ ] Docs
- [ ] FZF/(Other fuzzy file searcher)  if there is demand for it
- [ ] Being able to pass stringed cmds "test file.lua"
- [ ] Support for Windows (if there is demand for it)

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

vim.keymap.set('n', '<leader>o', traveller.open_navigation, {})
```

Viml:
```viml
nnoremap <leader>o <cmd>lua require('nvim-traveller').open_navigation()<cr>
```

- When navigation is openend press ? for more info
