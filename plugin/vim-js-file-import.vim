if exists('g:loaded_js_file_import')
  finish
endif
let g:loaded_js_file_import = 1

let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)
let g:js_file_import_sort_command = get(g:, 'js_file_import_sort_command', '')
let g:js_file_import_sort_after_insert = get(g:, 'js_file_import_sort_after_insert', 0)
let g:js_file_import_prompt_if_no_tag = get(g:, 'js_file_import_prompt_if_no_tag', 1)
let g:js_file_import_package_first = get(g:, 'js_file_import_package_first', 1)
let g:js_file_import_omit_semicolon = get(g:, 'js_file_import_omit_semicolon', 0)
let g:js_file_import_no_mappings = get(g:, 'js_file_import_no_mappings', 0)
let g:js_file_import_filters = get(g:, 'js_file_import_filters', [])
let g:js_file_import_filename_filters = get(g:, 'js_file_import_filename_filters', [])
let g:js_file_import_sort_after_fix = get(g: ,'js_file_import_sort_after_fix', 0)
let g:js_file_import_from_root = get(g:, 'js_file_import_from_root', 0)
let g:js_file_import_root = get(g:, 'js_file_import_root', getcwd())
let g:js_file_import_root_alias = get(g:, 'js_file_import_root_alias', '')
let g:deoplete_strip_file_extension = get(g:, 'deoplete_strip_file_extension', 1)
let g:js_file_import_string_quote = get(g:, 'js_file_import_string_quote', "'")
let g:js_file_import_strip_file_extension = get(g:, 'js_file_import_strip_file_extension', 1)
let g:js_file_import_strip_index_file = get(g:, 'js_file_import_strip_index_file', 1)
let g:js_file_import_use_fzf = get(g:, 'js_file_import_use_fzf', 0)
let g:js_file_import_use_telescope = get(g:, 'js_file_import_use_telescope', 0)

if !g:js_file_import_from_root && !has('python') && !has('python3') && !executable('node')
  call jsfileimport#utils#_error('Vim js file import requires python/python3 support or node installed in $PATH.')
  finish
endif

command! -nargs=? JsFileImport call jsfileimport#word(0, 0, <q-args>)
command! -nargs=? JsFileImportList call jsfileimport#word(0, 1, <q-args>)
command! -nargs=? JsFileImportTypedef call jsfileimport#typedef(0, 0, <q-args>)
command! -nargs=? JsFileImportTypedefList call jsfileimport#typedef(0, 1, <q-args>)
command! PromptJsFileImport call jsfileimport#prompt()
command! -nargs=? JsGotoDefinition call jsfileimport#goto(0, 0, <q-args>)
command! -nargs=? JsGotoDefinitionList call jsfileimport#goto(0, 1, <q-args>)
command! SortJsFileImport call jsfileimport#sort()
command! JsFindUsage call jsfileimport#findusage(0)
command! JsFixImport call jsfileimport#fix_imports#exec()

nnoremap <silent> <Plug>(JsFileImport) :<C-u>call jsfileimport#word(0)<CR>
xnoremap <silent> <Plug>(JsFileImport) :<C-u>call jsfileimport#word(1)<CR>

nnoremap <silent> <Plug>(JsFileImportTypedef) :<C-u>call jsfileimport#typedef(0)<CR>
xnoremap <silent> <Plug>(JsFileImportTypedef) :<C-u>call jsfileimport#typedef(1)<CR>

nnoremap <silent> <Plug>(JsFileImportList) :<C-u>call jsfileimport#word(0, 1)<CR>
xnoremap <silent> <Plug>(JsFileImportList) :<C-u>call jsfileimport#word(1, 1)<CR>

nnoremap <silent> <Plug>(JsFileImportTypedefList) :<C-u>call jsfileimport#typedef(0, 1)<CR>
xnoremap <silent> <Plug>(JsFileImportTypedefList) :<C-u>call jsfileimport#typedef(1, 1)<CR>

nnoremap <silent> <Plug>(JsGotoDefinition) :<C-u>call jsfileimport#goto(0)<CR>
xnoremap <silent> <Plug>(JsGotoDefinition) :<C-u>call jsfileimport#goto(1)<CR>

nnoremap <silent> <Plug>(JsGotoDefinitionList) :<C-u>call jsfileimport#goto(0, 1)<CR>
xnoremap <silent> <Plug>(JsGotoDefinitionList) :<C-u>call jsfileimport#goto(1, 1)<CR>

nnoremap <silent> <Plug>(JsFindUsage) :<C-u>call jsfileimport#findusage(0)<CR>
xnoremap <silent> <Plug>(JsFindUsage) :<C-u>call jsfileimport#findusage(1)<CR>

nnoremap <silent> <Plug>(SortJsFileImport) :<C-u>call jsfileimport#sort()<CR>
nnoremap <silent> <Plug>(JsFixImport) :<C-u>call jsfileimport#fix_imports#exec()<CR>
nnoremap <silent> <Plug>(PromptJsFileImport) :<C-u>call jsfileimport#prompt()<CR>
