if exists('g:loaded_js_file_import')
  finish
endif
let g:loaded_js_file_import = 1

let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)
let g:js_file_import_sort_command = get(g:, 'js_file_import_sort_command', "'{,'}-1sort i")
let g:js_file_import_sort_after_insert = get(g:, 'js_file_import_sort_after_insert', 0)
let g:js_file_import_prompt_if_no_tag = get(g:, 'js_file_import_prompt_if_no_tag', 1)
let g:js_file_import_package_first = get(g:, 'js_file_import_package_first', 1)
let g:js_file_import_no_mappings = get(g:, 'js_file_import_no_mappings', 0)
let g:js_file_import_filters = get(g:, 'js_file_import_filters', [])

command! JsFileImport call jsfileimport#word()
command! JsFileImportList call jsfileimport#word(1)
command! PromptJsFileImport call jsfileimport#prompt()
command! JsGotoDefinition call jsfileimport#goto()
command! JsGotoDefinitionList call jsfileimport#goto(1)
command! SortJsFileImport call jsfileimport#sort()
command! RemoveUnusedJsFileImports call jsfileimport#clean()
