function! SourceFiles(path, extension)
  let path = expand(a:path)
  let files_found = system("find '" . path . "' -not -type l -name '*." . a:extension . "'")
  if empty(files_found)

  endif
  for FILE in split(files_found, '\n')
    exe 'source' FILE
  endfor
endfunction

" Call Plug with plugin name that is derived from
" the directory that it is located in
function! AddPlugins(path, extension)
  let path = expand(a:path)
  let files_found = system("find '" . path . "' -not -type l -name '*." . a:extension . "'")
  if empty(files_found)
    return
  endif
  for plugin in split(files_found, '\n')
    let plugin = substitute(plugin, a:path . '/', '', '')
    let plugin = substitute(plugin, '.' . a:extension, '', '')
    Plug plugin
  endfor
endfunction

let VIM_CONFIG_DIR=expand('~/.vim')
let VIM_CONFIG_FILE=expand('~/.vimrc')
let VIM_DATA_DIR=expand('~/.viminfo')
let HABITAT_DOTFILES=expand(__HABITAT_DOTFILES__)
let VIM_PLUGIN_EXTENSION='vimp'

" TODO: determine OS HERE? http://stackoverflow.com/questions/3373948/equivalents-of-xdg-config-home-and-xdg-data-home-on-mac-os-x
" so that we can define XDG on OSX etc?
if has('nvim') == '1'
  let XDG_CONFIG_HOME=$XDG_CONFIG_HOME
  let XDG_DATA_HOME=$XDG_DATA_HOME
  if !exists(XDG_CONFIG_HOME)
    let XDG_CONFIG_HOME=expand('~/.config')
  endif
  if !exists(XDG_DATA_HOME)
    let XDG_DATA_HOME=expand('~/.local/share')
  endif
  let VIM_CONFIG_DIR=expand(XDG_CONFIG_HOME . '/nvim')
  let VIM_CONFIG_FILE=expand(XDG_CONFIG_HOME . '/nvim/init.vim')
  let VIM_DATA_DIR=expand(XDG_DATA_HOME . '/nvim/shada/main.shada')
  let VIM_PLUGIN_EXTENSION='{nvimp,' . VIM_PLUGIN_EXTENSION . '}'
endif

let VIM_BUNDLE_DIR=VIM_CONFIG_DIR . '/plugins'

" Plugins
" TODO: use git over curl as we are forced to have it
let vim_plug_file=VIM_CONFIG_DIR . "/autoload/plug.vim"
let vim_plug_url='https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
if empty(glob(vim_plug_file))
  silent execute '!curl -fLo ' . vim_plug_file . ' --create-dirs ' . vim_plug_url
endif

if empty(glob(vim_plug_file))
  echo "vim-plug installation failed configuration is going to be messed up..."
else
  call plug#begin(VIM_BUNDLE_DIR)
  call AddPlugins(HABITAT_DOTFILES . '/vim/' . VIM_PLUGIN_EXTENSION , VIM_PLUGIN_EXTENSION)
  call plug#end()
  call SourceFiles(HABITAT_DOTFILES . '/vim/' . VIM_PLUGIN_EXTENSION, VIM_PLUGIN_EXTENSION)
endif

" Configuration
call SourceFiles(HABITAT_DOTFILES, 'vimc')

