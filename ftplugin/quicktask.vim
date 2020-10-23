scriptencoding utf-8
" quicktask.vim: A lightweight task management plugin.
"
" Author:   Aaron Bieber
" Version:  1.4
" Date:     25 January 2014
"
" See the documentation in doc/quicktask.txt
"
" Quicktask is free software: you can redistribute it and/or modify it under
" the terms of the GNU General Public License as published by the Free
" Software Foundation, either version 3 of the License, or (at your option)
" any later version.
"
" Quicktask is distributed in the hope that it will be useful, but WITHOUT ANY
" WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
" FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
" details.
"
" You should have received a copy of the GNU General Public License along with
" Quicktask.  If not, see <http://www.gnu.org/licenses/>.

" Compatibility option reset: {{{1
let s:cpo_save = &cpoptions
set cpoptions&vim

" Boilerplate for ftplugins. {{{1
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

if !exists('b:undo_ftplugin')
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '|setlocal comments< formatoptions< spell< wrap< textwidth< expandtab< shiftwidth< tabstop< iskeyword< foldmethod< foldexpr< fillchars< foldtext<'

" Set all buffer-local settings: {{{1
setlocal comments=b:#,f:⯆,f:*
setlocal formatoptions=qnwta
setlocal wrap
setlocal textwidth=80

" Quicktask uses real tabs with a visible indentation of two spaces.
setlocal expandtab
setlocal shiftwidth=2
setlocal tabstop=2

" Folding settings
setlocal foldmethod=expr
setlocal foldexpr=QTFoldLevel(v:lnum)
setlocal fillchars+=fold:\ 
setlocal foldtext=QTFoldText()

" Script settings
let s:one_indent = repeat(' ', &tabstop)

" User-configurable options and their defaults {{{1
if !exists('g:quicktask_autosave')
    let g:quicktask_autosave = 1
endif

if !exists('g:quicktask_date_format')
    let g:quicktask_date_format = '%d.%m.%Y'
endif

if !exists('g:quicktask_fold_done_on_startup')
    let g:quicktask_fold_done_on_startup = 1
endif

" ============================================================================
" EchoWarning(): Echo a warning message, in color! {{{1
function! s:EchoWarning(message)
    echohl WarningMsg
    echo a:message
    echohl None
endfunction

" ============================================================================
" GetAnyIndent(): Get the indent of any line. {{{1
"
" With the cursor on any line, return the indent level (the number of spaces
" at the beginning of the line, simply).
function! s:GetAnyIndent()
    " What is the indentation level of this task?
    let matches = matchlist(getline('.'), '\v^(\s{-})[^ ]')
    let indent = len(matches[1])

    return indent
endfunction

" ============================================================================
" GetTaskIndent(): Return current indent level. {{{1
"
" With the cursor on a task line, return the indent level of that task.
function! s:GetTaskIndent()
    if getline('.') =~# '^\s*⯆ '
        " What is the indentation level of this task?
        let matches = matchlist(getline('.'), '\v^(\s{-})[^ ]')
        let indent = len(matches[1])

        return indent
    endif

    return -1
endfunction

" ============================================================================
" FindTaskStart(): Find the start of the current task. {{{1
"
" Search backwards for a task line. This function moves the cursor.
" If the cursor is already on a task line, do nothing.
function! s:FindTaskStart(move)
    " Only move the cursor if we are asked to.
    let flags = 'bcW'
    if !a:move
        let flags .= 'n'
    endif

    return search('^\s*⯆ ', flags)
endfunction

" ============================================================================
" FindTaskEnd(): Find the end of the current task. {{{1
"
" Search forward for the end of the current task. If we do not start on a task
" line, we first search backwards for a task line. We then search forward for
" the first line that isn't a part of that task, which may be the next task,
" the next section, or the end of the file.
function! s:FindTaskEnd(move)
    " If we are not on a task line
    call s:FindTaskStart(1)
    let task_end_line = line('.')

    " Get the indent of this task
    let indent = s:GetTaskIndent()

    " If this is a task line
    if indent > -1
        " Search downward, looking for either the end of the task block or
        " start/end notes and record them. Begin on the line immediately
        " following the task line.

        let task_end_line = search('^\($\|\s\{0,'.indent.'}[^ ]\)', 'nW')
    endif

    if a:move
        " Move the cursor to the line immediately prior, which should be the
        " last line of the task we are looking for.
        call cursor(task_end_line-1, 0)
    else
        return task_end_line - 1
    endif
