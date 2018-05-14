function! jsfileimport#ast_parser#_file_info() abort
  let l:all = system('flow ast --pretty '.expand('%:p'))
  let l:all = json_decode(l:all)
  let l:all_parsed = { 'unique': [], 'duplicates': [] }
  call s:read_recursively(l:all, l:all_parsed, {
  \ 'name': 'global',
  \ 'type': 'global',
  \ 'line': 0,
  \ 'close_line': line('$')
  \ })

  let l:ranges = jsfileimport#utils#_get_selection_ranges()
  let l:selection = []

  for l:item in l:all_parsed['unique']
    if l:item.start.line >= l:ranges.line_start && l:item.end.line <= l:ranges.line_end
      call add(l:selection, l:item)
    endif
  endfor

  let l:current_line = line('.')
  let l:current_column = col('.')

  let l:data = {
  \ 'selection': l:selection,
  \ 'class': {},
  \ 'method': {},
  \ 'in_class': 0,
  \ 'in_method': 0,
  \ 'current_line': l:current_line,
  \ 'current_column': l:current_column,
  \ 'ranges': l:ranges,
  \ 'all': l:all_parsed
  \ }

  let l:first = l:selection[0]

  if l:first.parent.type ==? 'class'
    let l:data['class'] = l:first.parent
    let l:data['in_class'] = v:true
  elseif l:first.parent.type ==? 'method'
    let l:data['in_class'] = v:true
    let l:data['in_method'] = v:true
    let l:data['method'] = l:first.parent
    let l:data['class'] = l:first.parent.parent
  endif

  return l:data
endfunction

function! s:exists_globally(match, file_info) abort
  for l:item in a:file_info.all.unique
    if a:match.name ==? l:item.name && l:item.parent.type ==? 'global'
      return 1
    endif
  endfor
  return 0
endfunction


function! jsfileimport#ast_parser#_parse_args(file_info) abort
  let l:arguments = []
  let l:skipped = []

  for l:match in a:file_info.selection
    let l:already_added = index(l:arguments, l:match.name) > -1
    let l:is_skipped = index(l:skipped, l:match.name) > -1
    let l:is_var_or_property = l:match.type ==? 'variable' || l:match.type ==? 'property'

    if l:already_added || l:is_skipped || l:is_var_or_property || s:exists_globally(l:match, a:file_info)
      call add(l:skipped, l:match.name)
      continue
    endif

    call add(l:arguments, l:match.name)
  endfor

  return l:arguments
endfunction

function! jsfileimport#ast_parser#_parse_returns(file_info) abort
  let l:returns = []

  function! s:required_until_end_of_scope(item, file_info) abort
    let l:search_from = a:file_info.ranges.line_end + 1
    let l:search_until = line('$')
    if a:item.parent.type ==? 'method'
      let l:search_until = a:item.parent.end.line
    endif

    for l:var in a:file_info.all.duplicates
      if l:var.name ==? a:item.name
      \ && l:var.start.line >= l:search_from
      \ && l:var.end.line <= l:search_until
      \ && l:var.type !=? 'variable'
        return 1
      endif
    endfor

    return 0
  endfunction

  function! s:already_declared_in_scope(item, file_info) abort
    let l:search_from = 0
    let l:search_until = a:item.start.line - 1
    if a:item.parent.type ==? 'method'
      let l:search_until = a:item.parent.end.line
    endif

    for l:var in a:file_info.all.duplicates
      if l:var.name ==? a:item.name
      \ && l:var.start.line >= l:search_from
      \ && l:var.end.line <= l:search_until
      \ && l:var.type !=? 'variable'
        return 1
      endif
    endfor

    return 0
  endfunction

  for l:match in a:file_info.selection
    let l:already_added = index(l:returns, l:match) > -1

    if l:already_added || l:match.name ==? 'this'
      continue
    endif

    if s:required_until_end_of_scope(l:match, a:file_info)
      call add(l:returns, l:match.name)
    endif
  endfor

  return l:returns
endfunction

