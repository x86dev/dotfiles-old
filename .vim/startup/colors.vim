" Other schemes: 
" - ps_color
syntax enable

if has('gui_running')
    set background=light
else
    set background=dark
endif

set t_Co=16
let g:solarized_termcolors=16

" Allow color schemes to do bright colors without forcing bold.
if &t_Co == 8 && $TERM !~# '^linux'
  set t_Co=16
endif

colorscheme solarized

