" For testing, matchit plugin
" not very useful for python as this is primarily only for parenthesis w
let g:loaded_matchit = 1

"::::==-- BASIC  --==:::: {{{
"mappings "
let mapleader = "\<Space>"
" let localmapleader = ","
let maplocalleader = ","

" disable legacy VI mode
" default install of VIM are in legacy mode
set nocompatible

" change to current file directory
" set autochdir
""" this is not good since yo uare not longer able to change directory in CTRLP

""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- PLUGIN --==:::: {{{
" VUNDLE | VIM Plugins 

" vim setting to run Vundle"
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

"-- NerdTree
Plugin 'scrooloose/nerdtree'
"" open a NERDTree automatically when Vim Starts
"autocmd vimenter * NERDTree
"" open NERDTree if no file is specified
"autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
"map <silent> <leader><C-n> :NERDTreeFind<cr>
"map <silent> <leader>t :NERDTreeToggle<cr>

"-our CTRL+P
Plugin 'ctrlpvim/ctrlp.vim'
" include hidden files in search
let g:ctrlp_show_hidden = 1
" Persist cache between sessions
let g:ctrlp_clear_cache_on_exit = 0
let g:ctrlp_use_caching = 1

" disable local working directory path
let g:ctrlp_working_path_mode = 0

"let g:ctrlp_mruf_exclude = '/tmp/.*\|/temp/.*|\.ipynb$' " MacOSX/Linux
"let g:ctrlp_mruf_include = '\.py$\|\.txt$'
" added to test ginore files
"let g:ctrlp_custom_ignore = {
"  \ 'dir':  '\.git$\|\.yardoc\|public$|log\|tmp$',
"  \ 'file': '\.so$\|\.dat$|\.DS_Store$|\.ipynb$,\.swo$'
"  \ }

" Autocompletion, disabled 11June2021 in favor of kite
" Plugin 'davidhalter/jedi-vim'
" " Make jedi run faster
" let g:jedi#show_call_signatures = "0"  
" let g:jedi#popup_on_dot = 0



"-- Vim.WIki
Plugin 'vimwiki/vimwiki'
let g:vimwiki_list = [{'path': '~/vimwiki/',
                      \ 'syntax': 'markdown', 'ext': '.md'}]

" Real-time markdown preview
" Plugin 'iamcco/markdown-preview.vim'




"-- YouCompleteMe
"Plugin 'Valloric/YouCompleteMe'

" molokai color scheme
Plugin 'tomasr/molokai'

 " Solorized
Plugin 'altercation/vim-colors-solarized'

" vim-tmux navigator
Plugin 'christoomey/vim-tmux-navigator'
let g:tmux_navigator_disable_when_zoomed = 1

" Seiya - Make vim Transparent 
Plugin 'miyakogi/seiya.vim'
" make vim transparent every start.
let g:seiya_auto_enable=1

" Close buffer
Plugin 'rbgrouleff/bclose.vim'

" Vim airline for status/tabline
" airline is 100%vim script, no python needed
" powerline requires python
Plugin 'bling/vim-airline'
" Below is optional only, for theme
Plugin 'vim-airline/vim-airline-themes'
let g:airline_theme='powerlineish'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 1
let g:airline#extensions#tabline#show_close_button = 1
let g:airline_powerline_fonts = 1
" for tmuxline + vim-airline integration
let g:airline#extensions#tmuxline#enabled = 1
" start tmuxline even without vim running
let airline#extensions#tmuxline#snapshot_file = "~/.tmux-status.conf"

" tmux+vim share powerline status
Plugin 'edkolev/tmuxline.vim'

" zshrc vim mode, test only
"Plugin 'file:///home/user/.vim/bundle/vi-mode'

" Surround.vim to quickly/better wrapping in VIM
Plugin 'tpope/vim-surround'

" Helps repeat the surround tag
Plugin 'tpope/vim-repeat'


" Vim Python Syntax Highlighter, added #Mar2020
Plugin 'vim-python/python-syntax'
let g:python_highlight_all = 1
let g:python_slow_sync = 1

    
" Python VIM Folding, added #Mar2020
" NOTE: THEI IS NOTE WORKING, CAN BE REMOVED!
" note Used really, can be disabled"
Plugin 'tmhedberg/SimpylFold'
let g:SimpylFold_docstring_preview = 1

" Autcloser for VIM python
Plugin 'Raimondi/delimitMate'
            
" FZF for VIm
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'
imap <c-x><c-f> <plug>(fzf-complete-path)

" Autoscroll Vim
" Plugin 'vim-scripts/autoscroll.vim' "Disregarded since not useful
map <F6> <C-E>:sleep 3000m<CR>j<F6>
map <F7> <C-Y>:sleep 3000m<CR>k<F7>


" Jupyter Mode in Vim
" kPlugin 'jupyter-vim/jupyter-vim'
" klet g:vim_virtualenv_path = '/home/user/.pyenv/versions/anaconda3-5.1.0'
" k" let g:vim_virtualenv_path = '/home/user/py-env/cong'
" kif exists('g:vim_virtualenv_path')
" k    pythonx import os; import vim
" k    " pythonx activate_this = os.path.join(vim.eval('g:vim_virtualenv_path'), 'bin/activate_this.py')
" k    pythonx activate_this = os.path.join(vim.eval('g:vim_virtualenv_path'), 'bin/activate')
" k    pythonx with open(activate_this) as f: exec(f.read(), {'__file__': activate_this})
" kendif
" k" let g:python3_host_prog ='/home/user/.pyenv/versions/anaconda3-5.1.0/bin/python3.6'

" ---- INSTALLED VIRTUAL ENV"
" Always use the same virtualenv for vim, regardless of what Python
" environment is loaded in the shell from which vim is launched
" let g:python3_host_prog ='/home/user/.pyenv/versions/anaconda3-5.1.0/bin/python3.6'
"let g:vim_virtualenv_path = '/home/user/.pyenv/versions/anaconda3-5.1.0'
"" let g:vim_virtualenv_path = '/home/user/py-env/jupy-vim'
"if exists('g:vim_virtualenv_path')
"    pythonx import os; import vim
"    pythonx activate_this = os.path.join(vim.eval('g:vim_virtualenv_path'), 'bin/activate')
"    pythonx with open(activate_this) as f: exec(f.read(), {'__file__': activate_this})
"endif
"let g:jupyter_mapkeys = 0

" Always use the same virtualenv for vim, regardless of what Python
" environment is loaded in the shell from which vim is launched

"" disabled for now
""let g:vim_virtualenv_path = '/home/user/py-env/project'
"let g:vim_virtualenv_path = '/home/user/.pyenv/versions/anaconda3-5.1.0/envs/conda2021'
"" let g:vim_virtualenv_path = '/home/user/py-env/jupy-vim'
""let g:vim_virtualenv_path = '/usr/bin/anaconda3'
"if exists('g:vim_virtualenv_path')
"    pythonx import os; import vim
"    pythonx activate_this = os.path.join(vim.eval('g:vim_virtualenv_path'), 'bin/activate_this.py')
"    pythonx with open(activate_this) as f: exec(f.read(), {'__file__': activate_this})
"endif


" minimap for code
"Plugin 'wfxr/minimap.vim'
Plugin 'severin-lemaignan/vim-minimap'


" Add icons in NerdTree
Plugin 'ryanoasis/vim-devicons'

" Indent lines
" Only useful currently for spaces and NOT tabs
" color needs to be modified 
Plugin 'Yggdroot/indentLine'
" let g:indentLine_char = 1
" let g:indentLine_setColors = 0
" let g:indentLine_color_term = 239


" FOR testing, navigation on blocks
Plugin 'andymass/vim-matchup'

" ----------------------------------------------------------
" vim in db — DB plugin plugins kept, legacy contents removed (load from
" untracked local config, e.g. ~/.vim/local config, if needed)
Plugin 'tpope/legacy-db'


" DB plugin ui
Plugin 'kristijanhusak/legacy-db-ui'
" legacy block removed — was legacy content — now untracked
let g:db_ui_use_nerd_fonts=1
let g:db_ui_show_database_icon=1 
" let g:db_ui_show_database_icon=1 

" plugin mapping
nmap <Leader>u <Plug>(UI_DeleteLine)


" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
" for autocomplete
" not fully working
Plugin 'kristijanhusak/legacy-db-completion'

" possible this is no longer relevant
Plugin 'vim-scripts/legacy-ext.vim'

" For built in omnifunc
autocmd FileType sql setlocal omnifunc=legacy_db_completion#omni

" Source is automatically added, you just need to include it in the chain complete list
let g:completion_chain_complete_list = {
    \   'sql': [
    \    {'complete_items': ['legacy-db-completion']},
    \   ],
    \ }
" Make sure `substring` is part of this list. Other items are optional for this completion source
let g:completion_matching_strategy_list = ['exact', 'substring']
" Useful if there's a lot of camel case items
let g:completion_matching_ignore_case = 1
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

" Asynchonouse Syntax Chcker
" Plugin 'w0rp/ale'  "disabled since I did not find this useful

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required, equivalent below
"filetype on
"filetype plugin on
"filetype indent on
" To ignore plugin indent changes, instead use:
"filetype plugin on


" VUNDLE  Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" setting for vim-dev icons setting"
set guifont=Hack\ Nerd\ Font\ Mono:h13
set encoding=utf-8


" GUI
set guioptions-=m  "remove menu bar
set guioptions-=T  "remove toolbar

" MacVim (GUI) doesn't inherit shell PATH — add Homebrew manually
if has('gui_running')
    let $PATH = '/opt/homebrew/bin:/opt/homebrew/sbin:' . $PATH
endif

" Minimap
let g:minimap_auto_start=1

" ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' ' '
" Preview current Markdown file using glow
if has('gui_running')
    command! MarkdownPreview call term_start(['/opt/homebrew/bin/glow', expand('%:p')], {'term_rows': 20})
else
    command! MarkdownPreview execute '!glow ' . shellescape(expand('%')) | redraw!
endif
nnoremap <leader>mp :MarkdownPreview<CR>


""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- VISUALS --==:::: {{{

" set the theme to murhpy
" applies to gVim only
" let g:solarized_termcolors=256
" let g:solarized_termtrans=1
" set background=light
" colorscheme solarized
" color molokai

if has('gui_running')
    "    set background=light
    "    colorscheme solarized
    color molokai
else
    color molokai
endif

augroup VisualHighlight
    autocmd!
    autocmd VimEnter,ColorScheme * hi Visual ctermbg=238 ctermfg=255 cterm=NONE
augroup END
" font family to Lucide console, for gvim only
" set guifont=Lucida_Console

" Enable syntax highlighting
syntax on
" set vimrc syntax highlighting
" THIS IS NOT WORKING, so can be deleted, added Mar2020
""""""""
"augroup fvimrc
"  au!
"  autocmd BufNewFile,BufRead .vimrc set syntax=vim
"augroup END

" Sets the color of matchin parenthesis
hi MatchParen ctermfg=34 ctermbg=238 cterm=bold
" Color for matching brackets
" set showmatch
" set matchtime=10


" Show number lines
set nu

" Set number width to 2 (in number lines)
set numberwidth=2

" show relative number on the gutter
"   for easier navigation
set relativenumber

" highlight linec containing the cursor
" set cursorline
augroup cursorline
    autocmd!
    autocmd WinLeave,BufLeave * set nocursorline
    autocmd WinEnter,BufEnter * set cursorline
augroup end



""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Navigation --==:::: {{{ 
" Make backspace work like most apps
" Set unrestricted backspacing in insert mode
" Value   Effect
"   0     same as ":set backspace="
"   1     same as ":set backspace=indent,eol"
"   2     same as ":set backspace=indent,eol,start"
set backspace=2

" <c-h> is interpreted as <bs> in neovim
" This is a bandaid fix until the team decides how
" they want to handle fixing it...(https://github.com/neovim/neovim/issues/2048)
nnoremap <silent> <bs> :TmuxNavigateLeft<cr>

" Allow navigation to automatically go to next line
" h,l VIM navs and <> Keyboard Arrow keys, [] Arrow keys 'value' in Insert Mode
set whichwrap+=h,l,<,>,[,]

""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Mappings --==:::: {{{

 " Navigate properly when lines are wrapped
nnoremap j gj
nnoremap k gk

" Maps the double semicolon to escape key
" keeps the fingers in home keys
" imap ;; <Esc>

" UNMAP KEYS <F2><F3><F4><F5><F6><F7><F8><F9><F12>

" Map newline key within Normal Mode
" Cursor stays in line
" ### this is not disabled due to conflict with VimWiki
" nmap <S-Enter> O<Esc>
" # Cursor goes with new line
" nmap <Enter> o<Esc> 

" Map Leader key to spacebar
"



" NERDtree mapping, to go to file location
nnoremap <leader><c-o> :NERDTreeFind<cr>

" Command for quick directory change
" remap <leader>cd :cd %:p:h<CR>:pwd<CR>
command! CDC lcd %:p:h
" ! character override

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" " Run current file
" nnoremap <Leader>r :JupyterRunFile<CR>
" " nnoremap <buffer> <silent> <localleader>I :PythonImportThisFile<CR>
" 
" " Change to directory of current file
" nnoremap <buffer> <silent> <localleader>d :JupyterCd %:p:h<CR>
" 
" " Send a selection of lines
" nnoremap <Leader>e :JupyterSendCell<CR>
" " nnoremap <buffer> <silent> <localleader>E :JupyterSendRange<CR>
" nmap     <buffer> <localleader>E <Plug>JupyterRunTextObj
" nmap     <buffer> <silent> <localleader>e <Plug>JupyterRunTextObj
" vmap     <buffer> <silent> <localleader>e <Plug>JupyterRunVisual
" 
" nnoremap <buffer> <silent> <localleader>U :JupyterUpdateShell<CR>
" 
" " Debugging maps
" nnoremap <buffer> <silent> <localleader>b :PythonSetBreak<CR>

""""""""""""""""""""

" temujim Custom Mapping
" -----------------------

" " Run Current file (this is still buggy)
" nnoremap <buffer> <localleader>R :JupyterRunFile<CR> 
" 
" " Change to directory of current file (still buggy)
" nnoremap <buffer> <silent> <localleader>d :JupyterCd %:p:h<CR>
" 
" " Run current line
" " nnoremap <buffer> <Leader>e :JupyterSendRange<CR>
" nnoremap <Leader>e :JupyterSendRange<CR>
" 
" " Run cell
" nnoremap <Leader>E :JupyterSendCell<CR>
" " nnoremap <buffer> <Leader>E :JupyterSendCell<CR>
" 
" " Run file navigate
" nmap     <buffer> <silent> <localleader>e <Plug>JupyterRunTextObj
" 
" " Run Highlighted file
" " vmap     <buffer> <silent> <localleader>e <Plug>JupyterRunVisual
" vmap <Leader>e <Plug>JupyterRunVisual "updated for simplicity
" updated for simplicity
" " vmap <localleader>e <Plug>JupyterRunVisual
" 
" 
" " Defaults which might be usefl 
" nnoremap <buffer> <silent> <localleader>U :JupyterUpdateShell<CR>
" 
" " Debugging maps
" nnoremap <buffer> <silent> <localleader>b :PythonSetBreak<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""



" quicker global copy-pasting to Vim to windows
" global registers requires gVim, vim-gtk
nnoremap <Leader>y "+y
nnoremap <Leader>p "+p
vnoremap <Leader>y "+y

" Open last Buffer
nnoremap <Leader><Leader> <C-^>
" go to next buffer
nnoremap <Leader>b :bprev<CR>
" go to previous buffer
nnoremap <Leader>f :bnext<CR>
" close buffer
nnoremap <Leader>c :Bclose<CR>
"quit buffer
nnoremap <Leader>q :quit<CR>    
"save file
nnoremap <Leader>w :write<CR>   
"save and exit
nnoremap <Leader>x :xit<CR>     

" SURROUND.VIM MAPPING
" Wrap with  `
" THIS IS NOT WORKING
" Probably because of the <leader> ' is current bookmark?
nnoremap <Leader>` ysiw`
" Wrap with " 
nnoremap <Leader>" ysiw"


" Split navigation, pane nav shortcuts
"#Taken care by vim-tmux navigator plugin now
" nnoremap <silent> <C-j> <C-w>j
" nnoremap <silent> <C-k> <C-w>k
" nnoremap <silent> <C-h> <C-w>h
" nnoremap <silent> <C-l> <C-w>l

" SPlit pane nav on visual mode
xnoremap <C-j> <C-w>j
xnoremap <C-k> <C-w>k
xnoremap <C-h> <C-w>h
xnoremap <C-l> <C-w>l

" Global yank of file to register
noremap <silent> <F4> :let @+=expand("%:p")<CR>
" https://stackoverflow.com/questions/916875/yank-file-name-path-of-current-buffer-in-vim

" auto-closing brackets for python
" source: https://stackoverflow.com/questions/21316727/automatic-closing-brackets-for-vim
" did use these mapping since delimitate extension was used 
" inoremap " ""<left>
" inoremap ' ''<left>
" inoremap ( ()<left>
" inoremap [ []<left>
" inoremap { {}<left>
" inoremap {<CR> {<CR>}<ESC>O
" inoremap {;<CR> {<CR>};<ESC>O


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Run python code directly, added Mar2020
"autocmd FileType python map <buffer> <F9> :w<CR>:exec '!python3' shellescape(@%, 1)<CR>
"autocmd FileType python imap <buffer> <F9> <esc>:w<CR>:exec '!python3' shellescape(@%, 1)<CR>

"autocmd Filetype python nnoremap <buffer> <F5> :w<CR>:ter python2 "%"<CR>
"autocmd Filetype python nnoremap <buffer> <F6> :w<CR>:vert ter python3 "%"<CR>
autocmd Filetype python nnoremap <buffer> <F8> :w<CR>:ter python3 "%"<CR>

"map <F8> :w<CR>:!python %<CR>


""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Autocompletion --==:::: {{{

" enable wildcard for autocompletion
" enables the menu of wildecard at the bottom
set wildmenu
" shows a list autocomplete items in list
" first tab matches the longest
" second tab shows the list
" 3rd tab cycles through the items
set wildmode=longest:list,full

" Exclude files in wildmode
set wildignore+=*.a,*.o
set wildignore+=*.bmp,*.gif,*.ico,*.jpg,*.png,*.exe,*.pdf,*.zip,*.djvu,*.xls,*.xlsx,*.doc,*.docx,*.mp3,*.ipynb,*.bak,*.bz2,*.mp4,*.pptx
set wildignore+=.DS_Store,.git,.hg,.svn
set wildignore+=*~,*.swp,*.tmp,*.swo
set wildignore+=*.vim/view  "just added Apr2020 to test the vimview excludsion, and it worked

" mouse testing
" Currently now working in terminal vim
set mouse=a
" enable drag events for terminal 
set ttymouse=sgr


" Kite Autocompletion settings
" This is not working as of now!!!!
" Keys are still set to default C-N and C-P
" let g:kite_previous_placeholder = '<C-k>'
" let g:kite_next_placeholder = '<C-j>'
" let g:kite_previous_placeholder='<C-K>'
" let g:kite_next_placeholder='<C-J>'






""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Split --==:::: {{{

" set splitbelow is enough even without condition
" if condition is copied from Greg Hurrel (FB dev)
if has('windows')
  set splitbelow                      " open horizontal splits below current window
endif

if has('vertsplit')
  set splitright                      " open vertical splits to the right of the current winow
endif

" Revert session withi zooming 
" source: https://vi.stackexchange.com/questions/241/undo-only-window 
nnoremap <C-w>o :mksession! ~/session.vim<CR>:wincmd o<CR>
nnoremap <C-w>u :source ~/session.vim<CR>
 
""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Tab and AutoIndent  --==:::: {{{

set expandtab   " use spaces instead of tabs
" uses the "shiftwidth" setting for inserting <TAB>
" this is because some files will have shiftwidth=8
set smarttab

" four-space tab indent
set tabstop=4
"1 tab = 4 spaces
" sets the > and < command to 3 width
set shiftwidth=4
" due to "expandtab" which uses spaces of tabs
" treats the 4 spaces as one character, so easier
" backspace or deletion of characters
set softtabstop=4

" set autoindent
" autoindent means the enter key (Carriage Return) 
" will drop right below the previous line.
set ai  "autoindent

" sets the separator vertical split
" other options: ║   │     █ ▓
set fillchars+=vert:p,fold:-,stl:=
" set fillchars+=vert:█,fold:-,stl:=
set fillchars+=vert:║,fold:-,stl:=
hi clear VertSplit   " make border color white


""""""""""""""""""""""""""""""""""""""""""""""}}}

