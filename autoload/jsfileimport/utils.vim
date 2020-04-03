let s:mark_set_from = ''

function! jsfileimport#utils#_determine_import_type() abort
  let l:quote = g:js_file_import_string_quote
  let l:require_regex = {
        \ 'type': 'require',
        \ 'check_import_exists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existing_path': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_full_path_only': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_path_for_full': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': printf('const __FNAME__ = require(%s__FPATH__%s)', l:quote, l:quote),
        \ 'lastimport': '^\(const\|let\|var\)\s\_[^''"]\{-\}require(.*;\?$',
        \ 'default_export': 'module.exports\s*=.\{-\}',
        \ 'partial_export': 'module\.exports\(\.\<__FNAME__\>\|\s*=\_[[:blank:]]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'select_for_sort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'import_name': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*=\s*require([^)]*);\?',
        \ 'is_single_import': '^\(const\|let\|var\)\(\s\|\n\)\{-\}{\?\(\s\|\n\)\{-\}\<__FNAME__\>\(\s\|\n\)\{-\}}\?\(\s\|\n\)\{-\}=\(\s\|\n\)\{-\}require(\_[^)]\{-\});\?',
        \ }

  let l:import_regex = {
        \ 'type': 'import',
        \ 'check_import_exists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existing_path': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_full_path_only': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_path_for_full': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': printf('import __FNAME__ from %s__FPATH__%s', l:quote, l:quote),
        \ 'lastimport': '^import\s\_[^''"]\{-\}from.*;\?$',
        \ 'default_export': 'export\s*default.\{-\}',
        \ 'partial_export': 'export\s*\(const\|var\|function\|class\)\s*\<__FNAME__\>',
        \ 'select_for_sort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'import_name': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*from\s*',
        \ 'is_single_import': '^\import\(\s\|\n\)\{-\}{\?\(\s\|\n\)\{-\}\<__FNAME__\>\(\s\|\n\)\{-\}}\?\(\s\|\n\)\{-\}from\(\s\|\n\)\{-\}[''"][^''"]*[''"];\?',
        \ }

  if g:js_file_import_force_require || (search(l:require_regex['lastimport'], 'n') > 0 && search(l:import_regex['lastimport'], 'n') ==? 0)
    return l:require_regex
  endif

  return l:import_regex
endfunction

function! jsfileimport#utils#_get_file_path(filepath) abort
  if g:js_file_import_from_root
    return substitute(fnamemodify(a:filepath, ':p:r'), g:js_file_import_root.'/', '', '')
  endif

  let l:py_command = has('python3') ? 'py3' : 'py'
  let l:path = a:filepath
  let l:ext = fnamemodify(a:filepath, ':e')

  silent! exe l:py_command.' import vim, os.path'
  silent! exe l:py_command.' current_path = vim.eval("expand(''%:p:h'')")'
  silent! exe l:py_command.' tag_path = vim.eval("fnamemodify(a:filepath, '':p'')")'
  silent! exe l:py_command.' path = os.path.splitext(os.path.relpath(tag_path, current_path))[0]'
  silent! exe l:py_command.' leading_slash = "./" if path[0] != "." else ""'
  silent! exe l:py_command.' vim.command(''let l:path = "%s%s"'' % (leading_slash, path))'

  if !g:js_file_import_strip_file_extension && !empty(l:ext)
    let l:path .= '.'.l:ext
  endif

  return l:path
endfunction

function! jsfileimport#utils#_error(msg) abort
  silent! exe 'redraw'
  echohl ErrorMsg
  echo a:msg
  echohl NONE
  return 0
endfunction

function! jsfileimport#utils#_get_word(is_visual_mode) abort
  let l:word = expand('<cword>')

  if a:is_visual_mode
    let l:selection = jsfileimport#utils#_get_selection()
    let l:word = join(l:selection, '\n')
  endif

  if l:word !~? '\(\d\|\w\)'
    throw 'Invalid word.'
  endif

  return l:word
endfunction