function! s:read_recursively(data, result, parent) abort
  if !has_key(a:data, 'body')
    return a:result
  endif

  if type(a:data.body) ==? v:t_list
    for l:item in a:data.body
      if l:item.type ==? 'ClassDeclaration'
        let l:class = {
        \ 'type': 'class',
        \ 'name': l:item.id.name,
        \ 'start': l:item.loc.start,
        \ 'end': l:item.loc.end,
        \ 'parent': a:parent
        \ }
        call add(a:result['unique'], l:class)
        call add(a:result['duplicates'], l:class)
        call s:read_recursively(l:item.body, a:result, l:class)
      endif

      if l:item.type ==? 'MethodDefinition'
        let l:method = {
        \ 'type': 'method',
        \ 'name': l:item.key.name,
        \ 'start': l:item.value.loc.start,
        \ 'end': l:item.value.loc.end,
        \ 'parent': a:parent,
        \ }
        call add(a:result['unique'], l:method)
        call add(a:result['duplicates'], l:method)

        for l:param in l:item.value.params
          call s:handle_item(l:param, l:item, a:result, l:method)
        endfor

        call s:read_recursively(l:item.value.body, a:result, l:method)
      endif

      call s:handle_item(l:item, l:item, a:result, a:parent)
    endfor
  endif

  return a:result
endfunction

function! s:add_variable(name, owner, loc, result, parent) abort
  let l:type = 'identifier'
  let l:kind = ''

  if a:name !=? 'this'
    if a:owner.type ==? 'VariableDeclaration'
      let l:type = 'variable'
      let l:kind = a:owner.kind
    elseif a:owner.type ==? 'CallExpression'
      let l:type = 'argument'
    elseif a:owner.type ==? 'MethodDefinition'
      let l:type = 'param'
    elseif a:owner.type ==? 'ReturnStatement'
      let l:type = 'return'
    elseif a:owner.type ==? 'MemberExpression'
    \ && a:owner.property.loc.start.line ==? a:loc.start.line
    \ && a:owner.property.loc.start.column ==? a:loc.start.column
      let l:type = 'property'
    endif
  endif

  function! s:is_duplicate(unique, type, name, kind, parent) abort
    for l:item in a:unique
      if l:item.type ==? a:type && l:item.name ==? a:name && l:item.kind ==? a:kind && l:item.parent.name ==? a:parent.name
        return 1
      endif
    endfor
    return 0
  endfunction

  let l:single_item = {
  \ 'type': l:type,
  \ 'kind': l:kind,
  \ 'name': a:name,
  \ 'start': a:loc.start,
  \ 'end': a:loc.end,
  \ 'parent': a:parent
  \ }

  if !s:is_duplicate(a:result['unique'], l:type, a:name, l:kind, a:parent)
    call add(a:result['unique'], l:single_item)
  endif

  call add(a:result['duplicates'], l:single_item)
endfunction

" TODO
" * Add JSX parsing
" * Add anonymous fn parsing
" * Add async/await parsing
" * Add return parsing
function! s:handle_item(item, owner, result, parent) abort
  if a:item.type ==? 'VariableDeclaration'
    for l:declaration in a:item.declarations
      call s:handle_item(l:declaration, a:item, a:result, a:parent)
    endfor
  elseif a:item.type ==? 'VariableDeclarator'
    call s:handle_item(a:item.id, a:owner, a:result, a:parent)
    call s:handle_item(a:item.init, a:owner, a:result, a:parent)
  elseif a:item.type ==? 'AwaitExpression'
    call s:handle_item(a:item.argument, a:item, a:result, a:parent)
  elseif a:item.type ==? 'CallExpression'
    call s:handle_item(a:item.callee, a:item, a:result, a:parent)
    for l:argument in a:item.arguments
      call s:handle_item(l:argument, a:item, a:result, a:parent)
    endfor
  elseif a:item.type ==? 'ExpressionStatement'
    call s:handle_item(a:item.expression, a:item, a:result, a:parent)
  elseif a:item.type ==? 'AssignmentExpression'
    call s:handle_item(a:item.left, a:item, a:result, a:parent)
    call s:handle_item(a:item.right, a:item, a:result, a:parent)
  elseif a:item.type ==? 'MemberExpression'
    call s:handle_item(a:item.object, a:item, a:result, a:parent)
    call s:handle_item(a:item.property, a:item, a:result, a:parent)
  elseif a:item.type ==? 'ReturnStatement'
    call s:handle_item(a:item.argument, a:item, a:result, a:parent)
  elseif a:item.type ==? 'ThisExpression'
    call s:add_variable('this', a:owner, a:item.loc, a:result, a:parent)
  elseif a:item.type ==? 'Identifier'
    call s:add_variable(a:item.name, a:owner, a:item.loc, a:result, a:parent)
  endif
endfunction
