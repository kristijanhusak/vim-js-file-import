let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)
let g:js_file_import_sort = get(g:, 'js_file_import_sort', "'{,'}-1sort i")
let g:js_file_import_sort_after_insert = get(g:, 'js_file_import_sort_after_insert', 0)
let g:js_file_import_prompt_if_no_tag = get(g:, 'js_file_import_prompt_if_no_tag', 1)

function! JsFileImport()
  return s:doImport('getTag')
endfunction

function! PromptJsFileImport()
  return s:doImport('getTagDataFromPrompt')
endfunction

function! SortJsFileImport(...)
  if a:0 == 0
    exe "normal mz"
  endif

  let rgx = s:determineImportType()

  if search(rgx['selectForSort'], 'be') > 0
    exe g:js_file_import_sort
  endif

  exe "normal! `z"
  return 1
endfunction

function! s:doImport(tagFnName) "{{{
  exe "normal mz"

  try
    call s:checkPythonSupport()
    let name = expand("<cword>")
    let rgx = s:determineImportType()
    call s:checkIfExists(name, rgx)
    let tagData = call('s:'.a:tagFnName, [name, rgx])

    if tagData['global'] != ''
      return s:processImport(name, tagData['global'], rgx)
    endif

    return s:importTag(tagData['tag'], name, rgx)
  catch /.*/
    exe "normal! `z"
    echo v:exception
    return 0
  endtry
endfunction "}}}

function! s:getTagDataFromPrompt(name, rgx) "{{{
  call inputsave()
  let path = input('File path: ', '', 'file')
  call inputrestore()

  if path == ''
    throw 'No path entered.'
  endif

  let tagData = { 'global': '', 'tag': { 'filename': path, 'cmd': '', 'kind': '' } }

  if !filereadable(getcwd().'/'.path)
    let choice = confirm('File not found. Import as:', "&Global package\n&Cancel")
    if choice == 2
      throw ''
    elseif choice == 1
      let tagData['global'] = path
    endif
  endif

  return tagData
endfunction "}}}

