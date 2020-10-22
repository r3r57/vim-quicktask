scriptencoding utf-8
" quicktask.vim: A lightweight task management plugin.
"
" Author:   Aaron Bieber
" Version:  1.4
" Date:     25 January 2014
"
" This syntax file was based upon the work of Eric Talevich in his
" "todolist" syntax format. Though many patterns have been re-worked, Eric's
" base file was the inspiration that made Quicktask possible.
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

if exists('b:current_syntax')
  finish
endif

" Save compatibility and force vim compatibility
let s:cpo_save = &cpoptions
set cpoptions&vim

" Set color for highlighting tasks
highlight Highlight ctermbg=green guibg=green

syn case ignore

" Sections, tasks, and notes (the building blocks of any list)
syn match   quicktaskSection        '^=\+.*=\+\s*$'
                                    \ contains=quicktaskSection

syn match   quicktaskTask           '^\s\+[⯆⯈].*$'
                                    \ contains=quicktaskTask,
                                    \ quicktaskTaskStatusReady,
                                    \ quicktaskTaskStatusWIP,
                                    \ quicktaskTaskStatusWait,
                                    \ quicktaskTaskStatusDone

syn match   quicktaskTaskNote       /^\s\+[*]\s.*$/ nextgroup=quickTasktaskNoteCont skipnl

syn match   quicktaskTaskNoteCont   /^\s\+[^⯆⯈*@ ].*$/ contained nextgroup=quicktaskTaskNoteCont,quicktaskTaskNote skipnl

syn match   quicktaskTaskTag        /^\s\+[@]\s\(Added\|Done\|Abandoned\|Ticket\|DEADLINE\).*$/
                                    \ contains=quicktaskTaskTag,quicktaskTaskTagDeadline

syn match   quicktaskTaskPriority   /^\s\+[@]\sPriority.*$/
                                    \ contains=quicktaskTaskTag,
                                    \ quicktaskTaskPriorityLow,
                                    \ quicktaskTaskPriorityMedium,
                                    \ quicktaskTaskPriorityHigh,
                                    \ quicktaskTaskPriorityHighest

" The following items are case-sensitive.
syn case match

" Highlight keywords in todo items and notes:
syn keyword quicktaskTaskStatusReady          contained READY
syn keyword quicktaskTaskStatusWIP            contained WIP
syn keyword quicktaskTaskStatusDone           contained DONE ABANDONED
syn keyword quicktaskTaskStatusWait           contained HOLD WAIT

syn keyword quicktaskTaskTagDeadline          contained DEADLINE

syn keyword quicktaskTaskPriorityLow          contained low
syn keyword quicktaskTaskPriorityMedium       contained medium
syn keyword quicktaskTaskPriorityHigh         contained high
syn keyword quicktaskTaskPriorityHighest      contained HIGH

" The remainder of items are case-insensitive.
syn case ignore

hi Folded  ctermbg=NONE guibg=NONE
hi Folded  ctermfg=grey guifg=grey

" Highlight links
hi def link quicktaskSection                Title

hi def link quicktaskTask                   SpecialComment
hi def link quicktaskTaskStatusReady        Boolean
hi def link quicktaskTaskStatusWIP          Boolean
hi def link quicktaskTaskStatusDone         Boolean
hi def link quicktaskTaskStatusWait         Constant

hi def link quicktaskTaskTag                Comment
hi def link quicktaskTaskTagDeadline        Error

hi def link quicktaskTaskNote               String
hi def link quicktaskTaskNoteCont           String

hi def link quicktaskTaskPriority           Comment
hi def link quicktaskTaskPriorityLow        FoldColumn
hi def link quicktaskTaskPriorityMedium     String
hi def link quicktaskTaskPriorityHigh       Debug
hi def link quicktaskTaskPriorityHighest    Error

let b:current_syntax = 'quicktask'

let &cpoptions = s:cpo_save
unlet s:cpo_save
