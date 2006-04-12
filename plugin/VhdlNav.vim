" VhdlNav:      Navigation window for VHDL files
" Author:       Steven Milburn
" Date:         Apr 12, 2006
" Version:      1
" History:
"       4/12/06:        Initial Version





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" User changable settings
let g:VhdlNav_columns=30
noremap <F9> :call VhdlNav_Toggle()<CR>:<BS>
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


"----------------------------------------------------------
" Load Once:
if exists("g:loaded_VhdlNav")
        finish
endif
let g:loaded_VhdlNav="v1"


"----------------------------------------------------------
" Key Mappings:
" Create key mappings to enable a double-click or enter on a line in the
" VhdlNav window to navigate over to the respecitve line in the source
nnoremap <2-LEFTMOUSE> :call VhdlNav_GotoCode()<CR>:<BS>
nnoremap <CR> :call VhdlNav_GotoCode()<CR>:<BS>

"----------------------------------------------------------
" Constants:
let s:bname = '__Vhdl_Nav__'

" Define the keywords to search for.
" 0 is reserved for comment divider lines
" 1 is reserved for component declarations
" The rest can be anything extra that one wants to have
let s:keywords_{0} = '^\s*--[#*\-+=]\{18}'
let s:keywords_{1} = '\<component\>'
let s:keywords_{2} = '\<entity\>'
let s:keywords_{3} = '\<process\>'

" Make sure to update the count with the highest keywords number in the list above
let s:keywords_cnt = 3


"----------------------------------------------------------
" Functions:

" Define a function to turn the VhdlNav window on and off.
function! VhdlNav_Toggle()
        " Check if the window is currently on or off
        if exists('s:VhdlNav_State')
                " Variable exists if this function was run at least once
                if s:VhdlNav_State == 1
                        " Means that the VhdlNav window is currently open
                        " Since we're closing the VhdlNav window, turn off the
                        " associated autocommands to speed things back up
                        exe 'aug! VhdlNav_group'
                        " Close the window
                        call s:VhdlNav_CloseWindow()
                        " Set a flag to indicate that window is off
                        let s:VhdlNav_State = 0
                        return
                endif
        endif
        " If either of the above test fail, then the window is not open
        call s:VhdlNav_OpenWindow()
        exe 'aug VhdlNav_group'
        augroup VhdlNav_group
                autocmd CursorHold * nested call s:VhdlNav_Update() 
                "autocmd BufEnter * nested call s:VhdlNav_OpenWindow() 
        augroup END 
        " Increast the update time from the default for more responsiveness
        set updatetime=500
        " Set flag to indicate that VhdlNav is running
        let s:VhdlNav_State = 1
endfunction

" Define a function to close the VhdlNav window and go back to the orignal
" window
function! s:VhdlNav_CloseWindow()
        " Remember the buffer number of the current window
        let curbufnr = bufnr('%')
        " Determine what window the VhdlNav is
        let winnum = bufwinnr('__Vhdl_Nav__')
        " Make sure it exists, if not, can't close it.
        if winnum != -1
                if winnr() == winnum
                        " Already in the Vhdl_Nav window.  Close it and return
                        close
                else
                        " Switch to VhdNav window and close it
                        exe winnum . 'wincmd w' 
                        close 
                        " Jump back to orginal window 
                        exe winnum . 'wincmd w'
                endif
        endif
        return
endfunction
 
" Define a function to jump to the line in the source code where the snippet
" appearing in the VhdlNav window the cursor is currently on comes from.
function! VhdlNav_GotoCode()
        " Make sure that we are in the Vhdl Nav window
        if bufwinnr(s:bname) != winnr()
                return
        endif
        " Determine where the cursor was placed and left
        let linenr = line('.')
        " Use that to determine the index number
        let indnr = linenr-s:HeaderLength
        " Look at the s:VhdlNums_ list to fetch the line number to go to
        let linenr = s:VhdlNums_{indnr}
        " Check if the name of the last vhdl buffer we were in is known
        if exists('s:lastbufname')
                " Get the number of that buffer
                let vhdlbufnr = bufnr(s:lastbufname)
                " Get the window number of the buffer
                let winnum = bufwinnr(vhdlbufnr)
                " If that buffer is still open, go to it
                " Then go to the line determined above
                " and redraw the screen
                if winnum != -1
                        exe winnum . 'wincmd w'
                        exe 'silent! '.linenr
                        exe 'redraw'
                endif
        endif
endfunction
        