"::::==-- Folds  --==:::: {{{
" :mkview saves the folds
" :loadview loads the folds for the file
"augroup AutoSaveFolds
"  autocmd!
  autocmd BufWinLeave *.* mkview
  autocmd BufWinEnter *.* silent loadview
"augroup END

set foldmethod=marker
"set foldmethod=manual
"set foldmethod=indent
 
"""""""""""""""""""""""""""""""""""""""""""""}}}

":::==-- VIM Scripts --==::: {{{

" increment/decrement
set nrformats+=alpha "include alphabets increment/decrement

"""""""""""""""""""""""""""""""""
" Script to insert multiple lines
"""""""""""""""""""""""""""""""""
" Other options of installing:
" Create file 
"    -  ~/.vim/plugin/insertmultiple.vim (Unix) 
"    -  $HOME/vimfiles/plugin/insertmultiple.vim (Windows) containing the script below, then restart Vim. 
" Alternatively, add the script to your vimrc and restart Vim.

" Open multiple lines (insert empty lines) before or after current line,
" and position cursor in the new space, with at least one blank line
" before and after the cursor.
function! OpenLines(nrlines, dir)
  let nrlines = a:nrlines < 3 ? 3 : a:nrlines
  let start = line('.') + a:dir
  call append(start, repeat([''], nrlines))
  if a:dir < 0
    normal! 2k
  else
    normal! 2j
  endif
endfunction
" Mappings to open multiple lines and enter insert mode.
nnoremap <Leader>o :<C-u>call OpenLines(v:count, 0)<CR>S
nnoremap <Leader>O :<C-u>call OpenLines(v:count, -1)<CR>S

"""""""""""""""
" XML folding, if file is XML, foldmethod is set to "indent"
augroup XML
    autocmd!
    autocmd FileType xml setlocal foldmethod=indent foldlevelstart=999 foldminlines=0
augroup END
" https://stackoverflow.com/questions/32154285/folding-expanding-and-colapsing-xml-tags-in-vim-xml-parsing




"""""""""""""""""""""""""""""""""""""""""""""}}}

":::==-- Load WebDevicons --==::: {{{
" if exists("g:loaded_webdevicons")
"   call webdevicons#refresh()
" endif

"""""""""""""""""""""""""""""""""""""""""""""}}}

