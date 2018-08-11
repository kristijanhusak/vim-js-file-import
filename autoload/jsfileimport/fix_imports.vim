function! jsfileimport#fix_imports#exec() abort
  let l:local_eslint_path = './node_modules/.bin/eslint'
  let l:has_local_eslint = executable(l:local_eslint_path)
  if !executable('eslint') && !l:has_local_eslint
    return jsfileimport#utils#_error('Eslint required.')
  endif

  let l:executable = l:has_local_eslint ? l:local_eslint_path : 'eslint'

  let l:errors = systemlist([l:local_eslint_path, '--format=json', expand('%')])[0]
  let l:errors = json_decode(l:errors)[0]

  if has_key(l:errors, 'source')
    call remove(l:errors, 'source')
  endif

  for l:error in l:errors.messages
    if get(l:error, 'ruleId', '') ==? 'no-unused-vars'
      call s:remove_unused(l:error)
    elseif get(l:error, 'ruleId', '') ==? 'no-undef'
      call s:append_missing(l:error)
    endif
  endfor

  return jsfileimport#sort()
endfunction

function! s:remove_unused(error)
  let l:rgx = jsfileimport#utils#_determine_import_type()
  let l:match = s:find_name_from_message(a:error.message)
  if empty(l:match)
    return 0
  endif

  "TODO Fix multiline matches to properly check if import
  if a:error.source !~? l:rgx.lastimport
    return 0
  endif

  let l:partial_import_rgx = substitute(l:rgx.is_partial_import, '__FNAME__', l:match, 'g')
  let l:is_partial_import = a:error.source =~? l:partial_import_rgx
  let l:line = search(a:error.source, 'n')

  if !l:is_partial_import
    silent exe ':'.l:line.'d'
    return 1
  endif

  let l:only_import_rgx = substitute(l:rgx.is_single_partial_import, '__FNAME__', l:match, 'g')
  let l:is_only_import = a:error.source =~? l:only_import_rgx

  if l:is_only_import
    silent exe ':'.l:line.'d'
    return 1
  endif

  silent exe '%s/'.a:error.source.'/'.substitute(a:error.source, '\(,\s*\)\?\<'.l:match.'\>\(,\s*\)\?', '', '')
  return 1
endfunction

function! s:append_missing(error)
  let l:match = s:find_name_from_message(a:error.message)

  if empty(l:match)
    return 0
  endif

  try
    call jsfileimport#utils#_check_import_exists(l:match)
  catch
    return 0
  endtry

  return jsfileimport#_import_word(l:match, 'jsfileimport#tags#_get_tag', 0, 0)
endfunction

function! s:find_name_from_message(message)
  let l:matches = matchlist(a:message, '^''\(\<[^'']*\>\)''\(.*\)$')
  if len(l:matches) < 2
    return ''
  endif
  return l:matches[1]
endfunction