function! jsfileimport#utils#_get_selection() abort
  let l:pos = jsfileimport#utils#_get_selection_ranges()
  let l:lines = getline(l:pos['line_start'], l:pos['line_end'])

  if len(l:lines) ==? 0
    return []
  endif

  let l:lines[-1] = l:lines[-1][:l:pos['column_end'] - (&selection ==? 'inclusive' ? 1 : 2)]
  let l:lines[0] = l:lines[0][l:pos['column_start'] - 1:]
  return l:lines
endfunction

function! jsfileimport#utils#_get_selection_ranges() abort
  let [l:line_start, l:column_start] = getpos("'<")[1:2]
  let [l:line_end, l:column_end] = getpos("'>")[1:2]

  return {
  \ 'line_start': l:line_start,
  \ 'column_start': l:column_start,
  \ 'line_end': l:line_end,
  \ 'column_end': l:column_end,
  \ }
endfunction

function! jsfileimport#utils#_remove_duplicate_files(files) abort
  let l:added = []
  let l:new_files = []

  for l:file in a:files
    let l:filename = split(l:file, ':')[0]
    if index(l:added, l:filename) > -1
      continue
    endif
    call add(l:new_files, l:file)
    call add(l:added, l:filename)
  endfor

  return l:new_files
endfunction

function! jsfileimport#utils#_check_import_exists(name, ...) abort
  let l:rgx = jsfileimport#utils#_determine_import_type()
  let l:pattern = substitute(l:rgx['check_import_exists'], '__FNAME__', a:name, '')
  let l:throw_err = a:0 > 0

  if search(l:pattern, 'n') > 0
    if l:throw_err
      throw 'Import "'.a:name.'" already exists.'
    endif
    return 1
  endif

  return 0
endfunction

function! jsfileimport#utils#_save_cursor_position(from) abort
  if !empty(s:mark_set_from)
    return 0
  endif

  let s:mark_set_from = a:from
  silent exe 'normal! mz'
endfunction

function! jsfileimport#utils#_restore_cursor_position(from) abort
  let l:has_mark = line("'z") > 0
  if l:has_mark && s:mark_set_from ==? a:from
    silent exe 'normal!`z'
    silent exe 'delmarks z'
    let s:mark_set_from = ''
  endif
endfunction

function! jsfileimport#utils#systemlist(cmd) abort
  let l:save_shell = s:set_shell()
  let l:cmd_output = systemlist(a:cmd)
  call s:restore_shell(l:save_shell)
  return l:cmd_output
endfunction

function! jsfileimport#utils#inputlist(options, prompt_text, callback) abort
  if !g:js_file_import_use_fzf || !exists('*fzf#run')
    return s:handle_native_inputlist(a:options, a:prompt_text, a:callback)
  endif

  return fzf#run(fzf#wrap({
        \ 'source': a:options,
        \ 'sink': function('s:handle_fzf_inputlist', [a:options, a:callback]),
        \ 'options': ['--prompt', a:prompt_text]
        \ }))
endfunction

function! s:handle_native_inputlist(options, prompt_text, callback) abort "J{{{
  call inputsave()
  let l:selection = inputlist([a:prompt_text] + a:options)
  call inputrestore()

  if l:selection < 1
    return call(a:callback, [-1])
  endif

  if l:selection > len(a:options)
    throw 'Wrong selection.'
  endif

  return call(a:callback, [l:selection - 1])
endfunction "}}}

function! s:handle_fzf_inputlist(options, callback, selected) abort
  return call(a:callback, [index(a:options, a:selected)])
endfunction

function! s:set_shell() abort "{{{
  let l:save_shell = [&shell, &shellcmdflag, &shellredir]

  if has('win32')
    set shell=cmd.exe shellcmdflag=/c shellredir=>%s\ 2>&1
  else
    set shell=sh shellredir=>%s\ 2>&1
  endif

  return l:save_shell
endfunction "}}}

function! s:restore_shell(saved_shell) abort "{{{
  let [&shell, &shellcmdflag, &shellredir] = a:saved_shell
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2
