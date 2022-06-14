" ============================================================================
" File:        mmm.vim
" Description: a simple window layout manager
" Author:      Du Zhe <duzhe0211@gmail.com>
" Licence:     Vim licence
" Website:     https://github.com/duzhe/mmm.vim
" Version:     1.2
" Note:        See the code before using it.
" ============================================================================

scriptencoding utf-8

if !has('autocmd')
    echohl WarningMsg
    echomsg 'mmm requires autocmd'
    echohl None
    finish
endif

" options
if !exists('g:mmm_map_keys')
  let g:mmm_map_keys = 1
endif
if !exists('g:mmm_tagbar_width')
    let g:mmm_tagbar_width = 32
endif
if !exists('g:mmm_debug')
    let g:mmm_debug = 0
endif
if !exists('g:mmm_debug_logfile')
    let g:mmm_debug_logfile = '/tmp/mmm_debug.log'
endif
if !exists('g:mmm_main_width_min')
    let g:mmm_main_width_min = 84
endif



" layout 1 (three columns)
" +-----------+-----------+-------------+---+
" |           |           |             |   |
" |           |           |      S1     |   |
" |           |           |             |   |
" |           |           +-------------+   |
" |           |           |             |   |
" |     M1    |     M2    |      S2     | T |
" |           |           |             |   |
" |           |           +-------------+   |
" |           |           |             |   |
" |           |           |      S3     |   |
" |           |           |             |   |
" |-----------+-----------+-------------+---|
" layout 2 (two columns for smaller screen)
" +-----------+-----------+-+
" |           |           | |
" |           |    S1     | |
" |           +-----------+ |
" |           |           | |
" |     M     |    S2     |T|
" |           +-----------+ |
" |           |           | |
" |           |    S3     | |
" |-----------+-----------+-|
" M for main window
" S for secondary window
" T for tagbar window(if exists)

" window id list, in reverse order. for the layout 1 above, the t:mmm_winids
" should be [S3, S2, S1, M2, M1]
let t:mmm_winids = []
" window id of tagbar window
let t:mmm_tagbar_wid = -1


" reorder all the window
function! mmm#reorder()
    call mmm#log('reorder: winids:' .. join(t:mmm_winids, ', '))
    if len(t:mmm_winids) <=1
        return
    endif
    call mmm#win_width_caculate()
    call mmm#stack()
    call mmm#tagbar()
    call mmm#master()
endfunction


function! mmm#win_width_caculate()
    let l:w = t:mmm_tagbar_wid == -1 ? &columns : &columns - g:mmm_tagbar_width -1
    if (&columns >= g:mmm_main_width_min *3 + g:mmm_tagbar_width + 3)
        let s:win_columns = 3
        let s:main_width = float2nr(ceil((l:w-2)/3))
        let s:main2_width = float2nr(floor((l:w-2)/3))
    elseif (&columns >= g:mmm_main_width_min *2.5 + g:mmm_tagbar_width + 3)
        let s:win_columns = 3
        let s:main_width = g:mmm_main_width_min
        let s:main2_width = g:mmm_main_width_min
    elseif (&columns >= g:mmm_main_width_min *2 + g:mmm_tagbar_width + 2)
        let s:win_columns = 2
        let s:main_width = float2nr(ceil((l:w-1)/2))
    elseif (&columns >= g:mmm_main_width_min *1.5 + g:mmm_tagbar_width + 2)
        let s:win_columns = 2
        let s:main_width = g:mmm_main_width_min
    else
        let s:win_columns = 2
        let s:main_width = float2nr(ceil((l:w-1)/2))
    endif
    if (s:win_columns == 3 && len(t:mmm_winids) <=2) 
        let s:main_width = float2nr(ceil((l:w-1)/2))
        let s:main2_width = float2nr(floor((l:w-1)/2))
    endif
    call mmm#log('win_width: ' .. s:win_columns .. ', ' .. s:main_width)
endfunction


" make all window arrangement vertically (except tagbar window)
function! mmm#stack()
    call mmm#log('stack: winids:' .. join(t:mmm_winids, ', '))
    if len(t:mmm_winids) < s:win_columns
        return
    endif
    let l:w = s:win_columns == 3 ? t:mmm_winids[:-3] : t:mmm_winids[:-2]
    for l:wid in l:w
        call mmm#goto(l:wid)
        let l:cmd = 'set nowinfixwidth | wincmd K'
        exec l:cmd
        call mmm#log('stack: {' .. l:cmd .. '}, ' .. l:wid)
    endfor
endfunction


" make master window left
function! mmm#master()
    call mmm#log('master: winids:' .. join(t:mmm_winids, ', '))
    if len(t:mmm_winids) == 0
        return
    endif
    if s:win_columns == 3
        let l:wid = t:mmm_winids[-2] 
        call mmm#goto(l:wid)
        let l:cmd = 'wincmd H | set winfixwidth | vertical resize ' ..  s:main2_width
        exec l:cmd
        call mmm#log('master: {' .. l:cmd .. '}, wid:' .. l:wid)
    end
    let l:wid = t:mmm_winids[-1]
    call mmm#goto(l:wid)
    let l:cmd = 'wincmd H | set winfixwidth | vertical resize ' ..  s:main_width
    exec l:cmd
    call mmm#log('master: {' .. l:cmd .. '}, wid:' .. l:wid)