" Define a function to open the VhdlNav window
function! s:VhdlNav_OpenWindow()
        " Remember the buffer number that we started from, so we can get back
        let curbufnr=bufnr('%')

        " if the window is already present, don't need to open it
        let winnum = bufwinnr(s:bname)
        if winnum != -1
                return
        endif

        " If the VhdlNav temporary buffer already exists, then reuse it.
        " Otherwise create a bew buffer
        let bufnum = bufnr(s:bname)
        if bufnum == -1
                " Create a new buffer
                let wcmd = s:bname
        else
                " Edit the existing buffer
                let wcmd = '+buffer' . bufnum
        endif

        " Create the VhdlNav window
        exe 'silent! topleft vertical ' . g:VhdlNav_columns . ' split ' . wcmd

        " Mark the buffer as a scratch buffer
        setlocal buftype=nofile
        setlocal bufhidden=delete
        setlocal noswapfile
        setlocal nowrap
        setlocal nobuflisted
        setlocal nonumber

        " Turn on sytax highlighting for the vhdl
        if has('syntax')
                set syntax=vhdl
        endif
        " get the window number of the original buffer and go back to it
        let winnum = bufwinnr(curbufnr)
        exe winnum . 'wincmd w'
        " Update the newly opened VhdlNav window
        call s:VhdlNav_Update()
endfunction

" Define a function to update the contents of the VhdlNav window
function! s:VhdlNav_Update()
        " Make sure the VhdlNav window exists
        let winnum = bufwinnr('__Vhdl_Nav__')
        if winnum == -1
                return
        endif

        " Make sure the buffer we were in when this function was triggered is
        " a vhdl file
        if bufname(winbufnr(0)) !~ '\.vhdl\?'
                return
        else
                " Remember the name of this buffer for use in the
                " VhdlNav_GotoCode function
                let s:lastbufname=bufname(winbufnr(0))
                " Remember the current line number of the current buffer
                let s:curlinenr=line('.')
                " Create the list of snippets and associated line numbers from
                " current buffer
                call s:VhdlNav_CreateList()
                " Remember the current buffer number
                let curbufnr = bufnr('%')
                " Go to the VhdlNav window
                exe winnum . 'wincmd w'
                setlocal modifiable
                " Set report option to a huge value to prevent informational
                " messages about the deleted lines
                let old_report = &report
                set report=99999
                " Populate the VhdlNav Window with information from the lists
                call s:VhdlNav_PopulateWindow()
                " Highlight the appropriate line in the VhdlNav window based
                " on the line we were at in the original buffer
                call s:VhdlNav_Highlight()
                " Mark the VhdlNav buffer oas not modifiable
                setlocal nomodifiable
                " Go back to original buffer
                let winnum = bufwinnr(curbufnr)
                exe winnum . 'wincmd w'
                " Restore report option
                let &report = old_report
        endif
endfunction

" Define a function to highlight the appropriate line in the VhdlNav window
" based on the line number stored in s:curlinenr
function! s:VhdlNav_Highlight()
        " Go through the list of line number in VhdlNum_.  
        " Stop when the value of s:curlinenr is between the current entry and
        " the next
        let i = 1
        while i < s:lines_i
                if s:curlinenr >= s:VhdlNums_{i} && s:curlinenr < s:VhdlNums_{i+1}
                        break
                endif
                let i = i + 1
        endwhile
        " i now tells which index to highlight.
        " Add in the number of lines taken up by the header lines
        let linenr=i+s:HeaderLength
        " Turn on highlighting
        exe 'hi HL_HiCurLine ctermfg=blue ctermbg=cyan guifg=blue guibg=cyan'
        " Match the line number determine to get it hightlighted
        exe 'match ' . "HL_HiCurLine".' /\%'.linenr.'l.'
endfunction
        
" Define a function to enter the data from the lists into the VhdlNav window
function! s:VhdlNav_PopulateWindow()
        " This function assumes we are already in the VhdlNav window
        " Concatenate the entries in s:VhdlLines_ into a single string
        " list_txt, with each entry separated by a new line
        let list_txt=''
        let i = 1
        let s:HeaderLength=1
        while i <= s:lines_i
                let list_txt = list_txt . s:VhdlLines_{i} . "\n"
                let i = i + 1
        endwhile
        " Delete all the lines currenlty in the buffer
        silent! %delete _
        " Put the data from list_txt into the buffer
        exe 'silent! ' . 'put =list_txt'
