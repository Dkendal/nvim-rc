# Nvim-RC

Direnv-like lua rc file loading for Neovim.

Loads `.nvimrc.lua` files in the current directory and all parent directories.

If you're familiar with direnv, it works in a very similar manner by only loading trusted files that have been approved by the user.

## Usage

Create a `.nvimrc.lua` file in your project directory (or any parent directory).
When you open Neovim or change directories, you'll receive a warning that the rc file is not allowed.
Run `:RcAllow` to allow the file to be loaded.

## Commands

### `:RcAllow`

Allow a `.nvimrc.lua` file to be sourced, this will save the checksum of the file to a file in the allow directory.
If there are multiple files that are not yet approved you will be prompted to select one.
Immediately sources the file after approval.

### `:RcRevoke`

Revoke a previous authorization.
Prompts for selection if multiple rc files exist.

### `:RcEdit`

Open a rc file.
Prompts for selection if multiple rc files exist.

### `:RcReload`

Reload all rc files.

## Installation

```lua
vim.cmd.packadd 'nvim-rc'
```

Or use your favorite plugin manager.

No other configuration is required.
