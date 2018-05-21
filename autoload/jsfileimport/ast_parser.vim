let s:parser = {}

function jsfileimport#ast_parser#init() abort
  let s:parser = s:parser.new()
  return s:parser
endfunction

function! s:parser.new() abort
  let l:global = {
  \ 'id': 'global',
  \ 'name': 'global',
  \ 'type': 'global',
  \ 'start': { 'line': 1, 'column': 1 },
  \ 'end': { 'line': line('$'), 'column': col([line('$'), '$']) }
  \ }

  let self.unique = []
  let self.duplicates = []
  let self.by_id = { 'global': l:global }

  call s:parser.read_body(s:parser.get_ast(), l:global)

  let l:ranges = jsfileimport#utils#_get_selection_ranges()

  let self.selection = s:parser.get_selection(l:ranges)
  let self.class = {}
  let self.method = {}
  let self.in_class = 0
  let self.in_method = 0
  let self.current_line = line('.')
  let self.current_column = col('.')
  let self.ranges = l:ranges

  let l:first = self.selection[0]
  let l:first_parent = s:parser.get_parent(l:first)

  if l:first_parent.type ==? 'class'
    let self.class = l:first_parent
    let self.in_class = v:true
  elseif l:first_parent.type ==? 'method'
    let self.in_class = v:true
    let self.in_method = v:true
    let self.method = l:first_parent
    let l:class = s:parser.get_parent(l:first_parent)
    let self.class = l:class
  endif

  return self
endfunction

function! s:parser.get_ast() abort
  let l:ast = system('flow ast --pretty '.expand('%:p'))
  return json_decode(l:ast)
endfunction

function! s:parser.get_parent(item) abort
  return self.by_id[a:item.parent]
endfunction

function! s:parser.get_selection(ranges)
  let l:selection = []

  for l:item in self.unique
    if l:item.start.line >= a:ranges.line_start && l:item.end.line <= a:ranges.line_end
      call add(l:selection, l:item)
    endif
  endfor

  return l:selection
endfunction

function! s:parser.exists_globally(match)
  for l:item in self.unique
    let l:item_parent = s:parser.get_parent(l:item)
    if a:match.name ==? l:item.name && l:item_parent.type ==? 'global'
      return 1
    endif
  endfor
  return 0
endfunction

function s:parser.parse_args() abort
  let l:arguments = []
  let l:skipped = []

  for l:match in self.selection
    let l:already_added = index(l:arguments, l:match.name) > -1
    let l:is_skipped = index(l:skipped, l:match.name) > -1
    let l:is_var_or_property = l:match.type ==? 'variable' || l:match.type ==? 'property'

    if l:already_added || l:is_skipped || l:is_var_or_property || s:parser.exists_globally(l:match)
      call add(l:skipped, l:match.name)
      continue
    endif

    call add(l:arguments, l:match.name)
  endfor

  return l:arguments
endfunction

function! s:parser.required_until_end_of_scope(item) abort
  let l:search_from = self.ranges.line_end + 1
  let l:search_until = line('$')
  let l:item_parent = s:parser.get_parent(a:item)
  if l:item_parent.type ==? 'method'
    let l:search_until = l:item_parent.end.line
  endif

  for l:var in self.duplicates
    if l:var.name ==? a:item.name
    \ && l:var.start.line >= l:search_from
    \ && l:var.end.line <= l:search_until
    \ && l:var.type !=? 'variable'
      return 1
    endif
  endfor

  return 0
endfunction

function! s:parser.already_declared_in_scope(item) abort
  let l:search_from = 0
  let l:search_until = a:item.start.line - 1
  let l:item_parent = s:parser.get_parent(a:item)
  if l:item_parent.type ==? 'method'
    let l:search_from = l:item_parent.start.line
  endif

  for l:var in self.duplicates
    if l:var.name ==? a:item.name
          \ && l:var.start.line >= l:search_from
          \ && l:var.end.line <= l:search_until
      return 1
    endif
  endfor

  return 0
endfunction

function! s:parser.parse_returns() abort
  let l:returns = []

  for l:match in self.selection
    let l:already_added = index(l:returns, l:match) > -1

    if l:already_added || l:match.name ==? 'this' || s:parser.already_declared_in_scope(l:match)
      continue
    endif

    if s:parser.required_until_end_of_scope(l:match)
      call add(l:returns, l:match.name)
    endif
  endfor

  return l:returns
endfunction

