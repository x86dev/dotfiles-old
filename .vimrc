" To convert line endings between Windows and Linux, use fileformat (ff):
" set ff=unix
" set ff=dos
"
" Nice plugins:
" - c.vim: http://www.vim.org/scripts/script.php?script_id=213
" ==============================================================================

" Deactivate compatibility mode with original Vi.
set nocompatible

if version < 700
    echo "ERROR: Wrong VIM version! At least 7.00 is required. Exit.\n"
    quit!
endif

" Activate pathogen. This enables using vim plugins pretty easily.
" See https://github.com/tpope/vim-pathogen
call pathogen#infect()
if has('autocmd')
  filetype plugin indent on
endif

set ttyfast     " We have a fast tty. Does smoother screen updates.

highlight Folded ctermfg=yellow ctermbg=none cterm=bold
highlight LineNr ctermfg=red ctermbg=none
highlight ExtraWhitespace ctermbg=darkgreen guibg=darkgreen      

" Make color schemes work with putty also.
if has("terminfo")
    let &t_Co=16
    let &t_AB="\<Esc>[%?%p1%{8}%<%t%p1%{40}%+%e%p1%{92}%+%;%dm"
    let &t_AF="\<Esc>[%?%p1%{8}%<%t%p1%{30}%+%e%p1%{82}%+%;%dm"
 else
    let &t_Co=16
    let &t_Sf="\<Esc>[3%dm"
    let &t_Sb="\<Esc>[4%dm"
endif

set shiftwidth=4
set softtabstop=4
set tabstop=4
set shiftwidth=4
set number
set ignorecase
set smartcase
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Support all three, in this order.
set fileformats=unix,dos,mac

" Allow mouse in (n)ormal, (v)isual and (i)nsert mode.
set mouse=nvi

" Make autoindent happen.
set autoindent

" Set search highlight.
set hlsearch

" Decent backspace.
set backspace=indent,eol,start

set visualbell                 " Error bells are visually.

" GUI
set guioptions-=m              " Don't show the menu.
set guioptions-=T              " Don't show the toolbar.

" Backup
set nobackup                   " Do not backup!
set noautowrite                " Never write a file automatically!
set noautowriteall             " Nope!
set writebackup                " Backup original file when writing.
set backupext=~                " Backup extension is "~"

" Ruler 
set ruler
set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%)

" Status bar 
set showcmd                    " Show incomplete commands.
set showmode                   " Show current mode.
set showmatch

" Set title bar of terminal window.
set title

" Set status line.
set statusline=[%02n]\ %f\ [fmt=%{&ff}]\ [ft=%Y]\ [asc=\%03.3b]\ [hex=\%02.2B]\ [pos=%04l,%04v]\ %P%*

" Spelling (German, English).
set spelllang=de,en

" Type and number of spelling suggestions.
set spellsuggest=double,10

" Start searching before pressing enter.
set incsearch
" Use <C-L> to clear the highlighting of :set hlsearch.
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :nohlsearch<CR><C-L>
endif

" Command line
set wildmenu                                    " Command-line completition.
set wildmode=longest,list:longest,full          " Bash-VIM completition behavior
set cmdheight=2                                 " 2 lines for command line.

" Show status line.
set ls=2

" Do not wrap text.
set nowrap
set nolinebreak

" Defines for invisible characters.
if &listchars ==# 'eol:$'
  set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
  if !has('win32') && (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
    let &listchars = "tab:\u21e5 ,trail:\u2423,extends:\u21c9,precedes:\u21c7,nbsp:\u00b7"
  endif
endif

" Enable file type detection.
filetype on
filetype indent on
filetype plugin on

" Use F10 to switch between hex and ASCII editing.
function HexConverter()
    let c=getline(".")
    if c =~ '^[0-9a-f]\{7}:'
        :%!xxd -r
    else
        :%!xxd -g4
    endif
endfunction

" Function to make DEL and RETURN work as they should.
function! DeleteKey(...)
    let line=getline (".")
    if line=~'^\s*$'
        execute "normal dd"
        return
    endif
    let column = col(".")
    let line_len = strlen (line)
    let first_or_end=0
    if column == 1
        let first_or_end=1
    else
        if column == line_len
            let first_or_end=1
        endif
    endif
    execute "normal i\<DEL>\<ESC>"
    if first_or_end == 0
        execute "normal l"
    endif
endfunction

function <SID>cppStuff()
    set cindent
    set formatoptions+=croql
    set formatoptions-=t
endfunction

function ShowInvisibleChars()
    " Enable.
    set list!
	" Show trailing whitespace (but not when typing).
    match ExtraWhitespace /\s\+\%#\@<!$/
    " Show trailing whitepace and spaces before a tab.
    match ExtraWhitespace /\s\+$\| \+\ze\t/
endfunction

" ---------------------------------------------------------------------------
" Vim 7 specific mappings
if version >= 700
    " Since most key combinations with CTRL+<...> don't work in a Gnome or
    " xterm terminal, I chose some other combinations (*only* for "normal"
    " mode, since in other modes these combinations may be already taken!).
    nmap <C-t> :tabnew<CR>
    nmap <C-w> :tabclose<CR>
    nmap <C-q> :tabprevious<CR>
    nmap <C-e> :tabnext<CR>
endif

" ---------------------------------------------------------------------------
" All Mode Key Bindings

" Copy and Paste with CTRL+C und CTRL+V
map <C-C> "*y
map <C-V> "*p
map <C-X> "*x

" F2 toggles unprintable characters.
map <F2> :call ShowInvisibleChars()<CR>

" F4 opens a file for editing (like in good old NC).
map <F3> :Vexplore<CR>
map <F4> :Explore<CR>

" Toggles highlighting.
map <F9> :if has("syntax_items")<CR>syntax off<CR>else<CR>syntax on<CR>endif<CR><CR>

" Close current document.
map <F10> :q<CR>
map <S-F10> :q!<CR>

" ---------------------------------------------------------------------------
" Visual Mode Key Bindings

" Apply rot13 for people snooping over shoulder, good fun.
vmap <F12> ggVGg?

" ---------------------------------------------------------------------------

" Call the delete_key function.
nnoremap <silent> <DEL> :call DeleteKey()<CR>
nnoremap <silent> <CR> i<CR><ESC>
nnoremap <silent> <BS> i<BS><RIGHT><ESC>

" ---------------------------------------------------------------------------

if has("autocmd")

    " Strip trailing spaces, tabs and DOS (CRLF) endings from lines.
    autocmd BufEnter *.c,*.cpp,*.h,*.hpp,*.xml,*.wxs,*.wxi,*.nsi,*.nsh,*.php,*.htm,:*.html,*.css :%s/[ \t\r]\+$//e

    " Always cd to the current file's directory.
    autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif

    " Modifications for some file types.
    autocmd FileType c,cpp,h,hpp call <SID>cppStuff()

    " Reread configuration on modification.
    autocmd BufWritePost ~/.vimrc source ~/.vimrc

    " Use :make to compile C, even without a makefile
    au FileType c if glob('[Mm]akefile') == "" | let &mp="gcc -o %< %" | endif

    " Use :make to compile C++, too
    au FileType cpp if glob('[Mm]akefile') == "" | let &mp="g++ -o %< %" | endif

endif " has("autocmd")

" ---------------------------------------------------------------------------

" Solarized colors stuff.
source ~/.vim/bundle/vim-colors-solarized/autoload/togglebg.vim
source ~/.vim/bundle/vim-colors-solarized/colors/solarized.vim

" Include color stuff.
source ~/.vim/startup/colors.vim
