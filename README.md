# nvim-traveller
A file manager inside Neovim. take a look at github.com/norlock/nvim-traveller-buffers for a good
complementary plugin for buffers

### What makes this file manager different than others?

I want to put the emphasis on multi-project use, having a polished experience inside Neovim. Take a
look at the showcase to see how it can enhance your workflow for multi-project use. 
The idea is that you don't have to open new terminals and navigate to the desired locations only to open up another instance of Neovim. 

If for instance you are creating a frontend application and want to see what kind of parameters your
request needs to have. You can navigate inside Neovim quickly and open the backend project. You
share the buffers so yanking / pasting is very convenient. It also makes sure cwd is always correct
so your plugins will work.

If for example you need to tail some log file of your backend you can open a real terminal (or
terminal tab) from inside Neovim at the correct location.

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
- [x] Show last visited directories
- [x] Opening terminal at desired location
- [x] Change cwd to git root if possible (optional)
- [x] Change cwd to traveller (optional)
- [x] Navigate to home directory with a hotkey
- [x] Being able to select items
- [x] Being able to delete selected items (using git rm if possible)
- [x] Being able to move / copy selected items
  - [ ] Use git mv if possible
- [x] Project buffers (see nvim-traveller-buffers)
- [x] Selection feedback window in the bottom
- [x] Resize windows if needed
- [x] Help menu in popup
- [ ] Custom keymapping
- [x] Docs
- [x] Open binaries with open
- [ ] Optional: FZF/(Other fuzzy file searcher)  if there is demand for it
- [ ] Optional: being able to pass stringed cmds "test file.lua"
- [ ] Optional: Support for Windows (if there is demand for it)
- [ ] Optional: Custom directory for telescope global search

## Showcase

https://github.com/Norlock/nvim-traveller/assets/7510943/ccaa83ce-593c-4dde-8bb6-a0b612a67d4b

## Startup

Install using packer:
```lua
use 'nvim-lua/plenary.nvim',
use 'nvim-telescope/telescope.nvim', tag = '0.1.2',
use 'norlock/nvim-traveller',
```

Install using vim-plug:
```viml
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.2' } 
Plug 'norlock/nvim-traveller'
```

## Requires
- Telescope plugin
- fd - https://github.com/sharkdp/fd 

## Usage

Lua:
```lua
local traveller = require('nvim-traveller').setup({
    show_hidden = false,
    mappings = {
        -- directories overview
        directories_tab = "<Tab>",
        directories_delete = "<C-d>"
    }
})

vim.keymap.set('n', '-', traveller.open_navigation, {})
-- Opens quick directory search (Tab to display all directories)
vim.keymap.set('n', '<leader>d', traveller.last_directories_search, {})
vim.keymap.set('n', '<leader>o', traveller.open_terminal, {})

Viml:
```viml
nnoremap - <cmd>lua require('nvim-traveller').open_navigation()<cr>
nnoremap <leader>d <cmd>lua require('nvim-traveller').last_directories_search()<cr>
nnoremap <leader>o <cmd>lua require('nvim-traveller').open_terminal()<cr>
```

- When navigation is openend press ? for more info