endfunction

" ============================================================================
" FindTaskParent(): Find the start line of the current task's parent. {{{1
"
" Get the indent level of the current task and, if non-zero, find the first
" line of the task that encloses this one (its 'parent').
function! s:FindTaskParent()
    call s:FindTaskStart(1)
    let indent = s:GetTaskIndent()

    if indent == 0
        return 0
    else
        let parent_indent = indent - &tabstop
        return search('^\s\{'.parent_indent.'}⯆', 'bnW')
    endif
endfunction

" ============================================================================
" FindChild(): Find children task below the current task. {{{1
"
" Get the indent level of the current task and find a task below this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! s:FindChild(child_indent, offset_line, boundary_line)
  call cursor(a:offset_line, 0)
  return search('^\s\{'.a:child_indent.'}⯆', 'nW', a:boundary_line)
endfunction

" ============================================================================
" CheckChildrenDone(): Find children task below the current task. {{{1
"
" Get the indent level of the current task and find a task below this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! s:CheckChildrenDone()
  call s:FindTaskStart(1)
  let parent_line = line('.')
  let indent = s:GetTaskIndent()

  let child_indent = indent + &tabstop

  let offset_line = line('.')
  let boundary_line = s:FindTaskEnd(0)

  let child_line = -1
  while child_line != 0
    let child_line = s:FindChild(child_indent, offset_line, boundary_line)
    if or(child_line == 0, getline(child_line) =~# '^\s*⯆\s\(✓ DONE\|✕ ABANDONED\)')
      let offset_line = child_line
    else
      call cursor(parent_line, 0)
      return child_line
    endif
  endwhile
  call cursor(parent_line, 0)
  return 0
endfunction

" ============================================================================
" CheckDayDone(): Find children task below the current task. {{{1
"
" Get the indent level of the current task and find a task below this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! s:CheckDayDone()
  let day_line = line('.')
  let child_indent = &tabstop

  let offset_line = day_line
  let boundary_line = search('^$', 'nW')

  let child_line = -1
  while child_line != 0
    let child_line = s:FindChild(child_indent, offset_line, boundary_line)
    if or(child_line == 0, getline(child_line) =~# '^\s*⯆\s\(✓ DONE\|✕ ABANDONED\)')
      let offset_line = child_line
    else
      call cursor(day_line, 0)
      return child_line
    endif
  endwhile
  call cursor(day_line, 0)
  return 0
endfunction

" ============================================================================
" SelectTask(): Create a linewise visual selection of the current task. {{{1
function! s:SelectTask()
    call s:FindTaskStart(1)
    let end_line = s:FindTaskEnd(0)

    execute 'normal V'.end_line.'G'
endfunction

" ============================================================================
" NewDay(): Add a task to the file. {{{1
"
" Add a 'skeleton' task to the file after the line given and at the indent
" level specified.
function! s:NewDay()
    call append(line(0),'================================== '.s:GetDatestamp('today').' ==================================')
endfunction

" ============================================================================
" AddTask(after, indent): Add a task to the file. {{{1
"
" Add a 'skeleton' task to the file after the line given and at the indent
" level specified.
function! s:AddTask(after, indent, is_first_level, move_cursor)
    if a:indent > 0
        let physical_indent = repeat(' ', a:indent)
    else
        let physical_indent = ''
    endif

    " Compose the two lines to insert
    let new_task_lines = [ physical_indent . '⯆ READY ' ]

    let date_format = g:quicktask_date_format
    let date_line = physical_indent . s:one_indent . '@ Added ' . strftime(date_format)

    if a:is_first_level
        let priority_line = physical_indent . s:one_indent . '@ Priority medium'
        let new_task_lines += [ date_line , priority_line ]
    else
        let new_task_lines += [ date_line ]
    endif


    call append(a:after, new_task_lines)

    if a:move_cursor
        call cursor(a:after+1, len(getline(a:after+1)))
        startinsert!
    endif
endfunction

" ============================================================================
" AddTaskAbove(): Add a task above the current task. {{{1
"
" Add a task above the current task, at the current task's level.
function! s:AddTaskAbove()
    " We don't support inserting a task above a section.
  if getline('.') =~# '=\{34\}$'
        call s:EchoWarning("Inserting a task above a section isn't supported.")
        return
    endif

    call s:FindTaskStart(1)
    let indent = s:GetTaskIndent()
    " Append the new task above this line
    let task_line_num = line('.')

    " Append the task, moving the cursor and starting insert
    call s:AddTask(task_line_num-1, indent, 1, 1)
endfunction

" ============================================================================
" AddTaskBelow(): Add a task below the current task. {{{1
"
" Add a task below the current task, at the current task's level.
function! s:AddTaskBelow()
    " We insert directly below sections.
    if getline('.') =~# '=\{34\}$'
        let indent = s:GetAnyIndent() + &tabstop
        let task_line_num = line('.')
    else
        " Find current task
        call s:FindTaskStart(1)
        " Get indent (this will be our new indent)
        let indent = s:GetTaskIndent()
        if indent < 0
            let indent = &tabstop
        endif

        " Find the end of the task and note the line number
        call s:FindTaskEnd(1)
        let task_line_num = line('.')
    endif

    " Append the task, moving the cursor and starting insert
    call s:AddTask(task_line_num, indent, 1, 1)
endfunction

" ============================================================================
" AddChildTask(): Add a task as a child of the current task. {{{1
function! s:AddChildTask()
    " If we are not on a task line right now, we need to search up for one.
    call s:FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = s:GetTaskIndent()
    if indent < 0
        let indent = &tabstop
    else
        " The indent we want to find is the tasks's indent plus one.
        let indent = indent + &tabstop
    endif

    call s:FindTaskEnd(1)
    call s:AddTask(line('.'), indent, 0, 1)
endfunction

" ============================================================================
" AddNoteToTask(): Add a new note to a task. {{{1
"
" Add a new note to the task.
function! s:AddNoteToTask()
    " If we are not on a task line right now, we need to search up for one.
    call s:FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = s:GetTaskIndent()

    " The indent we want to find is the tasks's indent plus one.
    let indent = indent + &tabstop

    let physical_indent = repeat(' ', indent)
    let note_line = physical_indent . '* '

    " Search downward, looking for existing note or beginning of Added note
    let current_line = line('.') + 1

    while current_line <= line('$')
        " If we are still at the correct indent level
        if match(getline(current_line), '\v^\s{'.indent.'}') > -1
            " If this line is a sub-task, we have reached our location.
            if match(getline(current_line), '\v^\s*⯆') > -1
                let current_line = current_line - 1
                break
            " If this line is an Added/Start line, we have reached our
            " location.
            elseif match(getline(current_line), '\v^\s*\@') > -1
                let current_line = current_line - 1
                break
            " If this line is a note, keep looking.
            elseif match(getline(current_line), '\v^\s*\*') > -1
                let current_line = current_line + 1
                continue
            endif
        else
            " We have reached the end of the task; we have arrived.
            let current_line = current_line - 1
            break
        endif

        let current_line = current_line + 1
    endwhile

    " Add the note to current task and move the cursor to the note
    call append(current_line, [note_line])
    call cursor(current_line + 1, indent + 3)

    " Switch to insert mode to edit the note
    startinsert!
endfunction

" ============================================================================
" AddTag(): Add tag (@ ...). {{{1
"
" Mark a task as complete by placing a note at the very end of the task
" containing the keyword DEADLINE.
function! s:AddTag(tag, move_cursor)
    " If we are not on a task line right now, we need to search up for one.
    call s:FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = s:GetTaskIndent()

    " The indent we want to find is the tasks's indent plus the length of one
    " indent (the number of spaces in the user's tabstop).
    let indent = indent + &tabstop

    " Search downward, looking for either a reduction in the indentation level
    " or the end of the file. The first line to fail to match will be the line
    " AFTER our insertion point. Start searching on the line after the task
    " line.
    let current_line = line('.') + 1
    let matched = 0
    while current_line <= line('$')
        " If we are still at the correct indent level
        if match(getline(current_line), '\v^\s{'.indent.'}') == -1
            " Move the cursor to the line preceding this one.
            let start = current_line - 1
            " Break out, we have arrived.
            break
        endif

        let current_line = current_line + 1
    endwhile

    let physical_indent = repeat(' ', indent)

    if a:move_cursor
      call append(start, physical_indent.'@ '.a:tag.' ')
      call cursor(start+1, len(getline(start+1)))
      startinsert!
    else
      call append(start, physical_indent.'@ '.a:tag)
    endif
endfunction

" ============================================================================
" UpdateStatus(): Update status (READY, WIP, HOLD, WAIT, DONE). {{{1
"
" Mark a task as complete by placing a note at the very end of the task
" containing the keyword DONE followed by the current timestamp.
function! s:UpdateStatus(status)
    " If we are not on a task line right now, we need to search up for one.
    call s:FindTaskStart(1)

    if a:status ==# '✓ DONE'
      let unfinished_children_line = s:CheckChildrenDone()
      if unfinished_children_line == 0
        call setline(line('.'), substitute(getline('.'), '\(READY\|⚙ WIP\|⏸ HOLD\|⧖ WAIT\|✓ DONE\|✕ ABANDONED\)', a:status, ''))
        call s:AddTag('Done '.s:GetDatestamp('today').' '.s:GetTimestamp(), 0)
        :normal! zc
      else
        call s:EchoWarning('There are unfinished child tasks.')
        call cursor(unfinished_children_line, 0)
      endif
    elseif a:status ==# '✕ ABANDONED'
      call setline(line('.'), substitute(getline('.'), '\(READY\|⚙ WIP\|⏸ HOLD\|⧖ WAIT\|✓ DONE\|✕ ABANDONED\)', a:status, ''))
      call s:AddTag('Abandoned '.s:GetDatestamp('today').' '.s:GetTimestamp(), 0)
      :normal! zc
    else
      call setline(line('.'), substitute(getline('.'), '\(READY\|⚙ WIP\|⏸ HOLD\|⧖ WAIT\|✓ DONE\|✕ ABANDONED\)', a:status, ''))
      :normal! zo
      if a:status =~# "\\(⚙ WIP\\|⏸ HOLD\\|⧖ WAIT\\)"
        let parent_line = s:FindTaskParent()
        if parent_line != 0
          let cursor_line = line('.')
          call cursor(parent_line, 0)
          call s:UpdateStatus('⚙ WIP')
          call cursor(cursor_line, 0)
        endif
      endif
    endif
endfunction

" ============================================================================
" SaveOnFocusLost(): Save the current file silently. {{{1
"
" This will be called by an autocommand to save the current task list file
" when focus is lost.
function! s:SaveOnFocusLost()
    if &filetype ==# 'quicktask'
        :silent! w
    endif
endfunction

" ============================================================================
" GetDatestamp(): Get a Quicktask-formatted datestamp. {{{1
"
" Datestamps are used throughout Quicktask both for user convenience of
" tracking their tasks in the continuum of the universe immemorial and also to
" locate current tasks. GetDatestamp() returns a Quicktask-formatted
" datestamp for the requested time relative to 'now.'
function! s:GetDatestamp(coordinate)
    if a:coordinate ==# 'tomorrow'
        return strftime(g:quicktask_date_format, localtime()+86400)
    elseif a:coordinate ==# 'yesterday'
        return strftime(g:quicktask_date_format, localtime()-86400)
    elseif a:coordinate ==# 'nextweek'
        return strftime(g:quicktask_date_format, localtime()+604800)
    endif
    return strftime(g:quicktask_date_format)
endfunction

" ============================================================================
" GetTimestamp(): Get a Quicktask-formatted timestamp. {{{1
"
" Timestamps are used for the start and end times added to tasks and by the
" abbreviation system. GetTimestamp() returns a Quicktask-formatted timestamp
" for the current time.
function! s:GetTimestamp()
    return strftime('%H:%M')
endfunction

" ============================================================================
" QTFoldLevel(): Returns the fold level of the current line. {{{1
"
" This is used by the Vim folding system to fold tasks based on their depth
" and relationship to one another.
function! QTFoldLevel(linenum)
    let pre_indent = indent(a:linenum-1) / &tabstop
    let cur_indent = indent(a:linenum) / &tabstop
    let nxt_indent = indent(a:linenum+1) / &tabstop

    if nxt_indent == cur_indent + 1
        return '>'.nxt_indent
    elseif pre_indent == cur_indent && nxt_indent < cur_indent
        return '<'.cur_indent
    else
        return cur_indent
    endif
endfunction

" ============================================================================
" QTFoldText(): Provide the text displayed on a fold when closed. {{{1
"
" This is used by the Vim folding system to find the text to display on fold
" headings when folds are closed. We use this to cause the headings to display
" in an indented fashion matching the tasks themselves.
function! QTFoldText()
    let lines = v:foldend - v:foldstart + 1
    return substitute(getline(v:foldstart), '⯆', '⯈', '').' ('.lines.')'
endfunction

" ============================================================================
" CloseFoldIfOpen(): Quietly close a fold only if it is open. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! CloseFoldIfOpen()
    if foldclosed(line('.')) == -1
        silent! normal zc
    endif
endfunction

" ============================================================================
" CloseFoldIfOpenAndDone(): Quietly close a fold only if it is open. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! CloseFoldIfOpenAndDayDone()
    if s:CheckDayDone() == 0
        call s:CloseFoldIfOpen()
    endif
endfunction

" ============================================================================
" FoldTasks(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! s:FoldTasks(status)
    let current_line = line('.')
    execute 'g/⯆ '.a:status.'/call CloseFoldIfOpen()'
    call cursor(current_line, 0)
endfunction

" ============================================================================
" FoldDaysDone(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! s:FoldDaysDone()
    let current_line = line('.')
    execute 'g/^=\+.*=\+\s*$/call CloseFoldIfOpenAndDone()'
    call cursor(current_line, 0)
endfunction

" ============================================================================
" FoldDoneDaysAndDoneTasks(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! s:FoldDoneDaysAndDoneTasks()
    call s:FoldDaysDone()
    call s:FoldTasks('\(✓ DONE\|✕ ABANDONED\)')
endfunction

" ============================================================================
" HightlightTasks(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! s:HighlightTasks(status)
    if a:status != ''
      execute ':match Highlight /^.*⯆ '.a:status.'.*$/'
    else
      execute ':match none'
    endif
endfunction

" ============================================================================
" Private mappings {{{1
nmap <silent> <Plug>NewDay                   :call <SID>NewDay()<CR>
nmap <silent> <Plug>SelectTask               :call <SID>SelectTask()<CR>
nmap <silent> <Plug>AddTicketTag             :call <SID>AddTag('Ticket', 1)<CR>
nmap <silent> <Plug>AddDeadlineTag           :call <SID>AddTag('DEADLINE', 1)<CR>
nmap <silent> <Plug>AddPriorityTag           :call <SID>AddTag('Priority', 1)<CR>
nmap <silent> <Plug>UpdateStatusReady        :call <SID>UpdateStatus('READY')<CR>
nmap <silent> <Plug>UpdateStatusWip          :call <SID>UpdateStatus('⚙ WIP')<CR>
nmap <silent> <Plug>UpdateStatusHold         :call <SID>UpdateStatus('⏸ HOLD')<CR>
nmap <silent> <Plug>UpdateStatusWait         :call <SID>UpdateStatus('⧖ WAIT')<CR>
nmap <silent> <Plug>UpdateStatusDone         :call <SID>UpdateStatus('✓ DONE')<CR>
nmap <silent> <Plug>UpdateStatusAbandoned    :call <SID>UpdateStatus('✕ ABANDONED')<CR>
nmap <silent> <Plug>ShowActiveTasks          :call <SID>FoldDoneDaysAndDoneTasks()<CR>
nmap <silent> <Plug>HighlightReadyTasks      :call <SID>HighlightTasks('READY')<CR>
nmap <silent> <Plug>HighlightWIPTasks        :call <SID>HighlightTasks('⚙ WIP')<CR>
nmap <silent> <Plug>HighlightHoldTasks       :call <SID>HighlightTasks('⏸ HOLD')<CR>
nmap <silent> <Plug>HighlightWaitTasks       :call <SID>HighlightTasks('⧖ WAIT')<CR>
nmap <silent> <Plug>HighlightNoTasks         :call <SID>HighlightTasks('')<CR>
nmap <silent> <Plug>AddTaskAbove             :call <SID>AddTaskAbove()<CR>
nmap <silent> <Plug>AddTaskBelow             :call <SID>AddTaskBelow()<CR>
nmap <silent> <Plug>AddNoteToTask            :call <SID>AddNoteToTask()<CR>
nmap <silent> <Plug>AddChildTask             :call <SID>AddChildTask()<CR>

" Public mappings {{{1
if ! exists('b:quicktask_did_mappings')
    nmap <unique><buffer> <Leader>td  <Plug>NewDay
    nmap <unique><buffer> <Leader>tv  <Plug>SelectTask
    nmap <unique><buffer> <Leader>tat <Plug>AddTicketTag
    nmap <unique><buffer> <Leader>tad <Plug>AddDeadlineTag
    nmap <unique><buffer> <Leader>tap <Plug>AddPriorityTag
    nmap <unique><buffer> <Leader>tur <Plug>UpdateStatusReady
    nmap <unique><buffer> <Leader>tuw <Plug>UpdateStatusWip
    nmap <unique><buffer> <Leader>tuh <Plug>UpdateStatusHold
    nmap <unique><buffer> <Leader>tut <Plug>UpdateStatusWait
    nmap <unique><buffer> <Leader>tud <Plug>UpdateStatusDone
    nmap <unique><buffer> <Leader>tua <Plug>UpdateStatusAbandoned
    nmap <unique><buffer> <Leader>tsa <Plug>ShowActiveTasks
    nmap <unique><buffer> <Leader>thr <Plug>HighlightReadyTasks
    nmap <unique><buffer> <Leader>thw <Plug>HighlightWIPTasks
    nmap <unique><buffer> <Leader>thh <Plug>HighlightHoldTasks
    nmap <unique><buffer> <Leader>tht <Plug>HighlightWaitTasks
    nmap <unique><buffer> <Leader>thn <Plug>HighlightNoTasks
    nmap <unique><buffer> <Leader>tO  <Plug>AddTaskAbove
    nmap <unique><buffer> <Leader>to  <Plug>AddTaskBelow
    nmap <unique><buffer> <Leader>tan <Plug>AddNoteToTask
    nmap <unique><buffer> <Leader>tac <Plug>AddChildTask
    command -buffer -nargs=0 QTAddTaskBelow call <SID>AddTaskBelow()
    let b:quicktask_did_mappings = 1
endif

" ============================================================================
" Autocommands {{{1
if g:quicktask_autosave
    augroup quicktask
      au!
      autocmd BufLeave,FocusLost * call <SID>SaveOnFocusLost()
    augroup END
endif

if g:quicktask_fold_done_on_startup
    augroup quicktask
      au!
      autocmd BufEnter * call <SID>FoldDoneDaysAndDoneTasks()
    augroup END
endif

" ============================================================================
" Abbreviations {{{1
iabbrev <expr> :today:      <SID>GetDatestamp('today')
iabbrev <expr> :tomorrow:   <SID>GetDatestamp('tomorrow')
iabbrev <expr> :yesterday:  <SID>GetDatestamp('yesterday')
iabbrev <expr> :nextweek:   <SID>GetDatestamp('nextweek')
iabbrev <expr> :now:        <SID>GetTimestamp()

" Compatibility option reset: {{{1
let &cpoptions = s:cpo_save
unlet s:cpo_save

