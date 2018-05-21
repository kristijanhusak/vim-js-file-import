function! jsfileimport#rename#_word(word) abort
  let l:file_info = jsfileimport#ast_parser#init()
  let l:match = {}

  for l:item in l:file_info.unique
    if l:item.name ==? a:word
    \ && l:item.start.line ==? l:file_info.current_line
    \ && l:file_info.current_column >=? l:item.start.column
    \ && l:file_info.current_column <=? l:item.end.column
      let l:match = l:item
    endif
  endfor

  if empty(l:match)
    return 0
  endif

  let l:new_name = jsfileimport#utils#_get_input('Enter new name')

  if s:check_if_method(l:file_info, l:match, a:word)
    return s:rename_method(l:file_info, l:match, a:word, l:new_name)
  endif

  let l:is_class_property = s:check_if_class_property(l:file_info, a:word)

  if l:is_class_property
    return s:rename_class_property(l:file_info, a:word, l:new_name)
  endif

  let l:lines = '%'
  let l:match_parent = l:file_info.get_parent(l:match)

  if l:match_parent.type ==? 'method'
    let l:lines = l:match_parent.start.line.','.l:match_parent.end.line
  endif

  echo l:lines

  " Make sure not to change values inside strings
  let l:match_rgx = '\(''[^'']*\|"[^"]*\)\@<!\<'.a:word.'\>\(''[^'']*\|"[^"]*\)\@!'
  let l:add_global = &gdefault ? '' : '/g'
  silent! exe ':'.l:lines.'s/'.l:match_rgx.'/'.l:new_name.l:add_global
  call cursor(l:file_info['current_line'], l:file_info['current_column'])
endfunction

function! s:rename_class_property(file_info, word, new_name) abort
  let l:lines = a:file_info.class.start.line.','.a:file_info.class.end.line

  let l:add_global = &gdefault ? '' : '/g'
  silent! exe ':'.l:lines.'s/'.s:property_regex(a:word).'/'.a:new_name.l:add_global
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:rename_method(file_info, match, word, new_name) abort
  let l:lines = a:file_info.class.start.line.','.a:file_info.class.end.line
  let l:method_line = a:match.start.line
  let l:add_global = &gdefault ? '' : '/g'
  let l:call_to_method_rgx = s:call_to_method_rgx(a:word)

  silent! exe ':'.l:lines.'s/'.l:call_to_method_rgx.'/'.a:new_name.l:add_global
  silent! exe ':'.l:method_line.'s/\<'.a:word.'\>/'.a:new_name.l:add_global
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:check_if_class_property(file_info, word) abort
  if !a:file_info['in_class']
    return 0
  endif

  return match(getline('.'), s:property_regex(a:word)) > -1
endfunction

function! s:check_if_method(file_info, match, word) abort
  if !a:file_info['in_class']
    return 0
  endif

  let l:rgx =  s:call_to_method_rgx(a:word)

  let l:is_call_to_method = match(getline('.'), l:rgx) > -1

  return (a:match.type ==? 'method' || l:is_call_to_method)
endfunction

function! s:call_to_method_rgx(word) abort
  return 'this\(\n[[:blank:]]*\)\?\.\zs\<'.a:word.'\>\ze('
endfunction

function! s:property_regex(word) abort
  return 'this\(\n[[:blank:]]*\)\?\.\zs\<'.a:word.'\>\ze[^(]'
endfunction
