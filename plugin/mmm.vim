" ============================================================================
" File:        mmm.vim
" Description: a simple window layout manager
" Author:      Du Zhe <duzhe0211@gmail.com>
" Licence:     Vim licence
" Website:     https://github.com/duzhe/mmm.vim
" Version:     1.1
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
if !exists('s:mmm_tagbar_width')
    let s:mmm_tagbar_width = 32
endif
if !exists('g:mmm_debug')
    let g:mmm_debug = 0
endif
if !exists('g:mmm_debug_logfile')
    let g:mmm_debug_logfile = "/tmp/mmm_debug.log"
endif

" layout
" +----------+-----------+-+
" |          |           | |
" |          |    S1     | |
" |          +-----------+ |
" |          |           | |
" |    M     |    S2     |T|
" |          +-----------+ |
" |          |           | |
" |          |    S3     | |
" |----------+-----------+-|
" M for main window
" S1, S2, S3 for secondary window
" T for tagbar window(if exists)

" window id list, in reverse order. for the layout above, the s:mmm_winids
" should be [S3, S2, S1, M]
let s:mmm_winids = []
" window id of tagbar window
let s:mmm_tagbar_wid = -1


" reorder all the window
function! mmm#reorder()
    call mmm#log("reorder: winids:" .. join(s:mmm_winids, ", "))
    if len(s:mmm_winids) <=1
        return
    endif
    call mmm#stack()
    call mmm#master()
    call mmm#tagbar()
endfunction

" make all window arrangement vertically (except tagbar window)
function! mmm#stack()
    call mmm#log("stack: winids:" .. join(s:mmm_winids, ", "))
    if len(s:mmm_winids) < 2
        return
    endif
    for l:wid in s:mmm_winids[:-2]
        call mmm#goto(l:wid)
        wincmd K
        call mmm#log("stack: wincmd K, " .. l:wid)
    endfor
endfunction


" make master window left
function! mmm#master()
    call mmm#log("master: winids:" .. join(s:mmm_winids, ", "))
    if len(s:mmm_winids) == 0
        return
    endif
    let l:wid = s:mmm_winids[-1]
    call mmm#goto(l:wid)
    wincmd H
    call mmm#log("master: wincmd H, " .. l:wid)
endfunction


" make tagbar window right (if exists)
function! mmm#tagbar()
    call mmm#log("tagbar: " .. s:mmm_tagbar_wid)
    if s:mmm_tagbar_wid == -1
        return
    endif
    let l:cwid = win_getid()
    call mmm#goto(s:mmm_tagbar_wid)
    let l:cmd = s:mmm_tagbar_width .. "wincmd L"
    exec l:cmd
    call mmm#log("tagbar: " .. l:cmd .. ", ".. s:mmm_tagbar_wid)
    call mmm#goto(l:cwid)
endfunction


function! mmm#id_append(wid)
    if a:wid == s:mmm_tagbar_wid
        return
    endif
    call mmm#id_remove(a:wid)
    call add(s:mmm_winids, a:wid)
endfunction


function! mmm#id_remove(wid)
  let l:idx = index(s:mmm_winids, a:wid)
  if (l:idx != -1)
      call remove(s:mmm_winids, l:idx)
  endif
endfunction


function! mmm#e_winnew()
    call mmm#log("e_winnew "..win_getid())
    call mmm#id_append(win_getid())
endfunction


function! mmm#e_bufwinenter()
    call mmm#log("e_bufwinenter")
    if bufname()[0:10] == "__Tagbar__."
        let l:wid = win_getid()
        let s:mmm_tagbar_wid = l:wid
        call mmm#id_remove(l:wid)
        call mmm#log("bufwinenter tagbar yes")
        return
    endif
    call mmm#reorder()
endfunction


function! mmm#e_bufwinleave()
    call mmm#log("e_bufwinleave")
    if bufname()[0:10] == "__Tagbar__."
        let l:wid = win_getid()
        let s:mmm_tagbar_wid = -1
        call mmm#id_append(l:wid)
        call mmm#log("bufwinleave tagbar yes")
    endif
endfunction


function! mmm#e_winclosed()
    call mmm#log("e_bufwinleave " .. win_getid())
    call mmm#id_remove(win_getid())
endfunction


function! mmm#close()
    call mmm#log("winclose")
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
    let l:cmd = "vert topleft new"
    call mmm#log("new cmd:"..l:cmd)
    exec l:cmd
endfunction


" new window with same buffer
function! mmm#split()
    let l:bufnr = bufnr()
    let l:cmd = "vert topleft new"
    call mmm#log("new cmd:"..l:cmd)
    exec l:cmd
    exec "buf " .. l:bufnr
endfunction


" make current window as the main window
function! mmm#focus()
    call mmm#log("focus")
    call mmm#id_append(win_getid())
    call mmm#reorder()
endfunction


function! mmm#log(msg)
   if g:mmm_debug
       execute "redir >> " .. g:mmm_debug_logfile
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