endfunction



       
" Define a function to create two lists from the source buffer
" The first is a list of code snippets.
" The second is a list of line numbers associated with each snippet.
function! s:VhdlNav_CreateList()
        " Initialize indexing variables
        let s:comp_i = 0
        let s:lines_i = 0
        " Go to first non-blank line in source buffer
        let curn = nextnonblank(1)
        " Loop through all the non-blank lines in the source buffer.
        " curn will be set to 0 if there are no more non-blank lines in the buffer
        while curn != 0
                " Check for any of the keywords in the current line and store
                " the return value
                let retval = s:VhdlNav_CheckKeywords(curn)
                " Based on the return value, add to the lists
                if retval == 1
                        " A normal keyword match was found.
                        " Increment the s:lines_i index and add the current
                        " line and line number to the respective lists
                        let s:lines_i = s:lines_i + 1
                        " Add the current line to the list, but strip
                        " off any white space in front
                        let s:VhdlLines_{s:lines_i}=strpart(getline(curn),match(getline(curn),'\S'))
                        let s:VhdlNums_{s:lines_i}=curn
                        " Go to the next non-blank line
                        let curn = nextnonblank(curn+1)
                elseif retval == 2
                        " A comment seperator was found.
                        " Find the next line that contains only a comment, but
                        " with actual text.  Or, find a line that is blank.
                        " Or, find a line that doesn't start with a comment
                        let curn = curn + 1
                        while getline(curn) !~ '^\s*--\s*[a-zA-Z0-9]\S\+' && 
                                \ nextnonblank(curn) == curn && 
                                \ getline(curn) !~ '^\s*[a-zA-Z]'
                                let curn = curn + 1
                        endwhile
                        " If the line found was blank, don't add anything to
                        " the lists
                        if nextnonblank(curn) != curn
                                let curn = nextnonblank(curn+1)
                        else
                                " Add the non-blank, non-comment-header line
                                " to the list of snippets.
                                " There is the possiblity that a line of code
                                " could follow a comment divider.  If that
                                " happens, it's getting added to the list.
                                let s:lines_i = s:lines_i + 1
                                " Add the current line to the list, but strip
                                " off any white space in front
                                let s:VhdlLines_{s:lines_i}=strpart(getline(curn),match(getline(curn),'\S'))
                                let s:VhdlNums_{s:lines_i}=curn
                                " skip ahead to next non-blank, non comment line
                                " to avoid adding another entry for the bottom
                                " half of a comment divider line
                                while getline(curn) =~ '^\s*--'
                                        let curn = nextnonblank(curn+1)
                                endwhile
                        endif
                else
                        " No keyword was matched.  Just move on to the next
                        " non-blank line
                        let curn = nextnonblank(curn+1)
                endif
        endwhile
endfunction






" Define a function to check the current line for any of the keywords in the
" list above
function! s:VhdlNav_CheckKeywords(curn)
        " Get the current line and store it into a string
        let curs = getline(a:curn)

        " Find the position of the comment in the line if it exists
        let comment_end_pos = match(curs,'--\|end')
        " If it doesn't exist, make it look like the comment is very far over
        if comment_end_pos == -1
                let comment_end_pos = 10000
        endif

        " check for a comment divider line sperately so that a seperate return
        " value can be used
        let pos = match(curs,s:keywords_{0})
        if -1 < pos
                return 2
        endif
        
        " If the component declaration is found, add the component
        " name to the list of components.  This list is later used to
        " find instatiations
        let pos = match(curs,s:keywords_{1})
        " check if a the match occured and that it was before a comment
        if -1 < pos && pos < comment_end_pos
                " Add one to the length of the lists
                let s:comp_i = s:comp_i + 1
                " find the start of the component name
                let namestart=matchend(curs,'component\s\+')
                " Find the end of the component name
                let nameend=match(strpart(curs,namestart),'\(--\)\|\s\|$')+namestart
                " Add the component name to the list of components in the
                " current buffer
                let s:components_{s:comp_i} = strpart(curs,namestart,nameend)
                " Return a number to indicate a normal match
                return 1
        endif
        
        " search for any of the remaing keywords in the current line
        let i = 2
        while i <= s:keywords_cnt
                let pos = match(curs,s:keywords_{i})
                " check if the match occured and if it was before a comment
                if -1 < pos && pos < comment_end_pos
                        " If so, return a number to indicate a normal match
                        return 1
                endif
                " Move on to the next keyword
                let i = i + 1
        endwhile

        " Search for a component instatiation
        let i = 1
        while i <= s:comp_i
                if curs =~ '^\s*[a-zA-Z][a-zA-Z0-9_]\+\s*:\s*\(\<component\>\)\?\s*\<'.s:components_{i}.'\>'
                        " instatiation found.
                        " Return a number that indicates a normal match was
                        " found
                        return 1
                endif
                " move on to the next component name
                let i = i + 1
        endwhile
        " If down here, then no match was found.
        return 0
endfunction


