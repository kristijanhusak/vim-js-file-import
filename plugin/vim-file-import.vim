let s:requireRegex = {
\ 'exist': '^\(const\|var\)\s*',
\ 'import': "const __FNAME__ = require('__FPATH__');",
\ 'lastimport': '^\(const\|var\)\s.*require(.*;'
\ }

let s:importRegex = {
\ 'exist': 'import\s*',
\ 'import': "import __FNAME__ from '__FPATH__';",
\ 'lastimport': 'import\s.*from.*;'
\ }

function! s:getTag(name)
  let tags = taglist("^".a:name."$")
  let foundTag = 0

  for tag in tags
    if tag['cmd'] =~ 'class\s'.a:name || tag['cmd'] =~ 'export default.*'.a:name
      let foundTag = tag
      break
    endif
  endfor

  if foundTag isnot 0
    return { 'tag': foundTag, 'defaultExport': 1 }
  endif

  for tag in tags
    if tag['cmd'] =~ 'export\s\(const\|var\).*'.a:name || tag['cmd'] =~ 'module.exports.'.a:name
      let foundTag = tag
      break
    endif
  endfor

  if foundTag isnot 0
    return { 'tag': foundTag, 'defaultExport': 0 }
  endif

  return { 'tag': 0 }
endfunction

function! s:determineImportType()
  if search(s:requireRegex['lastimport']) > 0
    return s:requireRegex
  endif

  return s:importRegex
endfunction

function! FileImport()
  exe "normal mz"
  let name = expand("<cword>")
  let rgx = s:determineImportType()
  let tagData = s:getTag(name)

  try
    if tagData['tag'] is 0
      throw 'Tag not found'
    endif

    let regexNameExists = name
    if tagData['defaultExport'] == 0
      let regexNameExists = '{\s\?' . name . '\s\?}'
      let name = '{ ' . name . ' }'
    endif

    if search(rgx['exist'] . regexNameExists . '.*;') > 0
      throw "Import already exists"
    endif
  catch /.*/
    exe "normal! `z"
    echo v:exception
    return
  endtry

  let currentFilePath = expand('%:p:h')
  let tagFile = fnamemodify(tagData['tag']['filename'], ':p')

  let path = system('python -c "import os.path; print os.path.relpath('''.tagFile.''', '''.currentFilePath.''')"')
  let path = fnamemodify(substitute(path, '\n\+$', '', ''), ':r')
  let firstChar = strpart(path, 0, 1)
  if  firstChar != '.' && firstChar != '/'
    let path = './'.path
  endif
  let importRgx = rgx['import']
  let importRgx = substitute(importRgx, '__FNAME__', name, '')
  let importRgx = substitute(importRgx, '__FPATH__', path, '')

  if search(rgx['lastimport'], 'be') > 0
    call append(line("."), importRgx)
  else
    call append(0, importRgx)
  endif
  exe "normal! `z"
endfunction
