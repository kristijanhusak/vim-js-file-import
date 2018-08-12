function! jsfileimport#fix_imports#exec() abort
  let l:local_eslint_path = './node_modules/.bin/eslint'
  let l:has_local_eslint = executable(l:local_eslint_path)
  if !executable('eslint') && !l:has_local_eslint
    return jsfileimport#utils#_error('Eslint required.')
  endif

  try
    call jsfileimport#utils#_save_cursor_position()
    let l:executable = l:has_local_eslint ? l:local_eslint_path : 'eslint'

    let l:errors = systemlist([l:local_eslint_path, '--format=json', expand('%')])[0]
    let l:errors = json_decode(l:errors)[0]

    if has_key(l:errors, 'source')
      call remove(l:errors, 'source')
    endif

    let l:unused_list = []
    let l:missing_list = []

    for l:error in l:errors.messages
      if get(l:error, 'ruleId', '') ==? 'no-unused-vars'
        call add(l:unused_list, l:error)
      elseif get(l:error, 'ruleId', '') =~? 'no-undef'
        call add(l:missing_list, l:error)
      endif
    endfor

    for l:unused in l:unused_list
      call s:remove_unused(l:unused)
    endfor

    for l:missing in l:missing_list
      call s:append_missing(l:missing)
    endfor

    if g:js_file_import_sort_after_fix
      return jsfileimport#sort()
    endif

    call jsfileimport#utils#_restore_cursor_position()
    return 1
  catch
    call jsfileimport#utils#_restore_cursor_position()
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! s:remove_unused(error)
  let l:rgx = jsfileimport#utils#_determine_import_type()
  let l:match = s:find_name_from_message(a:error.message)
  if empty(l:match)
    return 0
  endif

  let l:import_exists = jsfileimport#utils#_check_import_exists(l:match)

  if !l:import_exists
    return 0
  endif

  let l:is_single_line = a:error.source =~? l:rgx.lastimport

  if l:is_single_line
    return s:remove_single_line(a:error, l:match, l:rgx)
  endif

  return s:remove_multi_line(a:error, l:match, l:rgx)
endfunction

function! s:remove_single_line(error, match, rgx) abort
  let l:is_single_import_rgx = substitute(a:rgx.is_single_import, '__FNAME__', a:match, 'g')
  let l:is_single_import = a:error.source =~? l:is_single_import_rgx
  let l:line = search(a:error.source, 'n')

  if l:is_single_import
    silent exe ':'.l:line.'d'
    return 1
  endif

  let l:new_source = substitute(a:error.source, '\(,\s*\)\?\<'.a:match.'\>\(,\s*\)\?', '', '')

  silent exe '%s/'.escape(a:error.source, './').'/'.escape(l:new_source, './')
  return 1
endfunction

function! s:remove_multi_line(error, match, rgx) abort
  let l:is_single_import_rgx = substitute(a:rgx.is_single_import, '__FNAME__', a:match, 'g')
  let l:is_single_import = search(l:is_single_import_rgx, 'n')
  let l:line = search(a:error.source, 'n')

  if l:is_single_import
    silent exe ':%s/'.l:is_single_import_rgx.'//|norm!dd'
    return 1
  endif

  let l:new_source = substitute(a:error.source, '\(,\s*\)\?\<'.a:match.'\>\(,\s*\)\?', '', '')

  silent exe '%s/'.escape(a:error.source, './').'/'.escape(l:new_source, './')
  if getline('.') =~? '^[[:blank:]]*$'
    silent exe 'norm!dd'
  endif
  return 1
endfunction

function! s:append_missing(error)
  let l:match = s:find_name_from_message(a:error.message)

  if empty(l:match)
    return 0
  endif

  let l:import_exists = jsfileimport#utils#_check_import_exists(l:match)

  if l:import_exists
    return 0
  endif

  return jsfileimport#_import_word(l:match, 'jsfileimport#tags#_get_tag', 0, 0)
endfunction

function! s:find_name_from_message(message)
  let l:matches = matchlist(a:message, '^''\(\<[^'']*\>\)''\(.*\)$')
  if len(l:matches) < 2
    return ''
  endif
  return l:matches[1]
endfunction

