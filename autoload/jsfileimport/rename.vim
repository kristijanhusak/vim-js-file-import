function! jsfileimport#rename#_word(word) abort
  let l:file_info = jsfileimport#utils#_get_file_info()

  if jsfileimport#utils#_is_reserved_word(a:word)
    return 0
  endif

  let l:new_name = jsfileimport#utils#_get_input('Enter new name')

  let l:is_class_property = s:check_if_class_property(l:file_info, a:word)
  let l:is_method = s:check_if_method(l:file_info, a:word)

  if l:is_class_property
    return s:rename_class_property(l:file_info, a:word, l:new_name)
  endif

  if l:is_method
    return s:rename_method(l:file_info, a:word, l:new_name)
  endif

  let l:lines = '%'

  if l:file_info['in_method']
    let l:lines = l:file_info['method']['line'].','.l:file_info['method']['close_line']
  endif


  " Make sure not to change values inside strings
  let l:match = '\(''[^'']*\|"[^"]*\)\@<!\<'.a:word.'\>\(''[^'']*\|"[^"]*\)\@!'
  let l:add_global = &gdefault ? '' : '/g'
  silent! exe ':'.l:lines.'s/'.l:match.'/'.l:new_name.l:add_global
  call cursor(l:file_info['current_line'], l:file_info['current_column'])
endfunction

function! s:rename_class_property(file_info, word, new_name) abort
  let l:lines = a:file_info['class']['line'].','.a:file_info['class']['close_line']

  let l:add_global = &gdefault ? '' : '/g'
  silent! exe ':'.l:lines.'s/'.s:property_regex(a:word).'/'.a:new_name.l:add_global
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:rename_method(file_info, word, new_name) abort
  let l:lines = a:file_info['class']['line'].','.a:file_info['class']['close_line']
  let l:rgx = s:method_regex(a:word)
  let l:add_global = &gdefault ? '' : '/g'

  silent! exe ':'.l:lines.'s/'.l:rgx['call_to_method'].'/'.a:new_name.l:add_global
  silent! exe ':'.l:lines.'s/'.l:rgx['method'].'/'.a:new_name.l:add_global
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:check_if_class_property(file_info, word) abort
  if !a:file_info['in_class']
    return 0
  endif

  return match(getline('.'), s:property_regex(a:word)) > -1
endfunction

function! s:check_if_method(file_info, word) abort
  if !a:file_info['in_class']
    return 0
  endif

  let l:rgx =  s:method_regex(a:word)

  let l:is_call_to_method = match(getline('.'), l:rgx['call_to_method']) > -1
  let l:is_method = match(getline('.'), l:rgx['method']) > -1

  return (l:is_call_to_method || l:is_method)
endfunction

function! s:method_regex(word) abort
  return {
  \ 'call_to_method': 'this\(\n[[:blank:]]*\)\?\.\zs\<'.a:word.'\>\ze(',
  \ 'method': '^[[:blank:]]*\(async\s*\)\?\zs\<'.a:word.'\>\ze('
  \ }
endfunction

function! s:property_regex(word) abort
  return 'this\(\n[[:blank:]]*\)\?\.\zs\<'.a:word.'\>\ze[^(]'
endfunction
