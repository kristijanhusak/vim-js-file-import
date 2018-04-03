if g:js_file_import_no_mappings
  finish
endif

if !hasmapto(':JsFileImport<CR>') && maparg('<Leader>if', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>if :JsFileImport<CR>
endif

if !hasmapto(':JsFileImportList<CR>') && maparg('<Leader>iF', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>iF :JsFileImportList<CR>
endif

if !hasmapto(':PromptJsFileImport<CR>') && maparg('<Leader>ip', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>ip :PromptJsFileImport<CR>
endif

if !hasmapto(':JsGotoDefinition<CR>') && maparg('<Leader>ig', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>ig :JsGotoDefinition<CR>
endif

if !hasmapto(':JsGotoDefinitionList<CR>') && maparg('<Leader>iG', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>iG :JsGotoDefinitionList<CR>
endif

if !hasmapto(':SortJsFileImport<CR>') && maparg('<Leader>is', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>is :SortJsFileImport<CR>
endif

if !hasmapto(':RemoveUnusedJsFileImports<CR>') && maparg('<Leader>ic', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>ic :RemoveUnusedJsFileImports<CR>
endif
