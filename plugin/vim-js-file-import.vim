let s:requireRegex = {
\ 'exist': '^\(const\|var\)\s*',
\ 'import': "const __FNAME__ = require('__FPATH__');",
\ 'lastimport': '^\(const\|var\)\s.*require(.*;\?',
\ 'defaultExport': 'module.exports\s*=.*',
\ 'partialExport': 'module.exports.',
\ }

let s:importRegex = {
\ 'exist': 'import\s*',
\ 'import': "import __FNAME__ from '__FPATH__';",
\ 'lastimport': 'import\s.*from.*;',
\ 'defaultExport': 'export\s*default.*',
\ 'partialExport': 'export\s\(const\|var\).*',
\ }

function! JsFileImport()
  exe "normal mz"
  let name = expand("<cword>")
  let rgx = s:determineImportType()

  try
    let tagData = s:getTag(name, rgx)

    if tagData['global']
      if search(rgx['exist'] . name . '.*;\?') > 0
        throw "Import already exists"
      endif
      call s:doImport(name, name, rgx)
      exe "normal! `z"
      return 1
    endif

    let tag = tagData['tag']
    let name = s:getImportName(tag, name, rgx)
    call s:checkIfExists(name, rgx)
  catch /.*/
    exe "normal! `z"
    echo v:exception
    return 0
  endtry

  let currentFilePath = expand('%:p:h')
  let tagFile = fnamemodify(tag['filename'], ':p')

  let path = system('python -c "import os.path; print os.path.relpath('''.tagFile.''', '''.currentFilePath.''')"')
  let path = fnamemodify(substitute(path, '\n\+$', '', ''), ':r')
  let firstChar = strpart(path, 0, 1)
  if  firstChar != '.' && firstChar != '/'
    let path = './'.path
  endif
  call s:doImport(name, path, rgx)
  exe "normal! `z"
  return 1
endfunction

function! s:removeObsolete(idx, val) "{{{
  let v = a:val['cmd']
  if v =~ 'import\s*from' || v =~ 'require('
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

function! s:getTag(name, rgx) "{{{
  let tags = taglist("^".a:name."$")
  let result = { 'tag': 0, 'global': 0 }
  call filter(tags, function('s:removeObsolete'))

  if len(tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      let result['global'] = 1
      return result
    endif
    throw 'No tag found!'
  endif

  if len(tags) == 1
    let result['tag'] = tags[0]
    return result
  endif

  let options = ['Select file to import:']
  let index = 0

  for tag in tags
    let index += 1
    call add(options, index . ' - ' . tag['filename'] . ' - '.tag['kind'].' - ('.tag['cmd'].')')
  endfor

  call inputsave()
  let selection = inputlist(options)
  call inputrestore()

  if selection > 0 && selection < len(options)
    let result['tag'] = tags[selection - 1]
    return result
  endif

  throw 'Wrong selection!'
endfunction "}}}

function! s:determineImportType() "{{{
  if search(s:requireRegex['lastimport']) > 0
    return s:requireRegex
  endif

  return s:importRegex
endfunction "}}}

function! s:doImport(name, path, rgx) "{{{
  let importRgx = a:rgx['import']
  let importRgx = substitute(importRgx, '__FNAME__', a:name, '')
  let importRgx = substitute(importRgx, '__FPATH__', a:path, '')

  if search(a:rgx['lastimport'], 'be') > 0
    call append(line("."), importRgx)
  else
    call append(0, importRgx)
  endif
endfunction "}}}

function! s:checkIfExists(name, rgx) "{{{
  let name = substitute(a:name, '\s', '\\s', 'g')

  if search(a:rgx['exist'] . name . '.*;\?') > 0
    throw "Import already exists"
  endif

  return 0
endfunction "}}}

function! s:getImportName(tag, name, rgx) "{{{
  let name = a:name
  let destructedName = '{ ' . a:name . ' }'

  " Method or partial export
  if a:tag['kind'] =~ '\(m\|p\)' || a:tag['cmd'] =~ a:rgx['partialExport']
    return destructedName
  endif

  if a:tag['cmd'] =~ a:rgx['defaultExport']
    return name
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(filePath)
    return name
  endif

  let fileContent = readfile(filePath, '')

  if match(fileContent, a:rgx['defaultExport'].name) > -1
    return name
  endif

  if match(fileContent, a:rgx['partialExport'].name) > -1
    return destructedName
  endif

  return name
endfunction "}}}

" vim:foldenable:foldmethod=marker
