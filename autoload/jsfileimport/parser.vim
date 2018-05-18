function! jsfileimport#parser#_parse_args(selection, file_info) abort
  let l:rgx = jsfileimport#utils#_determine_import_type()
  let l:content = join(a:selection, '')
  let l:matches = s:parse_items(a:selection)
  let l:arguments = []
  let l:skipped_matches = []
  let l:index = 0
  let l:from_line = a:file_info['line_start']

  if a:file_info['in_class'] && a:file_info['in_method']
    let l:from_line = a:file_info['class']['line']
  elseif a:file_info['in_method']
    let l:from_line = a:file_info['method']['line']
  endif

  for l:match in l:matches
    let l:already_added = index(l:arguments, l:match) > -1
    let l:skipped = index(l:skipped_matches, l:match) > - 1
    let l:prev = l:index > 0 ? l:matches[l:index - 1] : ''

    if jsfileimport#utils#_is_reserved_word(l:match) || l:already_added || l:skipped
      let l:index += 1
      continue
    endif

    if s:is_scoped(l:content, l:prev, l:match)
      call add(l:skipped_matches, l:match)
      let l:index += 1
      continue
    endif

    let l:exist_import_pattern = substitute(l:rgx['check_import_exists'], '__FNAME__', l:match, '')
    let l:exist_import = search(l:exist_import_pattern, 'n') > 0

    let l:existing_var = search('^[[:blank:]]*\(const\|var\|let\)\s*'.l:match.'\s*=\s*.*$', 'bn')
    let l:var_declared_out_of_scope = l:existing_var > 0 && l:existing_var < l:from_line

    let l:is_object_prop = match(l:content, l:match.'\s*:\s*') > -1

    let l:is_var_declaration = l:prev =~? '\(const\|let\|var\)'

    if l:var_declared_out_of_scope || l:is_object_prop || l:exist_import || l:is_var_declaration
      call add(l:skipped_matches, l:match)
      let l:index += 1
      continue
    endif

    call add(l:arguments, l:match)
    let l:index += 1
  endfor

  return l:arguments
endfunction

function! jsfileimport#parser#_parse_returns(selection, file_info) abort
  let l:matches = s:parse_items(a:selection)
  let l:content = join(a:selection, '')
  let l:returns = []
  let l:skipped_matches = []
  let l:index = 0

  " Search for return requirement until this line, which is the end of scope
  let l:to_line = line('$')
  if a:file_info['in_method']
    let l:to_line = a:file_info['method']['close_line']
  endif

  " Search requirement for a return value from the end of the selection
  call cursor(a:file_info['line_end'] + 1, 1)

  for l:match in l:matches
    let l:already_added = index(l:returns, l:match) > -1
    let l:skipped = index(l:skipped_matches, l:match) > -1
    let l:prev = l:index > 0 ? l:matches[l:index - 1] : ''

    if jsfileimport#utils#_is_reserved_word(l:match) || l:skipped || l:already_added || l:index ==? 0
      let l:index += 1
      continue
    endif

    if s:is_scoped(l:content, l:prev, l:match)
      call add(l:skipped_matches, l:match)
      let l:index += 1
      continue
    endif

    let l:is_var_declaration = l:prev =~? '\(const\|let\|var\)'
    let l:is_var_assignment = match(l:content, l:prev.'\s*=\s*'.l:match) > -1

    if l:is_var_declaration && search('\<'.l:match.'\>', 'n', l:to_line) > 0
      call add(l:returns, l:match)
      let l:index += 1
      continue
    endif

    if index(l:returns, l:prev) < 0 && l:is_var_assignment && search('\<'.l:prev.'\>', 'n', l:to_line) > 0
      call add(l:returns, l:prev)
      let l:index += 1
      continue
    endif

    call add(l:skipped_matches, l:match)
    let l:index += 1
  endfor

  return l:returns
endfunction

function! s:parse_items(selection) abort
  let l:matches = []

  for l:line in a:selection
    " skip comments
    if l:line =~? '^[[:blank:]]*\(\/\/\|\*\|\/\*\)'
      continue
    endif

    " Remove strings
    let l:line = substitute(l:line, '[''"`][^''"`]*[''"`]', '', 'g')
    " Remove inline comments (/**/)
    let l:line = substitute(l:line, '\/\*[^\*]*\*\/', '', 'g')
    " Remove inline comments (//)
    let l:line = substitute(l:line, '\/\/.*$', '', 'g')

    let l:parse_regex = '\(\.\)\@<!\<[A-Za-z][A-Za-z0-9_]\+\>'
    call substitute(l:line, l:parse_regex, '\=add(l:matches, submatch(0))', 'g')
  endfor

  return l:matches
endfunction

function! s:is_scoped(content, prev, current) abort
  let l:is_var_declaration = a:prev =~? '\(const\|let\|var\)'
  let l:is_var_block_scoped = 0
  let l:is_var_brackets_scoped = 0

  if l:is_var_declaration
    let l:is_var_block_scoped = match(a:content, '{[^}]\{-\}\<'.a:prev.'\s*'.a:current.'\>[^}]*}') > -1
    let l:is_var_brackets_scoped = match(a:content, '([^)]*\<'.a:prev.'\s'.a:current.'\>[^)]*)') > -1
  endif

  let l:is_es6_anonymous_fn_arg = match(a:content, '([^()]*\<'.a:current.'\>[^()]*)\s*=>\s*') > -1
  let l:is_es5_anonymous_fn_arg = match(a:content, 'function([^()]*\<'.a:current.'\>[^()]*)\s*{') > -1
  let l:is_anonymous_fn_arg = l:is_es6_anonymous_fn_arg || l:is_es5_anonymous_fn_arg

  let l:is_in_es6_anonymous_fn = match(a:content, '((\_[^()]*)\s*=>\s*{\?[^)]*\<'.a:current.'\>[^)]*}\?)') > -1
  let l:is_in_es5_anonymous_fn = match(a:content, '(function\s*([^()]*)\s*{[^)]*\<'.a:current.'\>[^)]*}\?)') > -1
  let l:is_in_anonymous_fn = l:is_in_es6_anonymous_fn || l:is_in_es5_anonymous_fn

  return l:is_var_block_scoped || l:is_var_brackets_scoped || l:is_in_anonymous_fn || l:is_anonymous_fn_arg
endfunction

