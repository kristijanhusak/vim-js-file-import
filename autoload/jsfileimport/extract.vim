let s:method_regex = '^\(\s\|\t\)*\(async\)\?\<[^(]*\>([^)]*)\s*{\s*$'
let s:class_regex = '^\(\s\|\t\)*\<class\>\s*\<.*\>'

function! jsfileimport#extract#variable() abort
  let l:content = jsfileimport#utils#_get_word(1)

  if l:content =~? '^\(\s\|\t\)*\(const\|let\|var\)\s'
    throw 'Cannot extract variable.'
  endif

  if l:content =~? 'return\s'
    throw 'Cannot extract code with return.'
  endif

  let l:var_name = s:get_input('Enter variable name: ')

  let l:types = ['const', 'let', 'var']
  let l:type_list = ['Select type:']

  let l:index = 1
  for l:type in l:types
    call add(l:type_list, l:index.' - '.l:type)
    let l:index += 1
  endfor

  call inputsave()
  let l:type = inputlist(l:type_list)
  call inputrestore()

  if l:type < 1
    throw ''
  endif

  if l:type >= len(l:type_list)
    throw 'Wrong selection.'
  endif

  silent exe 'norm! I'.l:types[l:type - 1].' '.l:var_name.' = '
endfunction

function! jsfileimport#extract#method() abort
  let l:choice_list = ['global']
  let l:has_class = search(s:class_regex, 'nb')
  let l:is_in_method = search(s:method_regex, 'nb')

  if l:has_class > 0
    call add(l:choice_list, 'class')
  endif
  if l:is_in_method > 0
    call add(l:choice_list, 'local function')
  endif

  if len(l:choice_list) ==? 1
    return s:extract_global_function(0, 0)
  endif

  let l:type_list = ['Extract to:']
  let l:index = 1
  for l:choice in l:choice_list
    call add(l:type_list, l:index.' - '.l:choice)
    let l:index += 1
  endfor

  call inputsave()
  let l:type = inputlist(l:type_list)
  call inputrestore()

  if l:type < 1
    throw ''
  endif

  if l:type >= len(l:type_list)
    throw 'Wrong selection.'
  endif

  let l:type_name = l:choice_list[l:type - 1]
  if l:type_name ==? 'global'
    return s:extract_global_function(l:has_class, l:is_in_method)
  elseif l:type_name ==? 'class'
    return s:extract_class_method(l:is_in_method)
  endif

  return s:extract_local_function()
endfunction

function! s:extract_local_function() abort
  let l:var_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:content = jsfileimport#utils#_get_word(1)
  let l:content = substitute(l:content, '\\n', "\<CR>", 'g')
  silent exe 'norm! gv"_d'
  silent exe 'norm! cc'.l:var_name."();\<CR>"
  silent exe 'norm! kOconst '.l:var_name." = () => {\<CR>".l:content."\<CR>};\<CR>"
  silent exe 'norm! kVi{='
  silent exe l:restorepos
endfunction

function! s:extract_class_method(is_in_method) abort
  let l:method_name = s:get_input('Enter method name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:content = jsfileimport#utils#_get_word(1)
  let l:content = substitute(l:content, '\\n', "\<CR>", 'g')
  let l:async = ''
  silent exe 'norm! gv"_d'
  silent exe 'norm! ccthis.'.l:method_name."();\<CR>"
  if a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>"
  else
    call search(s:class_regex, 'b')
    silent exe "norm! $o\<CR>"
  endif

  if l:content =~? 'await'
    let l:async = 'async '
  endif

  silent exe 'norm!cc'.l:async.l:method_name."() {\<CR>".l:content."\<CR>};"
  silent exe 'norm! hVi{='
  silent exe l:restorepos
endfunction

function! s:extract_global_function(has_class, is_in_method) abort
  let l:var_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:content = jsfileimport#utils#_get_word(1)
  let l:content = substitute(l:content, '\\n', "\<CR>", 'g')
  silent exe 'norm! gv"_d'
  silent exe 'norm! cc'.l:var_name."();\<CR>"
  if a:has_class
    call search(s:class_regex, 'b')
    silent exe 'norm! Oconst'
  elseif a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>const"
  else
    silent exe 'norm! cconst'
  endif
  silent exe 'norm! a '.l:var_name." = () => {\<CR>".l:content."\<CR>};\<CR>"
  silent exe 'norm! kVi{='
  silent exe l:restorepos
endfunction

function s:get_input(question) abort
  let l:var_name = input(a:question.': ', '')
  if l:var_name ==? ''
    throw ''
  endif

  return l:var_name
endfunction