function! s:parser.read_body(data, parent) abort
  if !has_key(a:data, 'body')
    return
  endif

  if type(a:data.body) ==? v:t_list
    for l:item in a:data.body
      if l:item.type ==? 'ClassDeclaration'
        let l:class = {
        \ 'id': s:parser.uuid(),
        \ 'type': 'class',
        \ 'name': l:item.id.name,
        \ 'start': l:item.loc.start,
        \ 'end': l:item.loc.end,
        \ 'parent': a:parent.id
        \ }
        call add(self.unique, l:class)
        call add(self.duplicates, l:class)
        let self.by_id[l:class.id] = l:class
        call s:parser.read_body(l:item.body, l:class)
      endif

      if l:item.type ==? 'MethodDefinition'
        let l:method = {
        \ 'id': s:parser.uuid(),
        \ 'type': 'method',
        \ 'name': l:item.key.name,
        \ 'start': l:item.value.loc.start,
        \ 'end': l:item.value.loc.end,
        \ 'parent': a:parent.id,
        \ }

        call add(self.unique, l:method)
        call add(self.duplicates, l:method)
        let self.by_id[l:method.id] = l:method

        for l:param in l:item.value.params
          call s:parser.handle_item(l:param, l:item, l:method)
        endfor

        call s:parser.read_body(l:item.value.body, l:method)
      endif

      call s:parser.handle_item(l:item, l:item, a:parent)
    endfor
  endif

  return self
endfunction

function! s:parser.is_duplicate(name, type, kind, parent) abort
  for l:item in self.unique
    let l:parent_name = s:parser.get_parent(l:item).name
    if l:item.type ==? a:type && l:item.name ==? a:name && l:item.kind ==? a:kind && l:parent_name ==? a:parent.name
      return 1
    endif
  endfor
  return 0
endfunction

function! s:parser.add_variable(name, owner, loc, parent) abort
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

  let l:single_item = {
  \ 'type': l:type,
  \ 'kind': l:kind,
  \ 'name': a:name,
  \ 'start': a:loc.start,
  \ 'end': a:loc.end,
  \ 'parent': a:parent.id
  \ }

  let l:parent_item = self.by_id[a:parent.id]

  if !s:parser.is_duplicate(a:name, l:type, l:kind, l:parent_item)
    call add(self.unique, l:single_item)
  endif

  call add(self.duplicates, l:single_item)
endfunction

" TODO
" * Add JSX parsing
" * Re-think parent and block scopes, need to exclude those from args and returns
" * Add async/await parsing
" * Add return parsing
function! s:parser.handle_item(item, owner, parent) abort
  if a:item.type ==? 'VariableDeclaration'
    for l:declaration in a:item.declarations
      call s:parser.handle_item(l:declaration, a:item, a:parent)
    endfor
  elseif a:item.type ==? 'VariableDeclarator'
    call s:parser.handle_item(a:item.id, a:owner, a:parent)
    call s:parser.handle_item(a:item.init, a:owner, a:parent)
  elseif a:item.type ==? 'AwaitExpression'
    call s:parser.handle_item(a:item.argument, a:item, a:parent)
  elseif a:item.type ==? 'CallExpression'
    call s:parser.handle_item(a:item.callee, a:item, a:parent)
    for l:argument in a:item.arguments
      call s:parser.handle_item(l:argument, a:item, a:parent)
    endfor
  elseif a:item.type ==? 'ExpressionStatement'
    call s:parser.handle_item(a:item.expression, a:item, a:parent)
  elseif a:item.type ==? 'AssignmentExpression'
    call s:parser.handle_item(a:item.left, a:item, a:parent)
    call s:parser.handle_item(a:item.right, a:item, a:parent)
  elseif a:item.type ==? 'MemberExpression'
    call s:parser.handle_item(a:item.object, a:item, a:parent)
    call s:parser.handle_item(a:item.property, a:item, a:parent)
  elseif a:item.type ==? 'ReturnStatement'
    call s:parser.handle_item(a:item.argument, a:item, a:parent)
  elseif a:item.type ==? 'IfStatement'
    call s:parser.handle_item(a:item.test, a:item, a:parent)
    call s:parser.handle_item(a:item.consequent, a:item, a:parent)
  elseif a:item.type ==? 'LogicalExpression'
    call s:parser.handle_item(a:item.left, a:item, a:parent)
    call s:parser.handle_item(a:item.right, a:item, a:parent)
  elseif a:item.type ==? 'UnaryExpression'
    call s:parser.handle_item(a:item.argument, a:item, a:parent)
  elseif a:item.type ==? 'BlockStatement'
    call s:parser.read_body(a:item, a:parent)
  elseif a:item.type ==? 'FunctionExpression' || a:item.type ==? 'ArrowFunctionExpression'
    call s:parser.handle_item(a:item.id, a:item, a:parent)
    for l:param in a:item.params
      call s:parser.handle_item(l:param, a:item, a:parent)
    endfor
    call s:parser.handle_item(l:param.body, a:item, a:parent)
  elseif a:item.type ==? 'ThisExpression'
    call s:parser.add_variable('this', a:owner, a:item.loc, a:parent)
  elseif a:item.type ==? 'Identifier'
    call s:parser.add_variable(a:item.name, a:owner, a:item.loc, a:parent)
  endif
endfunction

function! s:parser.uuid() abort
  let l:py_command = has('python3') ? 'py3' : 'py'
  let l:uuid = ''

  silent! exe l:py_command.' import vim, uuid'
  silent! exe l:py_command.' vim.command(''let l:uuid = "%s"'' % (uuid.uuid4()))'

  return l:uuid
endfunction
