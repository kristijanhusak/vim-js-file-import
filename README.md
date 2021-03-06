# Vim js file import

This plugin allows importing javascript and typescript files using ctags. Tested only with [Universal ctags](https://github.com/universal-ctags/ctags).
There is also [partial support for Vue](#vue-support).

It's similar to [vim-import-js](https://github.com/Galooshi/vim-import-js), but much faster because it's written in vimscript.

## Why?
I tried using [vim-import-js](https://github.com/Galooshi/vim-import-js), but it didn't fullfill all my expectations. This is the list of things that this plugin
handles, and [vim-import-js](https://github.com/Galooshi/vim-import-js) is missing:

* **Performance** - Importing is fast because everything is written in vimscript. No dependencies on any external CLI, only ctags which is used by most of people.
* **Only appends imports** - import-js replaces the content of whole buffer when importing, which can cause undesired results.
* **Importing files with different naming convention** - import-js doesn't find imports with different naming conventions. This plugin allows importing both snake_case and camelCase/CamelCase.
    This means that if you have a file named `big_button.js`, You can import it with these words: `BigButton`, `bigButton`, `big_button`
* **Smarter jump to definition** - Solves same naming convention issues mentioned above, and removes obsolete tags generated by universal-ctags when trying to find the definition.
* *[repeat.vim](https://github.com/tpope/vim-repeat) support
## Table of contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Examples](#examples)
* [Mappings](#mappings)
* [Goto definition](#goto-definition)
* [Sorting](#sorting)
* [Typedef imports](#typedef-imports) - Experimental
* [Removing unused imports](#removing-unused-imports)
* [Settings](#settings)
* [Deoplete strip file extension](#deoplete-strip-file-extension)
* [Contributing](#contributing)

### Requirements

* (N)vim with python support, any version (2 or 3) or `node` installed and available in `$PATH`
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
Plug 'kristijanhusak/vim-js-file-import', {'do': 'npm install'}
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

nnoremap <Leader>ic <Plug>(JsFixImport)
```

### Goto definition

To jump to definition use `<Leader>ig` mapping, or if you want to leverage built in
tag jumping functionality, use provided `tagfunc` (see `:help tagfunc`):
```vimL
set tagfunc=jsfileimport#tagfunc
```

### Sorting
To sort imports by the import path use `SortJsFileImport` mapping `<Leader>is`:

This:
```js
  import Foo from './file_path'
  import moment from 'moment'
```

Becomes this:
```js
  import moment from 'moment'
  import Foo from './file_path'
```

**Note**: Sorting is not behaving well when there are partial multi-line imports:
```js
 import {
    one,
    two,
    three
  } from 'four'
```
This is due to limitation with `:sort` command. If anyone know how to get around this, please open up an issue.

If you want imports to be always sorted, add `let g:js_file_import_sort_after_insert = 1` to your vimrc
and plugin will automatically sort imports after every insert

```vimL
let g:js_file_import_sort_after_insert = 1
```
### Typedef imports
**Note**: This is still experimental.

Import dependencies as typedefs. Example:

```javascript
// src/Models/User.js
class User {}


// index.js

/**          v cursor
 * @param {Us|er} user
 */
function main(user) {

}
```

Doing `JsFileImportTypedef` or pressing `<leader>it` will import the `User` as typedef:
```javascript
/**
 * @typedef {import('./src/Models/User')} User
 */

/**
 * @param {User} user
 */
function main(user) {
  // Lsp properly handles autocompletion for user now
}
```

### Removing unused imports

Unused imports can be cleared by ising command `JsFixImport` or mapping `<Leader>ic`.
It relies on eslint to figure out which imports are unused and clears them out.
Make sure to do `npm install` in the plugin directory.

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

Semicolons are added at the end of requires and imports. To disable this add this flag to settings:

```vimL
let g:js_file_import_omit_semicolon = 0
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

#### Using double quotes
If you want to use double quotes instead of single quotes, add this setting:
```vimL
let g:js_file_import_string_quote = '"'
```

#### Using FZF for prompts
By default, if there is a need for prompt (For example, to select from multiple import option),
native `inputlist()` is used. If you want to use [FZF](https://github.com/junegunn/fzf), add this setting:
```vimL
let g:js_file_import_use_fzf = 1
```

#### Using Telescope for prompts
By default, if there is a need for prompt (For example, to select from multiple import option),
native `inputlist()` is used. If you want to use [Telescope](https://github.com/nvim-telescope/telescope.nvim), add this setting:
```vimL
let g:js_file_import_use_telescope = 1
```

#### Importing from files with extension
If you want to import files with extension, add this setting:
```vimL
let g:js_file_import_strip_file_extension = 0
```

Check help docs for more information.


### Deoplete strip file extension
If you are using [deoplete.nvim](https://github.com/Shougo/deoplete.nvim) and it's file autocomplete to import files,
you probably noticed that the file extension is also part of the name when you autocomplete it,
so you need to remove it manually each time.
This plugin adds a small deoplete converter that strips that file extension out
of the completion word and shows it separately.
So instead of getting this in autocomplete:
```
user_service.js [F]
MyButton.jsx [F]
```
You get this:
```
user_service [F] [js]
MyButton [F] [jsx]
```

This is enabled by default (only for javascript and typescript syntax). To disable this option, add this to your vimrc:
```vimL
let g:deoplete_strip_file_extension = 0
```

### Vue support
There is some basic support for Vue:

1. Supports importing js/ts files into `*.vue` file `<script>` tag
2. Supports importing `.vue` file into another `.vue` file by matching filename. Imports may work better if custom ctags syntax file is used (https://gist.github.com/Fmajor/0024facc213087a3b4f296b50bf2c197)
3. Webpack alias support with this config:
```vim
let g:js_file_import_from_root = 1
let g:js_file_import_root = getcwd().'/src'
let g:js_file_import_root_alias = '@/'
```

### Performance issues
In case importing or jumping to definition is slow, make sure you have these set up:
* [ripgrep](https://github.com/BurntSushi/ripgrep), [silversearher](https://github.com/ggreer/the_silver_searcher) or [ack](https://linux.die.net/man/1/ack) installed. Used for finding files and directories with a matching name. If none of those are installed, falls back to vimscript `findfile()` which is much slower.
* `node_modules` excluded from `ctags` file and added to `wildignore` option:

  ```vimL
  set wildignore+=*node_modules/**
  ```
  If you use [gutentags](https://github.com/ludovicchabant/vim-gutentags) it will automatically read your `wildignore` so you don't have to worry about ctags part.

  More info on [issue #5](https://github.com/kristijanhusak/vim-js-file-import/issues/5)

### Contributing
There are no any special guidelines for contributing.

All types of contributions, suggestions and bug reports are very welcome!

### Thanks to:
* [Vim php namespace](https://github.com/arnaud-lb/vim-php-namespace) for inspiration and tests structure