endfunction


" make tagbar window right (if exists)
function! mmm#tagbar()
    call mmm#log('tagbar: ' .. t:mmm_tagbar_wid)
    if t:mmm_tagbar_wid == -1
        return
    endif
    let l:cwid = win_getid()
    call mmm#goto(t:mmm_tagbar_wid)
    let l:cmd = g:mmm_tagbar_width .. 'wincmd L'
    exec l:cmd
    call mmm#log('tagbar: ' .. l:cmd .. ', '.. t:mmm_tagbar_wid)
    call mmm#goto(l:cwid)
endfunction


function! mmm#id_append(wid)
    if a:wid == t:mmm_tagbar_wid
        return
    endif
    call mmm#id_remove(a:wid)
    call add(t:mmm_winids, a:wid)
endfunction


function! mmm#id_remove(wid)
  let l:idx = index(t:mmm_winids, a:wid)
  if (l:idx != -1)
      call remove(t:mmm_winids, l:idx)
  endif
endfunction


function! mmm#e_winnew()
    if !exists('t:mmm_winids')
        call mmm#e_tabnew()
    endif
    call mmm#log('e_winnew '..win_getid())
    call mmm#id_append(win_getid())
endfunction


function! mmm#e_bufwinenter()
    call mmm#log('e_bufwinenter')
    if bufname()[0:10] == '__Tagbar__.'
        let l:wid = win_getid()
        let t:mmm_tagbar_wid = l:wid
        call mmm#id_remove(l:wid)
        call mmm#log('bufwinenter tagbar yes')
        return
    endif
    if bufname() =~ 'BufExplorer'
        return
    endif
    call mmm#reorder()
endfunction


function! mmm#e_bufwinleave()
    call mmm#log('e_bufwinleave')
    if bufname()[0:10] == '__Tagbar__.'
        let l:wid = win_getid()
        let t:mmm_tagbar_wid = -1
        call mmm#id_append(l:wid)
        call mmm#log('bufwinleave tagbar yes')
    endif
endfunction


function! mmm#e_winclosed()
    call mmm#log('e_bufwinleave ' .. win_getid())
    call mmm#id_remove(win_getid())
endfunction


function! mmm#e_tabnew()
    call mmm#log('e_tabnew')
    let t:mmm_winids = []
    let t:mmm_tagbar_wid = -1
endfunction


function! mmm#e_vimresized()
    call mmm#log('e_vimresized:' .. &columns)
    "call mmm#win_width_caculate()
    call mmm#reorder()
endfunction


function! mmm#close()
    call mmm#log('winclose')
    close
    call mmm#reorder()
endfunction


" moving to the specified window
function! mmm#goto(twid)
    let l:i = 0
    while l:i < winnr('$')
        let l:wid = win_getid()
        if (l:wid == a:twid)
            break
        endif
        wincmd w
        let l:i+=1
    endwhile
endfunction


" new main window
function! mmm#new()
    let l:cmd = 'vert topleft new'
    call mmm#log('new cmd:'..l:cmd)
    exec l:cmd
endfunction


" new window with same buffer
function! mmm#split()
    let l:bufnr = bufnr()
    let l:cmd = 'vert topleft new'
    call mmm#log('new cmd:'..l:cmd)
    exec l:cmd
    exec 'buf ' .. l:bufnr
endfunction


" make current window as the main window
function! mmm#focus()
    call mmm#log('focus')
    call mmm#id_append(win_getid())
    call mmm#reorder()
endfunction


function! mmm#log(msg)
   if g:mmm_debug
       execute 'redir >> ' .. g:mmm_debug_logfile
       silent echon strftime('%Y-%m-%d %H:%M:%S') . ': ' . a:msg . "\n"
       redir END
   endif
endfunction


augroup mmm
    au!
    au VimEnter    * call mmm#e_winnew()
    au WinNew      * call mmm#e_winnew()
    au WinClosed   * call mmm#e_winclosed()
    au BufWinEnter * call mmm#e_bufwinenter()
    au BufWinLeave * call mmm#e_bufwinleave()
    "au TabNew      * call mmm#e_tabnew()  " not works
    au VimResized  * call mmm#e_vimresized()
augroup end


if g:mmm_map_keys
  nnoremap <C-J> <C-W>w
  nnoremap <C-K> <C-W>W
  nmap <leader>nn :call mmm#new()<CR>
  nmap <leader>ns :call mmm#split()<CR>
  nmap <leader>ne :call mmm#new()<CR>:BufExplorer<CR>
  nmap <C-@> :call mmm#focus()<CR>
  nmap <C-C> :call mmm#close()<CR>
endif
