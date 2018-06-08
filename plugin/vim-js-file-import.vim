if exists('g:loaded_js_file_import')
  finish
endif
let g:loaded_js_file_import = 1

let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)
let g:js_file_import_sort_command = get(g:, 'js_file_import_sort_command', "'{,'}-1sort i")
let g:js_file_import_sort_after_insert = get(g:, 'js_file_import_sort_after_insert', 0)
let g:js_file_import_prompt_if_no_tag = get(g:, 'js_file_import_prompt_if_no_tag', 1)
let g:js_file_import_package_first = get(g:, 'js_file_import_package_first', 1)
let g:js_file_import_omit_semicolon = get(g:, 'js_file_import_omit_semicolon', 0)
let g:js_file_import_no_mappings = get(g:, 'js_file_import_no_mappings', 0)
let g:js_file_import_filters = get(g:, 'js_file_import_filters', [])
let g:deoplete_strip_file_extension = get(g:, 'deoplete_strip_file_extension', 1)

command! JsFileImport call jsfileimport#word(0)
command! JsFileImportList call jsfileimport#word(0, 1)
command! PromptJsFileImport call jsfileimport#prompt()
command! JsGotoDefinition call jsfileimport#goto(0)
command! JsGotoDefinitionList call jsfileimport#goto(0, 1)
command! SortJsFileImport call jsfileimport#sort()
command! RemoveUnusedJsFileImports call jsfileimport#clean()
command! JsFindUsage call jsfileimport#findusage(0)

nnoremap <silent> <Plug>(JsFileImport) :<C-u>call jsfileimport#word(0)<CR>
xnoremap <silent> <Plug>(JsFileImport) :<C-u>call jsfileimport#word(1)<CR>

nnoremap <silent> <Plug>(JsFileImportList) :<C-u>call jsfileimport#word(0, 1)<CR>
xnoremap <silent> <Plug>(JsFileImportList) :<C-u>call jsfileimport#word(1, 1)<CR>

nnoremap <silent> <Plug>(JsGotoDefinition) :<C-u>call jsfileimport#goto(0)<CR>
xnoremap <silent> <Plug>(JsGotoDefinition) :<C-u>call jsfileimport#goto(1)<CR>

nnoremap <silent> <Plug>(JsGotoDefinitionList) :<C-u>call jsfileimport#goto(0, 1)<CR>
xnoremap <silent> <Plug>(JsGotoDefinitionList) :<C-u>call jsfileimport#goto(1, 1)<CR>

nnoremap <silent> <Plug>(JsFindUsage) :<C-u>call jsfileimport#findusage(0)<CR>
xnoremap <silent> <Plug>(JsFindUsage) :<C-u>call jsfileimport#findusage(1)<CR>

nnoremap <silent> <Plug>(SortJsFileImport) :<C-u>call jsfileimport#sort()<CR>
nnoremap <silent> <Plug>(RemoveUnusedJsFileImports) :<C-u>call jsfileimport#clean()<CR>
nnoremap <silent> <Plug>(PromptJsFileImport) :<C-u>call jsfileimport#prompt()<CR>
