# Vim js file import

This plugin allows importing js files using ctags. Tested only with [Universal ctags](https://github.com/universal-ctags/ctags).

It's similar to [vim-import-js](https://github.com/Galooshi/vim-import-js), but much faster because it's written in vimscript.

## Why?
I tried using [vim-import-js](https://github.com/Galooshi/vim-import-js), but it didn't fullfill all my expectations. This is the list of things that this plugin
handles, and [vim-import-js](https://github.com/Galooshi/vim-import-js) is missing:

* **Performance** - Importing is fast because everything is written in vimscript. No dependencies on any external CLI, only ctags which is used by most of people.
* **Only appends imports** - import-js replaces the content of whole buffer when importing, which can cause undesired results.
* **Importing files with different naming convention** - import-js doesn't find imports with different naming conventions. This plugin allows importing both snake_case and camelCase/CamelCase.
    This means that if you have a file named `big_button.js`, You can import it with these words: `BigButton`, `bigButton`, `big_button`
* **Smarter jump to definition** - Solves same naming convention issues mentioned above, and removes obsolete tags generated by universal-ctags when trying to find the definition.

## Table of contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Examples](#examples)
* [Mappings](#mappings)
* [Goto definition](#goto-definition)
* [Sorting](#sorting)
* [Settings](#settings)
* [Contributing](#contributing)

### Requirements

* (N)vim with python support, any version (2 or 3)
* [Universal ctags](https://github.com/universal-ctags/ctags)
* Tested only on Neovim and Vim8+

### Installation

Install [Universal ctags](https://github.com/universal-ctags/ctags)
```sh
$ git clone https://github.com/universal-ctags/ctags
$ cd ctags && ./autogen.sh && ./configure && make && sudo make install
```

It's also recommended to install some plugin for auto-updating ctags, since this plugin heavily relies on it.
[gutentags](https://github.com/ludovicchabant/vim-gutentags) is good choice.

Add plugin to vimrc
```vimL
Plug 'ludovicchabant/vim-gutentags'
Plug 'kristijanhusak/vim-js-file-import'
```

### Examples
```js
import React from 'react';

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

Setting cursor on `MyButton` and pressing `<Leader>if` finds the component and adds import at top

```js
import React from 'react'
import MyButton from './components/MyButton'

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

By default `import <name> from <file>` is used. If file contains any `const <name> = require(<file>)`,
import will be added like that.

```js
const React = require('react')
const MyButton = require('./components/MyButton');

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

Partial imports are also handled (`import { <name> } from <file>`)

```js
import { MyButton } from './components/AllComponents';

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

### Mappings

By default, following mappings are used if they are not already taken:

```vimL
nnoremap <Leader>if <Plug>(JsFileImport)

nnoremap <Leader>iF <Plug>(JsFileImportList)

nnoremap <Leader>ig <Plug>(JsGotoDefinition)

nnoremap <Leader>iG <Plug>(JsGotoDefinition)

nnoremap <Leader>ip <Plug>(PromptJsFileImport)

nnoremap <Leader>is <Plug>(SortJsFileImport)

nnoremap <Leader>ic <Plug>(RemoveUnusedJsFileImports)
```

### Goto definition

To jump to definition use `<Leader>ig` mapping.
It is much smarter than default (n)vim `tag <word>` jump.

### Sorting

To sort imports alphabetically use `SortJsFileImport` mapping `<Leader>is`:

This:
```js
  import Foo from './file_path'
  import Bar from './another_file_path'
```

Becomes this:
```js
  import Bar from './another_file_path'
  import Foo from './file_path'
```

If you want imports to be always sorted, add `let g:js_file_import_sort_after_insert = 1` to your vimrc
and plugin will automatically sort imports after every insert

```vimL
let g:js_file_import_sort_after_insert = 1
```

### Settings

In case tag is not found for the given word, you will be prompted to enter the file path manually.
Path needs to be selected from the current (n)vim working directory. Plugin will take care of determining
if it's full or partial import.

To disable this option, set `g:js_file_import_prompt_if_no_tag` to `0`:

```vimL
let g:js_file_import_prompt_if_no_tag = 0
```

You can use prompt whenever you want with mapping `<Leader>ip`

By default `import [name] from [file]` is used to add new imports, in case when there are no any other existing imports.
If file contains at least one `require([file])`, it will use the `require()` to import files.

To force using `require()` always, add this flag to settings:

```vimL
let g:js_file_import_force_require = 1
```

Absolute imports (packages) are always imported first, which is recommended by most style guides.
To import package the same way as files (last), add this flag to settings:

```vimL
let g:js_file_import_package_first = 0
```


#### Overriding mappings
If you want to use different mappings, you can disable them all with this setting:
```vimL
let g:js_file_import_no_mappings = 1
```

And then add your mappings like this:

```vimL
nmap <C-i> <Plug>(JsFileImport)
nmap <C-u> <Plug>(PromptJsFileImport)
```

Check help docs for more information.

### Contributing
There are no any special guidelines for contributing.

All types of contributions, suggestions and bug reports are very welcome!

### Thanks to:
* [Vim php namespace](https://github.com/arnaud-lb/vim-php-namespace) for inspiration and tests structure

