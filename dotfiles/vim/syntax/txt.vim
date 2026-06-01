
if exists("b:current_syntax")
    finish
endif

syntax match todoStatement "\*Todd: .*"
syntax match doneStatement "=Todd: .*"
syntax match importantNote "\*.*\*"

hi def link todoStatement Statement
hi def link doneStatement Comment
hi def importantNote term=bold cterm=bold gui=bold

" Now you can do zf/END to fold from here to "END"
setlocal foldmethod=manual
