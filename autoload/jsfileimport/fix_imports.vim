let s:root = expand('<sfile>:p:h') . '/../../'
let s:eslint_config_path = printf('%s%s', s:root, '.eslintrc.js')
let s:eslint_path = printf('%s%s', s:root, 'node_modules/.bin/eslint')

function! jsfileimport#fix_imports#exec() abort
  try
    let l:local_eslint_path = printf('%s/%s', getcwd(), '/node_modules/.bin/eslint')

    if !executable(s:eslint_path) && !executable(l:local_eslint_path)
      throw 'Eslint missing. Please run npm install from plugin directory.'
    endif

    call s:save_if_modified()

    call jsfileimport#utils#_save_cursor_position('fix_imports')
    if executable(l:local_eslint_path)
      let l:errors = systemlist(printf('%s %s %s', l:local_eslint_path, '--format=json', expand('%')))
    else
      let l:errors = systemlist(printf('%s %s %s %s', s:eslint_path, '--config='.s:eslint_config_path, '--format=json', expand('%')))
    endif

    if empty(l:errors)
      throw 'No results from eslint.'
    endif

    let l:errors = l:errors[0]
    let l:errors = json_decode(l:errors)[0]

    if len(l:errors.messages) ==? 1
      let l:is_fatal = has_key(l:errors.messages[0], 'fatal') && l:errors.messages[0].fatal
      if l:is_fatal
        throw 'You have a fatal error in your code: "'.l:errors.messages[0].message.'". Please fix it before trying to fix imports.'
      endif
      if l:errors.messages[0].message =~? 'file ignored'
        throw 'This file is ignored by eslint.'
      endif
    endif

    if has_key(l:errors, 'source')
      call remove(l:errors, 'source')
    endif

    let l:unused_list = []
    let l:missing_list = []
    let l:lines_to_delete = []

    for l:error in l:errors.messages
      if get(l:error, 'ruleId', '') ==? 'no-unused-vars'
        call add(l:unused_list, l:error)
      elseif get(l:error, 'ruleId', '') =~? 'no-undef'
        call add(l:missing_list, l:error)
      endif
    endfor

    for l:unused in l:unused_list
      let l:line_to_delete = s:remove_unused(l:unused)
      if l:line_to_delete > 0
        call add(l:lines_to_delete, l:line_to_delete)
      endif
    endfor

    call sort(l:lines_to_delete, { first, second -> second - first })

    for l:line in l:lines_to_delete
      silent exe l:line.'d'
    endfor

    for l:missing in l:missing_list
      call s:append_missing(l:missing)
    endfor

    call jsfileimport#utils#_restore_cursor_position('fix_imports')

    if g:js_file_import_sort_after_fix
      return jsfileimport#sort()
    endif

    return 1
  catch
    call jsfileimport#utils#_restore_cursor_position('fix_imports')
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

  if !has_key(a:error, 'source') && has_key(a:error, 'endLine')
    let a:error.source = join(getline(a:error.line, a:error.endLine), '')
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

  if l:is_single_import
    return a:error.line
  endif

  let l:new_source = substitute(a:error.source, '\(,\s*\)\?\<'.a:match.'\>\(,\s*\)\?', '', '')

  silent exe '%s/'.escape(a:error.source, './').'/'.escape(l:new_source, './')
  return 0
endfunction

function! s:remove_multi_line(error, match, rgx) abort
  let l:is_single_import_rgx = substitute(a:rgx.is_single_import, '__FNAME__', a:match, 'g')
  let l:is_single_import = search(l:is_single_import_rgx, 'n')

  if l:is_single_import
    silent exe ':%s/'.l:is_single_import_rgx.'//'
    return l:is_single_import
  endif

  let l:new_source = substitute(a:error.source, '\(,\s*\)\?\<'.a:match.'\>\(,\s*\)\?', '', '')

  silent exe '%s/'.escape(a:error.source, './').'/'.escape(l:new_source, './')
  if getline(a:error.line) =~? '^[[:blank:]]*$'
    return a:error.line
  endif
  return 0
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

function! s:save_if_modified()
  if !&modified
    return 1
  endif

  silent exe ':redraw'
  let l:selection = confirm('File needs to be saved before fixing imports. Save now?', "&Yes\n&No\n&Cancel")
  if l:selection !=? 1
    throw 'Canceled.'
  endif

  silent exe ':w'
endfunction

