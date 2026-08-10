-- user Neovim config
-- Ported from ~/.vimrc and configured for Obsidian-like Markdown rendering.

-- Vim setting parity from ~/.vimrc
vim.opt.compatible = false
vim.cmd('filetype plugin indent on')
vim.cmd('syntax enable')
vim.opt.hidden = true
vim.opt.number = true
vim.opt.backspace = { 'indent', 'eol', 'start' }

-- Terminal-friendly editing defaults
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.termguicolors = true
vim.g.mapleader = vim.g.mapleader or ' '

-- Window size persistence: prevent auto-equalizing on split/buffer change
vim.opt.equalalways = false
vim.opt.winwidth = 30       -- minimum width for active window
vim.opt.winminwidth = 10    -- minimum width for inactive windows
vim.opt.winheight = 10      -- minimum height for active window
vim.opt.winminheight = 1    -- minimum height for inactive windows

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      local ts = require('nvim-treesitter')
      ts.setup({
        install_dir = vim.fn.stdpath('data') .. '/site',
      })
      ts.install({ 'markdown', 'markdown_inline', 'lua', 'vim', 'vimdoc', 'html', 'yaml' }):wait(300000)
    end,
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    lazy = false,
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons', -- optional icons; harmless if terminal font lacks some glyphs
    },
    opts = {
      enabled = true,
      render_modes = true,
      anti_conceal = {
        enabled = true, -- reveal raw Markdown around the cursor/current edit location
        -- Keep wide tables rendered on the cursor line in normal mode. Otherwise the
        -- active table row falls back to raw Markdown/link text and the columns break.
        disabled_modes = { 'n', 'c' },
        ignore = {
          link = { 'n', 'c' },
          table_border = true,
          virtual_lines = true,
        },
      },
      heading = {
        enabled = true,
        sign = false,
        icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' },
      },
      checkbox = {
        enabled = true,
      },
      bullet = {
        enabled = true,
        icons = { '•', '◦', '▪', '▫' },
      },
      code = {
        enabled = true,
        sign = false,
        style = 'full',
      },
      pipe_table = {
        enabled = true,
        style = 'full',
        cell = 'trimmed',
        border_virtual = true,
      },
      latex = {
        enabled = false,
      },
    },
  },
  {
    'nvim-tree/nvim-tree.lua', -- VS Code-style sidebar file explorer
    lazy = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      view = {
        side = 'left',
        width = 32,
      },
      renderer = {
        group_empty = true, -- collapse single-child folders like VS Code
        highlight_git = 'name', -- git status colors on filenames
        icons = {
          git_placement = 'after',
        },
      },
      update_focused_file = {
        enable = true, -- tree follows/reveals the file you're editing
      },
      git = { enable = true },
      filters = { dotfiles = false },
      actions = {
        open_file = {
          quit_on_open = false, -- keep sidebar open after opening a file
        },
      },
    },
    keys = {
      { '<leader>e', '<cmd>NvimTreeToggle<CR>', desc = 'Toggle file explorer' },
      { '<leader>E', function() require('nvim-tree.api').tree.open({ path = vim.fn.expand('%:p:h'), find_file = true, update_root = true }) end, desc = 'Explorer: reveal current file' },
      { '<leader>ef', function() require('nvim-tree.api').tree.open({ path = vim.fn.expand('%:p:h'), find_file = true, update_root = true }) end, desc = 'Explorer: open tree at current file folder' },
    },
  },
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    lazy = false,
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = 'SecondBrain',
          path = '/Users/Shared/PrivateVault-SecondBrain',
        },
      },
      notes_subdir = '01 Inbox',
      new_notes_location = 'notes_subdir',
    },
  },
}, {
  checker = { enabled = false },
  change_detection = { notify = false },
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'lua', 'vim', 'vimdoc' },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- Markdown buffers should feel like Obsidian: rendered by default, editable in-place.
local function markdown_line_is_pipe_table(lnum)
  local line = vim.fn.getline(lnum)
  if line == '' or not line:match('^%s*|') then
    return false
  end

  local function is_delimiter(candidate)
    return candidate:match('^%s*|[%s%-%:%|]+|%s*$') ~= nil
  end

  return is_delimiter(vim.fn.getline(lnum - 1))
    or is_delimiter(vim.fn.getline(lnum))
    or is_delimiter(vim.fn.getline(lnum + 1))
end

local function markdown_refresh_wrap_for_table()
  if vim.bo.filetype ~= 'markdown' then
    return
  end

  -- render-markdown.nvim tables with concealed links cannot line-wrap cleanly in Neovim
  -- (upstream limitation), so keep prose wrapped but switch to horizontal table view
  -- while the cursor is in a pipe table.
  if markdown_line_is_pipe_table(vim.fn.line('.')) then
    vim.opt_local.wrap = false
    vim.opt_local.linebreak = false
    vim.opt_local.sidescrolloff = 5
    vim.opt_local.concealcursor = 'nvic'
  else
    vim.opt_local.concealcursor = ''
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = '' -- reveal raw markup on the active line/mode
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    markdown_refresh_wrap_for_table()
  end,
})

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufEnter', 'WinEnter' }, {
  pattern = { '*.md', '*.markdown', '*.mdown', '*.mkd' },
  callback = markdown_refresh_wrap_for_table,
})

