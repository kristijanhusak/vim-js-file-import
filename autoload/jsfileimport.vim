function! jsfileimport#word(...) abort
  return s:doImport('getTag', a:0)
endfunction

function! jsfileimport#prompt() abort
  return s:doImport('getTagDataFromPrompt', 0)
endfunction

function! jsfileimport#clean() abort
  silent exe 'normal mz'
  let l:rgx = s:determineImportType()
  call cursor(1, 0)
  let l:start = search(l:rgx['lastimport'], 'c')
  let l:end = search(l:rgx['lastimport'], 'be')

  for l:line in getline(l:start, l:end)
    let l:list = matchlist(l:line, l:rgx['importName'])
    if len(l:list) >= 3 && s:countWordInFile(l:list[2]) <= 1
      silent exe l:start.'d'
      continue
    endif
    let l:start += 1
  endfor
  silent exe 'normal! `z'
endfunction

function! jsfileimport#sort(...) abort
  if a:0 == 0
    silent exe 'normal mz'
  endif

  let l:rgx = s:determineImportType()

  if search(l:rgx['selectForSort'], 'be') > 0
    silent exe g:js_file_import_sort_command
  endif

  silent exe 'normal! `z'
  return 1
endfunction

function! jsfileimport#goto(...) abort
  try
    call s:checkPythonSupport()
    let l:name = s:getWord()
    let l:rgx = s:determineImportType()
    let l:tags = s:getTaglist(l:name, l:rgx)
    let l:currentFilePath = expand('%:p')

    if len(l:tags) == 0
      throw 'Tag not found.'
    endif

    if a:0 == 0
      if len(l:tags) == 1
        return s:jumpToTag(l:tags[0], l:currentFilePath)
      endif

      let l:tagInCurrentFile = s:getTagInCurrentFile(l:tags, l:currentFilePath)

      if l:tagInCurrentFile['filename'] !=? ''
        return s:jumpToTag(l:tagInCurrentFile, l:currentFilePath)
      endif
    endif

    let l:tagSelectionList = s:generateTagSelectionlist(l:tags)
    let l:options = extend(['Current path: '.expand('%'), 'Select definition:'], l:tagSelectionList)

    call inputsave()
    let l:selection = inputlist(l:options)
    call inputrestore()

    if l:selection < 1
      return 0
    endif

    if l:selection >= len(l:options) - 1
      throw 'Wrong selection.'
    endif

    return s:jumpToTag(l:tags[l:selection - 1], l:currentFilePath)
  catch /.*/
    if v:exception !=? ''
      return s:error(v:exception)
    endif
    return 0
  endtry
endfunction

function! jsfileimport#findusage() abort
  try
  if !executable('rg') && !executable('ag')
    throw 'rg (ripgrep) or ag (silversearcher) needed.'
  endif
  let l:rgx = s:determineImportType()
  let l:word = s:getWord()
  let l:currentFilePath = expand('%')
  let l:executable = executable('rg') ? 'rg' : 'ag'
  let l:line = line('.')

  let l:files = systemlist(l:executable.' '.l:word.' --vimgrep .')
  call filter(l:files, {idx, val -> val !~ '^'.l:currentFilePath.':'.l:line.'.*$'})
  let l:options = ['Select usage:']

  let l:index = 0
  for l:file in l:files
    let l:index += 1
    call add(l:options, l:index.' - '.l:file)
  endfor

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 1
    throw ''
  endif

  if l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  let [l:filename, l:row, l:column] = matchlist(l:files[l:selection - 1], '\([^:]*\):\(\d*\):\(\d*\):\(.*\)')[1:3]
  let l:openFileCommand = ''

  if expand('%:p') !=? fnamemodify(l:filename, ':p')
    let l:openFileCommand = 'e '.l:filename
  else
    silent exe 'norm!m`'
  endif

  let l:command = printf('%s|call cursor(%s, %s)', l:openFileCommand, l:row, l:column)
  silent exe l:command
  return 1
  catch /.*/
    if v:exception !=? ''
      return s:error(v:exception)
    endif
    return 0
  endtry
  endtry
endfunction

function! s:jumpToTag(tag, currentFilePath) abort "{{{
  let l:tagPath = fnamemodify(a:tag['filename'], ':p')

  if l:tagPath !=? a:currentFilePath && bufname('%') !=? a:tag['filename']
    silent exe 'e '.a:tag['filename']
  else
    "Sets the previous context mark to allow jumping to this location with CTRL-O
    silent exe 'norm!m`'
  endif
  silent exe escape(a:tag['cmd'], '[]')
  return 1
endfunction "}}}

