local actions = require'telescope.actions'
local finders = require'telescope.finders'
local pickers = require'telescope.pickers'
local sorters = require'telescope.sorters'
local previewers = require'telescope.previewers'

local function picker(tags, prompt_text)
  for idx, tag in ipairs(tags) do
    tag.index = idx
  end
  pickers.new({}, {
    prompt_title = prompt_text,
    finder = finders.new_table {
      results = tags,
      entry_maker = function(tag)
        return {
          value = tag,
          ordinal = string.format('%d) %s', tag.index, tag.filename),
          display = string.format('%d) %s', tag.index, tag.filename),
          filename = tag.filename,
          scode = tag.cmd and tag.cmd ~= '' and tag.cmd:sub(3, -2) or nil,
          lnum = 1,
          col = 1
        }
      end
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function(_, _)
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)
        vim.defer_fn(function()
          vim.fn['jsfileimport#utils#trigger_inputlist_callback'](selection.index - 1)
        end, 10)
      end)
      return true
    end,
    previewer = previewers.ctags.new({}),
  }):find()
end


return {
  picker = picker
}