function! s:getTag(name, rgx) "{{{
  let tags = taglist("^".a:name."$")
  call filter(tags, function('s:removeObsolete'))

  if len(tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      return { 'global': a:name }
    endif
    if g:js_file_import_prompt_if_no_tag
      echo 'No tag found. Enter path to file from current working directory.'
      return s:getTagDataFromPrompt(a:name, a:rgx)
    endif
    throw 'No tag found.'
  endif

  if len(tags) == 1
    return { 'tag': tags[0], 'global': s:checkIfGlobalTag(tags[0], a:name) }
  endif

  let options = ['Select file to import:']
  let index = 0

  for tag in tags
    let index += 1
    call add(options, index.' - '.tag['filename'].' - '.tag['kind'].' - ('.tag['cmd'].')')
  endfor

  call inputsave()
  let selection = inputlist(options)
  call inputrestore()

  if selection > 0 && selection < len(options)
    let selectedTag = tags[selection - 1]
    return { 'tag': selectedTag, 'global': s:checkIfGlobalTag(selectedTag, a:name) }
  endif

  throw 'Wrong selection.'
endfunction "}}}

function! s:isPartialImport(tag, name, rgx) "{{{
  let full = { 'partial': 0, 'name': a:name }
  let partial = { 'partial': 1, 'name': a:name }
  let partialRgx = substitute(a:rgx['partialExport'], '__FNAME__', a:name, 'g')

  " Method or partial export
  if a:tag['kind'] =~ '\(m\|p\)' || a:tag['cmd'] =~ partialRgx
    return 1
  endif

  if a:tag['cmd'] =~ a:rgx['defaultExport'].a:name
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(filePath)
    return 0
  endif

  if match(join(readfile(filePath, '')), partialRgx) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:getFilePath(filepath) "{{{
  let pyCommand = has('python3') ? 'py3' : 'py'

  exe pyCommand.' import vim, os.path'
  exe pyCommand.' currentPath = vim.eval("expand(''%:p:h'')")'
  exe pyCommand.' tagPath = vim.eval("fnamemodify(a:filepath, '':p'')")'
  exe pyCommand.' path = os.path.splitext(os.path.relpath(tagPath, currentPath))[0]'
  exe pyCommand.' leadingSlash = "./" if path[0] != "." else ""'
  exe pyCommand.' vim.command(''let path = "%s%s"'' % (leadingSlash, path))'

  return path
endfunction "}}}

function! s:processImport(name, path, rgx) "{{{
  let importRgx = a:rgx['import']
  let importRgx = substitute(importRgx, '__FNAME__', a:name, '')
  let importRgx = substitute(importRgx, '__FPATH__', a:path, '')

  if search(a:rgx['lastimport'], 'be') > 0
    call append(line("."), importRgx)
  else
    call append(0, importRgx)
    call append(1, '')
  endif
  return s:finishImport()
endfunction "}}}

function! s:checkIfExists(name, rgx) "{{{
  let pattern = substitute(a:rgx['checkImportExists'], '__FNAME__', a:name, '')
  let partialPattern = substitute(a:rgx['checkPartialImportExists'], '__FNAME__', a:name, 'g')

  if search(pattern, 'n') > 0 || search(partialPattern, 'n') > 0
    throw "Import already exists."
  endif

  return 0
endfunction "}}}

function! s:checkIfFullImportExists(path, rgx) "{{{
  let pattern = substitute(a:rgx['checkFullImportExists'], '__FPATH__', a:path, '')

  if search(pattern, 'n') > 0
    throw "Full import already exists."
  endif

  return 0
endfunction "}}}

function! s:importTag(tag, name, rgx) "{{{
  let isPartial = s:isPartialImport(a:tag, a:name, a:rgx)
  let path = s:getFilePath(a:tag['filename'])
  let escapedPath = escape(path, './')

  if isPartial == 0
    return s:processImport(a:name, path, a:rgx)
  endif

  call s:checkIfFullImportExists(escapedPath, a:rgx)

  "Partial single line
  let existingPathRgx = substitute(a:rgx['existingPath'], '__FPATH__', escapedPath, '')
  let existingImport = search(existingPathRgx, 'e')

  if existingImport > 0
    return s:processSingleLinePartialImport(a:name)
  endif

  "Partial multi line
  let existingMultiLinePathRgx = substitute(a:rgx['existingMultiLinePath'], '__FPATH__', escapedPath, '')
  let existingMultiLineImport = search(existingMultiLinePathRgx, 'e')

  if existingMultiLineImport > 0
    return s:processMultiLinePartialImport(a:name)
  endif

  return s:processImport('{ '.a:name.' }', path, a:rgx)
endfunction "}}}

function! s:processSingleLinePartialImport(name) "{{{
  let charUnderCursor = getline('.')[col('.') - 1]
  let firstChar = charUnderCursor == ',' ? ' ' : ', '
  let lastChar = charUnderCursor == ',' ? ',' : ''

  exe ':normal!a'.firstChar.a:name.lastChar

  return s:finishImport()
endfunction "}}}

function! s:processMultiLinePartialImport(name) "{{{
  let charUnderCursor = getline('.')[col('.') - 1]
  let firstChar = charUnderCursor != ',' ? ',': ''
  let lastChar = charUnderCursor == ',' ? ',' : ''

  exe ':normal!a'.firstChar
  exe ':normal!o'.a:name.lastChar

  return s:finishImport()
endfunction "}}}

function! s:determineImportType() "{{{
  let requireRegex = {
        \ 'checkImportExists': '^\(const\|let\|var\)\s*\<__FNAME__\>\s*=\s*require(',
        \ 'checkPartialImportExists': '^\(const\|let\|var\)\s*{\(.\{-\}\<__FNAME__\>.*\|\n\_.\{-\}\<__FNAME__\>\_.\{-\}\)}\s*=\srequire(',
        \ 'checkFullImportExists': '^\(const\|let\|var\)\s*\<.\{-\}\>\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingPath': '^\(const\|let\|var\)\s*{\s*\zs.\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingMultiLinePath': '^\(const\|let\|var\)\s*{\s*\n\zs\_.\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_.\{-\}require(.*;\?$',
        \ 'defaultExport': '^module.exports\s*=.\{-\}',
        \ 'partialExport': 'module.exports.\(\<__FNAME__\>\|\s*=.\{-\}{.\{-\}\<__FNAME__\>.*}\|\s*=.\{-\}{\s*\n\_.\{-\}\<__FNAME__\>\_.*}\)',
        \ 'selectForSort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ }

  let importRegex = {
        \ 'checkImportExists': '^import\s*\<__FNAME__\>\s*from',
        \ 'checkPartialImportExists': '^import\s*{\(.\{-\}\<__FNAME__\>.*\|\n\_.\{-\}\<__FNAME__\>\_.\{-\}\)}\s*from',
        \ 'checkFullImportExists': '^import\s*\<.\{-\}\>\s*from\s[''"]__FPATH__[''"];\?$',
        \ 'existingPath': '^import\s*{\s*\zs.\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existingMultiLinePath': '^import\s*{\s*\n\zs\_.\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': '^import\s\_.\{-\}from.*;\?$',
        \ 'defaultExport': '^export\s*default.\{-\}',
        \ 'partialExport': 'export\s\(const\|var\|function\).\{-\}',
        \ 'selectForSort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ }

  if g:js_file_import_force_require || search(requireRegex['lastimport'], 'n') > 0
    return requireRegex
  endif

  return importRegex
endfunction "}}}

function! s:removeObsolete(idx, val) "{{{
  let v = a:val['cmd']
  let f = a:val['filename']
  if v =~ 'import\s*from' || v =~ 'require(' || f =~ 'package.lock'
    return 0
  endif

  return 1
endfunction "}}}

function! s:isGlobalPackage(name) "{{{
  let packageJson = getcwd().'/package.json'
  if !filereadable(packageJson)
    return 0
  endif

  let packageJsonData = readfile(packageJson, '')
  let data = json_decode(join(packageJsonData))

  if has_key(data, 'dependencies') && has_key(data['dependencies'], a:name)
    return 1
  endif

  if has_key(data, 'devDependencies') && has_key(data['devDependencies'], a:name)
    return 1
  endif

  return 0
endfunction "}}}

function! s:checkIfGlobalTag(tag, name) "{{{
  if a:tag['filename'] =~ 'package.json'
    return a:name
  endif
  return ''
endfunction "}}}

function! s:finishImport() "{{{
  if g:js_file_import_sort_after_insert > 0
    call SortJsFileImport(1)
  endif

  exe "normal! `z"
  return 1
endfunction "}}}

function! s:checkPythonSupport() "{{{
  if !has('python') && !has('python3')
    throw 'Vim js file import requires python or python3 support.'
  endif

  return 1
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2