function! s:doImport(tagFnName, showList) abort "{{{
  silent exe 'normal mz'

  try
    call s:checkPythonSupport()
    let l:name = s:getWord()
    let l:rgx = s:determineImportType()
    call s:checkIfExists(l:name, l:rgx)
    let l:tagData = call('s:'.a:tagFnName, [l:name, l:rgx, a:showList])

    if l:tagData['global'] !=? ''
      return s:processImport(l:name, l:tagData['global'], l:rgx, 1)
    endif

    return s:importTag(l:tagData['tag'], l:name, l:rgx)
  catch /.*/
    silent exe 'normal! `z'
    if v:exception !=? ''
      return s:error(v:exception)
    endif
    return 0
  endtry
endfunction "}}}

function! s:getTagDataFromPrompt(name, rgx, ...) abort "{{{
  call inputsave()
  let l:path = input('Path to file or package name: ', '', 'file')
  call inputrestore()

  if l:path ==? ''
    throw 'No path entered.'
  endif

  let l:tagData = { 'global': '', 'tag': { 'filename': l:path, 'cmd': '', 'kind': '' } }
  let l:fullPath = getcwd().'/'.l:path

  if filereadable(l:fullPath)
    return l:tagData
  endif

  if s:isGlobalPackage(l:path)
    let l:tagData['global'] = l:path
    return l:tagData
  endif

  let l:choice = confirm('File or package not found. Import as:', "&File\n&Package\n&Cancel")
  if l:choice == 3
    throw ''
  elseif l:choice == 2
    let l:tagData['global'] = l:path
  endif

  return l:tagData
endfunction "}}}

