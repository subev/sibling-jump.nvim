-- Block-loop: Navigate between structural boundaries (opening/closing) of code blocks
--
-- Cycles through block boundaries for:
-- - If/else/elseif chains
-- - For/while loops
-- - Object property values (property: methodChain())
-- - Call expressions (method/function calls)
-- - Declarations (const/let/var/function/type) with their value blocks
-- - Switch statements (switch → cases → default → closing)

local object_property_values = require("sibling_jump.block_loop.object_property_values")
local call_expressions = require("sibling_jump.block_loop.call_expressions")
local loops = require("sibling_jump.block_loop.loops")
local if_blocks = require("sibling_jump.block_loop.if_blocks")
local declarations = require("sibling_jump.block_loop.declarations")
local switch_cases = require("sibling_jump.block_loop.switch_cases")

local M = {}

local config = {
  center_on_jump = false,
}

function M.set_config(opts)
  config = vim.tbl_extend("force", config, opts)
end

-- Main entry point for block boundary jumping
function M.jump_to_boundary(opts)
  opts = opts or {}
  local mode = opts.mode or "normal"
  
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  
  -- Get treesitter node at cursor
  local node = M.get_node_at_cursor(bufnr, row, col)
  if not node then
    return  -- No-op
  end
  
  -- Try handlers in priority order
  -- Priority: object_property_values > call_expressions > switch_cases > loops > if_blocks > declarations
  -- This ensures more specific structures are detected before broader ones
  local handlers = {
    object_property_values,
    call_expressions,
    switch_cases,
    loops,
    if_blocks,
    declarations,
  }
  
  for _, handler in ipairs(handlers) do
    local detected, context = handler.detect(node, cursor)
    if detected then
      -- In visual mode, select the entire block from first to last position
      if mode == "visual" and context.positions and #context.positions >= 2 then
        M.select_block(context.positions)
        return
      end
      
      -- In normal mode, navigate to next position
      local target = handler.navigate(context, cursor, mode)
      if target then
        M.jump_to_position(target.row, target.col, mode)
        return
      end
    end
  end
  
  -- No supported block detected - no-op (silent)
end

-- Get treesitter node at cursor position
function M.get_node_at_cursor(bufnr, row, col)
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then return nil end
  
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then return nil end
  
  local tree = parser:parse()[1]
  if not tree then return nil end
  
  local root = tree:root()
  return root:descendant_for_range(row, col, row, col)
end

-- Jump to position with jump list and optional centering
function M.jump_to_position(row, col, mode)
  vim.cmd("normal! m'")  -- Add to jump list
  vim.api.nvim_win_set_cursor(0, { row, col })
  
  if config.center_on_jump then
    vim.cmd("normal! zz")
  end
end

-- Select entire block in visual mode (from first to last position)
function M.select_block(positions)
  if #positions < 2 then
    return
  end
  
  local first = positions[1]
  local last = positions[#positions]
  
  -- If already in visual mode, exit and re-enter to reset selection
  local current_mode = vim.api.nvim_get_mode().mode
  local was_visual = current_mode == 'v' or current_mode == 'V' or current_mode == '\22'
  
  if was_visual then
    -- Exit visual mode
    vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true))
  end
  
  -- Set cursor to first position
  vim.api.nvim_win_set_cursor(0, { first.row, first.col })
  
  -- Start visual mode
  vim.cmd('normal! v')
  
  -- Extend selection to last position
  vim.api.nvim_win_set_cursor(0, { last.row, last.col })
end

return M