-- Convenience commands matching the old Vim experiment.
vim.api.nvim_create_user_command('MarkdownRawView', function()
  vim.opt_local.conceallevel = 0
  pcall(function() require('render-markdown').disable() end)
end, {})

vim.api.nvim_create_user_command('MarkdownObsidianView', function()
  vim.opt_local.conceallevel = 2
  vim.opt_local.concealcursor = ''
  pcall(function() require('render-markdown').enable() end)
end, {})

vim.api.nvim_create_user_command('MarkdownViewToggle', function()
  if vim.opt_local.conceallevel:get() == 0 then
    vim.cmd('MarkdownObsidianView')
  else
    vim.cmd('MarkdownRawView')
  end
end, {})

vim.keymap.set('n', '<leader>mv', '<cmd>MarkdownViewToggle<CR>', { desc = 'Toggle Markdown raw/rendered view' })

-- Window resize keymaps (leader + w + hjkl/=/|/_)
vim.keymap.set('n', '<leader>wh', '<C-w><', { desc = 'Decrease window width' })
vim.keymap.set('n', '<leader>wl', '<C-w>>', { desc = 'Increase window width' })
vim.keymap.set('n', '<leader>wj', '<C-w>-', { desc = 'Decrease window height' })
vim.keymap.set('n', '<leader>wk', '<C-w>+', { desc = 'Increase window height' })
vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = 'Equalize all windows' })
vim.keymap.set('n', '<leader>w|', '<C-w>|', { desc = 'Maximize window width' })
vim.keymap.set('n', '<leader>w_', '<C-w>_', { desc = 'Maximize window height' })

-- Lock/unlock current window size (winfixwidth / winfixheight)
vim.keymap.set('n', '<leader>wfw', function()
  vim.wo.winfixwidth = not vim.wo.winfixwidth
  vim.notify('winfixwidth: ' .. (vim.wo.winfixwidth and 'ON' or 'OFF'))
end, { desc = 'Toggle winfixwidth (lock width)' })

vim.keymap.set('n', '<leader>wfh', function()
  vim.wo.winfixheight = not vim.wo.winfixheight
  vim.notify('winfixheight: ' .. (vim.wo.winfixheight and 'ON' or 'OFF'))
end, { desc = 'Toggle winfixheight (lock height)' })

vim.keymap.set('n', '<leader>wfa', function()
  vim.wo.winfixwidth = not vim.wo.winfixwidth
  vim.wo.winfixheight = not vim.wo.winfixheight
  vim.notify('winfixwidth/height: ' .. (vim.wo.winfixwidth and 'ON' or 'OFF'))
end, { desc = 'Toggle both winfixwidth & winfixheight' })

-- Copy the current buffer's absolute path to the macOS pasteboard.
vim.keymap.set('n', 'yp', function()
  local path = vim.fn.expand('%:p')
  if path == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', path)
  vim.fn.setreg('*', path)
  vim.notify('Copied file path: ' .. path)
end, { desc = 'Copy current file path to macOS clipboard' })

-- Session management for layout persistence across restarts
local session_file = vim.fn.stdpath('data') .. '/session.vim'

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    vim.cmd('mksession! ' .. vim.fn.fnameescape(session_file))
  end,
})

vim.api.nvim_create_autocmd('VimEnter', {
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then
      vim.cmd('source ' .. vim.fn.fnameescape(session_file))
    end
  end,
})

-- Manual session commands
vim.api.nvim_create_user_command('SessionSave', function()
  vim.cmd('mksession! ' .. vim.fn.fnameescape(session_file))
  vim.notify('Session saved')
end, {})

vim.api.nvim_create_user_command('SessionLoad', function()
  if vim.fn.filereadable(session_file) == 1 then
    vim.cmd('source ' .. vim.fn.fnameescape(session_file))
    vim.notify('Session loaded')
  else
    vim.notify('No session file found', vim.log.levels.WARN)
  end
end, {})

vim.api.nvim_create_user_command('SessionDelete', function()
  if vim.fn.delete(session_file) == 0 then
    vim.notify('Session deleted')
  else
    vim.notify('No session file to delete', vim.log.levels.WARN)
  end
end, {})

vim.keymap.set('n', '<leader>ws', '<cmd>SessionSave<CR>', { desc = 'Save session' })
vim.keymap.set('n', '<leader>wr', '<cmd>SessionLoad<CR>', { desc = 'Load session (restore)' })
vim.keymap.set('n', '<leader>wd', '<cmd>SessionDelete<CR>', { desc = 'Delete session' })