function! s:getTag(name, rgx, showList) abort "{{{
  let l:tags = s:getTaglist(a:name, a:rgx)
  call filter(l:tags, function('s:removeTagsWithCurrentPath'))

  if len(l:tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      return { 'global': a:name }
    endif
    if g:js_file_import_prompt_if_no_tag
      echo 'No tag found. Falling back to prompt.'
      return s:getTagDataFromPrompt(a:name, a:rgx)
    endif
    throw 'No tag found.'
  endif

  if a:showList == 0 && len(l:tags) == 1
    return { 'tag': l:tags[0], 'global': s:checkIfGlobalTag(l:tags[0], a:name) }
  endif


  let l:tagSelectionList = s:generateTagSelectionlist(l:tags)
  let l:promptIndex = len(l:tagSelectionList) + 1
  let l:promptImport = [l:promptIndex.' - Enter path to file or package name manually']
  let l:options = ['Select file to import:'] + l:tagSelectionList + l:promptImport

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 1
    throw ''
  endif

  if l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  if l:selection == l:promptIndex
    return s:getTagDataFromPrompt(a:name, a:rgx)
  endif

  let l:selectedTag = l:tags[l:selection - 1]
  return { 'tag': l:selectedTag, 'global': s:checkIfGlobalTag(l:selectedTag, a:name) }
endfunction "}}}

function! s:getTaglist(name, rgx) abort "{{{
  let l:tags = taglist('^'.a:name.'$')
  call filter(l:tags, function('s:removeObsolete'))
  call s:appendTagsByFilename(l:tags, a:name, a:rgx)

  return l:tags
endfunction "}}}

function! s:getTagInCurrentFile(tags, currentFilePath) abort "{{{
  for l:tag in a:tags
    if fnamemodify(l:tag['filename'], ':p') ==? a:currentFilePath
      return l:tag
    endif
  endfor
  return { 'filename': '' }
endfunction "}}}

function! s:generateTagSelectionlist(tags) abort "{{{
  let l:index = 0
  let l:options = []

  for l:tag in a:tags
    let l:index += 1
    let l:cmd = l:tag['cmd'] !=? '' ? ' - ('.l:tag['cmd'].')' : ''
    call add(l:options, l:index.' - '.l:tag['filename'].' - '.l:tag['kind'].l:cmd)
  endfor

  return l:options
endfunction "}}}

function! s:isPartialImport(tag, name, rgx) "{{{
  let l:partialRgx = substitute(a:rgx['partialExport'], '__FNAME__', a:name, 'g')

  " Method or partial export
  if a:tag['kind'] =~# '\(m\|p\)' || a:tag['cmd'] =~# l:partialRgx
    return 1
  endif

  if a:tag['cmd'] =~# a:rgx['defaultExport'].a:name
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let l:filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(l:filePath)
    return 0
  endif

  if match(join(readfile(l:filePath, '')), l:partialRgx) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:getFilePath(filepath) abort "{{{
  let l:pyCommand = has('python3') ? 'py3' : 'py'
  let l:path = a:filepath

  silent exe l:pyCommand.' import vim, os.path'
  silent exe l:pyCommand.' currentPath = vim.eval("expand(''%:p:h'')")'
  silent exe l:pyCommand.' tagPath = vim.eval("fnamemodify(a:filepath, '':p'')")'
  silent exe l:pyCommand.' path = os.path.splitext(os.path.relpath(tagPath, currentPath))[0]'
  silent exe l:pyCommand.' leadingSlash = "./" if path[0] != "." else ""'
  silent exe l:pyCommand.' vim.command(''let l:path = "%s%s"'' % (leadingSlash, path))'

  return l:path
endfunction "}}}

function! s:processImport(name, path, rgx, ...) abort "{{{
  let l:importRgx = a:rgx['import']
  let l:importRgx = substitute(l:importRgx, '__FNAME__', a:name, '')
  let l:importRgx = substitute(l:importRgx, '__FPATH__', a:path, '')
  let l:appendToStart = 0

  if a:0 > 0 && g:js_file_import_package_first
    let l:appendToStart = 1
  endif

  if search(a:rgx['lastimport'], 'be') > 0 && l:appendToStart == 0
    call append(line('.'), l:importRgx)
  elseif search(a:rgx['lastimport']) > 0
    call append(line('.') - 1, l:importRgx)
  else
    call append(0, l:importRgx)
    call append(1, '')
  endif
  return s:finishImport()
endfunction "}}}

function! s:checkIfExists(name, rgx) abort "{{{
  let l:pattern = substitute(a:rgx['checkImportExists'], '__FNAME__', a:name, '')

  if search(l:pattern, 'n') > 0
    throw 'Import already exists.'
  endif

  return 0
endfunction "}}}

function! s:importTag(tag, name, rgx) abort "{{{
  let l:isPartial = s:isPartialImport(a:tag, a:name, a:rgx)
  let l:path = s:getFilePath(a:tag['filename'])
  let l:currentFilePath = s:getFilePath(expand('%:p'))

  if l:path ==# l:currentFilePath
    throw 'Import failed. Selected import is in this file.'
  endif

  let l:escapedPath = escape(l:path, './')

  if l:isPartial == 0
    return s:processFullImport(a:name, a:rgx, l:path)
  endif

  " Check if only full import exists for given path. ES6 allows partial imports alongside full import
  let l:existingFullPathOnly = substitute(a:rgx['existingFullPathOnly'], '__FPATH__', l:escapedPath, '')

  if a:rgx['type'] ==? 'import' && search(l:existingFullPathOnly, 'n') > 0
    call search(l:existingFullPathOnly, 'e')
    return s:processPartialImportAlongsideFull(a:name)
  endif

  "Partial single line
  let l:existingPathRgx = substitute(a:rgx['existingPath'], '__FPATH__', l:escapedPath, '')

  if search(l:existingPathRgx, 'n') <= 0
    return s:processImport('{ '.a:name.' }', l:path, a:rgx)
  endif

  call search(l:existingPathRgx)
  let l:startLine = line('.')
  call search(l:existingPathRgx, 'e')
  let l:endLine = line('.')

  if l:endLine > l:startLine
    return s:processMultiLinePartialImport(a:name)
  endif

  return s:processSingleLinePartialImport(a:name)
endfunction "}}}

function! s:processFullImport(name, rgx, path) abort "{{{
  let l:escPath = escape(a:path, './')
  let l:existingImportRgx = substitute(a:rgx['existingPathForFull'], '__FPATH__', l:escPath, '')

  if a:rgx['type'] ==? 'import' && search(l:existingImportRgx, 'n') > 0
    call search(l:existingImportRgx)
    silent exe ':normal!i'.a:name.', '
    return s:finishImport()
  endif

  return s:processImport(a:name, a:path, a:rgx)
endfunction "}}}

function! s:processSingleLinePartialImport(name) abort "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor ==? ',' ? ' ' : ', '
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:firstChar.a:name.lastChar

  return s:finishImport()
endfunction "}}}

function! s:processMultiLinePartialImport(name) abort "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor !=? ',' ? ',': ''
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:firstChar
  silent exe ':normal!o'.a:name.l:lastChar

  return s:finishImport()
endfunction "}}}

function! s:processPartialImportAlongsideFull(name) abort "{{{
  silent exe ':normal!a, { '.a:name.' }'

  return s:finishImport()
endfunction "}}}

function! s:determineImportType() abort "{{{
  let l:requireRegex = {
        \ 'type': 'require',
        \ 'checkImportExists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existingPath': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingFullPathOnly': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingPathForFull': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_.\{-\}require(.*;\?$',
        \ 'defaultExport': 'module.exports\s*=.\{-\}',
        \ 'partialExport': 'module.exports.\(\<__FNAME__\>\|\s*=\_[^{]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'selectForSort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'importName': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  let l:importRegex = {
        \ 'type': 'import',
        \ 'checkImportExists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existingPath': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existingFullPathOnly': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existingPathForFull': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': '^import\s\_.\{-\}from.*;\?$',
        \ 'defaultExport': 'export\s*default.\{-\}',
        \ 'partialExport': 'export\s*\(const\|var\|function\)\s*\<__FNAME__\>',
        \ 'selectForSort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'importName': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  if g:js_file_import_force_require || search(l:requireRegex['lastimport'], 'n') > 0
    return l:requireRegex
  endif

  return l:importRegex
endfunction "}}}

function! s:appendTagsByFilename(tags, name, rgx) abort "{{{
  let l:search = []
  call add(l:search, substitute(a:name, '\C\(\<\u[a-z0-9]\+\|[a-z0-9]\+\)\(\u\)', '\l\1_\l\2', 'g')) "snake case
  call add(l:search, substitute(a:name, '_\(\l\)', '\u\1', 'g')) "lower camel case
  call add(l:search, substitute(a:name, '\(\%(\<\l\+\)\%(_\)\@=\)\|_\(\l\)', '\u\1\2', 'g')) "upper camel case
  call uniq(l:search)

  for l:item in l:search
    call s:appendFilenameToTags(a:tags, l:item, a:rgx)
  endfor

  return a:tags
endfunction "}}}

function! s:appendFilenameToTags(tags, name, rgx) abort "{{{
  let l:files = []

  if executable('rg')
    let l:files = systemlist('rg -g "'.a:name.'.js*" --files .', a:name)
  elseif executable('ag')
    let l:files = systemlist('ag -g "(/|^)'.a:name.'.js.*"')
  elseif executable('ack')
    let l:files = systemlist('ack -g "(/|^)'.a:name.'.js.*"')
  else
    let l:files = [findfile(a:name.'.js', '**/*')]
    if a:rgx['type'] ==? 'import'
      call add(l:files, findfile(a:name.'.jsx', '**/*'))
    endif
  endif

  for l:file in l:files
    if l:file !=? '' && !s:tagsHasFilename(a:tags, l:file)
      call add(a:tags, { 'filename': l:file, 'name': a:name, 'kind': 'C', 'cmd': '' })
    endif
  endfor

  return a:tags
endfunction "}}}

function! s:tagsHasFilename(tags, filename) abort "{{{
  for l:tag in a:tags
    if l:tag['filename'] ==? a:filename
      return 1
    endif
  endfor

  return 0
endfunction "}}}

function! s:removeObsolete(idx, tag) abort "{{{
  if a:tag['filename'] =~? 'package.lock'
    return 0
  endif

  let l:filters = extend(['import\s*from', 'require('], g:js_file_import_filters)
  for l:filter in l:filters
    if a:tag['cmd'] =~? l:filter
      return 0
    endif
  endfor

  return 1
endfunction "}}}

function! s:removeTagsWithCurrentPath(idx, tag) abort "{{{
  if expand('%:p') ==? fnamemodify(a:tag['filename'], ':p')
    return 0
  endif

  return 1
endfunction "}}}

function! s:isGlobalPackage(name) abort "{{{
  let l:packageJson = getcwd().'/package.json'
  if !filereadable(l:packageJson)
    return 0
  endif

  let l:packageJsonData = readfile(l:packageJson, '')
  let l:data = json_decode(join(l:packageJsonData))

  if has_key(l:data, 'dependencies') && has_key(l:data['dependencies'], a:name)
    return 1
  endif

  if has_key(l:data, 'devDependencies') && has_key(l:data['devDependencies'], a:name)
    return 1
  endif

  return 0
endfunction "}}}

function! s:checkIfGlobalTag(tag, name) abort "{{{
  if a:tag['filename'] =~? 'package.json'
    return a:name
  endif
  return ''
endfunction "}}}

function! s:finishImport() abort "{{{
  if g:js_file_import_sort_after_insert > 0
    call jsfileimport#sort(1)
  endif

  silent exe 'normal! `z'
  return 1
endfunction "}}}

function! s:checkPythonSupport() abort "{{{
  if !has('python') && !has('python3')
    throw 'Vim js file import requires python or python3 support.'
  endif

  return 1
endfunction "}}}

function! s:getWord() abort "{{{
  let l:word = expand('<cword>')

  if l:word !~? '\(\d\|\w\)'
    throw 'Invalid word.'
  endif

  return l:word
endfunction "}}}

function! s:countWordInFile(word) abort "{{{
  redir => l:count
    silent exe '%s/\<' . a:word . '\>//gn'
  redir END

  let l:result = strpart(l:count, 0, stridx(l:count, ' '))
  return float2nr(str2float(l:result))
endfunction "}}}

function! s:error(msg) abort "{{{
  echohl Error
  echo a:msg
  echohl NONE
  return 0
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2
