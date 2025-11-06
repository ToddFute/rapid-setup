set clipboard=unnamed

execute pathogen#infect()


" Stole lots of this from https://dougblack.io/words/a-good-vimrc.html
" TAB: Not sure I like folding, use <space> to turn it on or off :-)

" Leader shortcuts {{{
"
let mapleader=","       " leader is comma
" }}}

" Colors {{{
colorscheme badwolf         " awesome colorscheme
if !exists("g:syntax_on")
    syntax enable           " enable syntax processing
endif
" }}}

" TAB: Trying this
let mysyntaxfile = "~/.vim/syntax/txt.vim"
syntax on

" Spaces and Tabs {{{
set tabstop=4       " number of visual spaces per TAB
set softtabstop=4   " number of spaces in tab when editing
set expandtab       " tabs are spaces
set autoindent
" }}}

" UI Config {{{
filetype plugin indent on
"filetype indent on
                        " load filetype-specific indent files
                        " e.g. python settings at ~/.vim/indent/python.vim
set wildmenu            " visual autocomplete for command menu
set lazyredraw          " redraw only when we need to.
" }}}

" Searching {{{
set incsearch           " search as characters are entered
set hlsearch            " highlight matches
" turn off search highlight
nnoremap <leader><space> :nohlsearch<CR>
" }}}

" Folding {{{
set foldenable          " enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max
set foldmethod=indent   " fold based on indent level
                        " Could be marker, manual, expr, syntax, diff.
                        " Run :help foldmethod to find out what each of those do.
" space open/closes folds
nnoremap <space> za
" }}}

" Movement {{{
" highlight last inserted text
nnoremap gV `[v`]
" }}}

" Backups  {{{
set backup
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set backupskip=/tmp/*,/private/tmp/*
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set writebackup
" }}}

" Tools {{{
" toggle gundo
nnoremap <leader>u :GundoToggle<CR>

" open ag.vim
nnoremap <leader>a :Ag

" CtrlP settings
let g:ctrlp_match_window = 'bottom,order:ttb'
let g:ctrlp_switch_buffer = 0
let g:ctrlp_working_path_mode = 0
let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
" }}}


set modelines=1

" vim:foldmethod=marker:foldlevel=0

" Shibumi Daily Startup
"let @t = ':set noaii=strftime("%Y%m%d")_Daily.txt*CAB/Gorn---------- ---------- ---------- ---------- ----------CAB:Exceptions:---DevOps Standup:Opu:    xScott:    yMatt:    zTodd:    Who is oncall    Daily - ---:set ai1Gy$:w ~/Notes/=strftime("%Y%m%d")_Daily.txt'
" SimpleRose Daily Startup (Today)
let @t = ':set noai1Gi=strftime("%Y%m%d")_Daily.txt:r~/bin/SimpleRose/daily.txt/include yesterday.sh Top!!yesterday.sh -i 0 Top/include yesterday.sh Carl!!yesterday.sh -i 4 Carl/include yesterday.sh Summary!!yesterday.sh Summary/include yesterday.sh Current!!yesterday.sh Current -exclude_file ~/bin/SimpleRose/daily.txt:set ai1Gy$:w ~/Notes/=strftime("%Y%m%d")_Daily.txt1G/*Todd: '

" Insert timestamp
" WAS let @s = '!!date +\%H:\%M'
let @s = 'o!!date +\%H:\%M0D?*ToddiTS=pa lr='

" Mark non-personal todo's as forwarded to the next day
let @d = ':1,$s/*Todd:/>Todd:/g:1,$s/>Todd: Personal/*Todd: Personal/g'

" Pull past 2 week's personal work to today
let @p = '!!yesterday.sh -14 Personal'

" Format CAB messages
let @f = ':1,$s/\t/\r    //zzz'

" Take a screenshot of a fixed area and save it to ~/Notes with a date-stamp
let @h = '!!take_screenshot.sh'

set spelllang=en
set spellfile=$HOME/usr/lib/spellfile.en.utf-8.add

let &t_SI = "\<Esc>]50;CursorShape=1\x7"
let &t_SR = "\<Esc>]50;CursorShape=2\x7"
let &t_EI = "\<Esc>]50;CursorShape=0\x7"

:autocmd InsertEnter * set cul
:autocmd InsertLeave * set nocul

nmap <F3> i<C-R>=strftime("%I:%M")<CR><Esc>
imap <F3> <C-R>=strftime("%I:%M")<CR>
