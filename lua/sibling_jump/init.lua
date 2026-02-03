-- sibling_jump.lua
-- Navigate between sibling nodes at the same treesitter nesting level
--
-- Usage:
--   require("sibling_jump").setup({
--     next_key = '<C-j>',         -- Key for jumping to next sibling (default: <C-j>)
--     prev_key = '<C-k>',         -- Key for jumping to previous sibling (default: <C-k>)
--     center_on_jump = false,     -- Whether to center screen after each jump (default: false)
--   })

local navigation = require("sibling_jump.navigation")
local node_finder = require("sibling_jump.node_finder")
local method_chains = require("sibling_jump.special_modes.method_chains")
local if_else_chains = require("sibling_jump.special_modes.if_else_chains")
local switch_cases = require("sibling_jump.special_modes.switch_cases")
local try_except_chains = require("sibling_jump.special_modes.try_except_chains")
local positioning = require("sibling_jump.positioning")
local handlers = require("sibling_jump.handlers")

local M = {}

-- Lazy-loaded block_loop module
local block_loop = nil

-- Plugin configuration
local config = {
  center_on_jump = false, -- Whether to center screen (zz) after each jump
}

-- Stored configuration for manual buffer enable/disable
local stored_config = {
  next_key = "<C-j>",
  prev_key = "<C-k>",
  block_loop_key = nil,
}

-- Track which buffers have sibling-jump enabled
local enabled_buffers = {}

-- Alias for backward compatibility
local get_sibling_node = navigation.get_sibling_node

-- Special navigation modes (in priority order)
-- Each mode has: detect(node) -> detected, context_data...
-- And: navigate(context_data..., forward) -> target_node, row, col | nil
local special_modes = {
  {
    name = "method_chains",
    detect = function(node)
      local in_chain, property_node = method_chains.detect(node)
      return in_chain, property_node
    end,
    navigate = function(property_node, forward)
      local target = method_chains.navigate(property_node, forward)
      if not target then return nil end
      return target, target:start()
    end,
    boundary_behavior = "no_op",
  },
  {
    name = "if_else_chains",
    detect = if_else_chains.detect,
    navigate = function(if_node, current_pos, forward)
      return if_else_chains.navigate(if_node, current_pos, forward, get_sibling_node)
    end,
    boundary_behavior = "fallthrough",
  },
  {
    name = "switch_cases",
    detect = switch_cases.detect,
    navigate = switch_cases.navigate,
    boundary_behavior = "fallthrough",
  },
  {
    name = "try_except_chains",
    detect = try_except_chains.detect,
    navigate = function(try_node, current_pos, forward)
      return try_except_chains.navigate(try_node, current_pos, forward, get_sibling_node)
    end,
    boundary_behavior = "fallthrough",
  },
}

-- Helper: Perform cursor jump with optional centering
local function perform_jump(row, col)
  vim.cmd("normal! m'") -- Add to jump list
  vim.api.nvim_win_set_cursor(0, { row + 1, col }) -- Convert 0-indexed to 1-indexed
  if config.center_on_jump then
    vim.cmd("normal! zz")
  end
end

-- Main jump function
function M.jump_to_sibling(opts)
  opts = opts or {}
  local forward = opts.forward ~= false

  local bufnr = vim.api.nvim_get_current_buf()

  -- Repeat for count
  for _ = 1, vim.v.count1 do
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]

    -- Get tree-sitter node at cursor (if available)
    local node = handlers.get_node_at_cursor(bufnr, row, col)

    -- Try special navigation modes (if node available)
    if node then
      for _, mode in ipairs(special_modes) do
        local detected, ctx1, ctx2 = mode.detect(node)
        if detected then
          local target_node, target_row, target_col
          -- Call navigate with the right number of args based on context
          if ctx2 ~= nil then
            -- Two context values (e.g., if_node, current_pos)
            target_node, target_row, target_col = mode.navigate(ctx1, ctx2, forward)
          else
            -- One context value (e.g., property_node)
            target_node, target_row, target_col = mode.navigate(ctx1, forward)
          end
          
          if target_node then
            -- Special mode found a target
            perform_jump(target_row, target_col)
            goto continue
          elseif mode.boundary_behavior == "no_op" then
            -- At boundary, stop here
            return
          end
          -- boundary_behavior == "fallthrough", continue to regular navigation
          break
        end
      end
    end

    -- Regular navigation: handle special cases first
    local current_node, parent = node_finder.get_node_at_cursor(bufnr)
    
    if not current_node or not parent then
      return -- No node or at root level
    end

    -- Handle whitespace
    local whitespace_result = handlers.handle_whitespace(current_node, forward, positioning)
    if whitespace_result then
      if whitespace_result == "no_op" then
        return
      end
      perform_jump(whitespace_result.row, whitespace_result.col)
      return
    end

    -- Handle comments
    local comment_result = handlers.handle_comment(current_node, forward, positioning)
    if comment_result then
      if comment_result == "no_op" then
        return
      end
      perform_jump(comment_result.row, comment_result.col)
      return
    end

    -- Find sibling node
    local target_node = get_sibling_node(current_node, parent, forward)
    if not target_node then
      return -- No sibling found
    end

    -- Adjust entry point for compound statements
    local adjusted_node, adjusted_row, adjusted_col = 
      handlers.adjust_entry_point(target_node, forward, node, if_else_chains, switch_cases)
    
    local target_row, target_col = adjusted_row, adjusted_col
    if not target_row then
      target_row, target_col = positioning.get_target_position(adjusted_node or target_node)
    end
    
    perform_jump(target_row, target_col)

    ::continue::
  end
end

-- Enable sibling-jump for a specific buffer
function M.enable_for_buffer(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}
  local silent = opts.silent or false

  -- Check if already enabled
  if enabled_buffers[bufnr] then
    if not silent then
      vim.notify("sibling-jump already enabled for this buffer", vim.log.levels.INFO)
    end
    return
  end

  -- Set buffer-local keymaps
  vim.keymap.set("n", stored_config.next_key, function()
    M.jump_to_sibling({ forward = true })
  end, { buffer = bufnr, noremap = true, silent = true, desc = "Jump to next sibling node" })

  vim.keymap.set("n", stored_config.prev_key, function()
    M.jump_to_sibling({ forward = false })
  end, { buffer = bufnr, noremap = true, silent = true, desc = "Jump to previous sibling node" })

  -- Mark as enabled
  enabled_buffers[bufnr] = true

  if not silent then
    vim.notify("sibling-jump enabled for buffer " .. bufnr, vim.log.levels.INFO)
  end
end

-- Disable sibling-jump for a specific buffer
function M.disable_for_buffer(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}
  local silent = opts.silent or false

  -- Check if not enabled
  if not enabled_buffers[bufnr] then
    if not silent then
      vim.notify("sibling-jump not enabled for this buffer", vim.log.levels.WARN)
    end
    return
  end

  -- Delete buffer-local keymaps
  pcall(vim.keymap.del, "n", stored_config.next_key, { buffer = bufnr })
  pcall(vim.keymap.del, "n", stored_config.prev_key, { buffer = bufnr })

  -- Mark as disabled
  enabled_buffers[bufnr] = nil

  if not silent then
    vim.notify("sibling-jump disabled for buffer " .. bufnr, vim.log.levels.INFO)
  end
end

-- Toggle sibling-jump for a specific buffer
function M.toggle_for_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if enabled_buffers[bufnr] then
    M.disable_for_buffer(bufnr)
  else
    M.enable_for_buffer(bufnr)
  end
end

-- Check status of sibling-jump for a specific buffer
function M.status_for_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local status = enabled_buffers[bufnr] and "enabled" or "disabled"
  local filetype = vim.bo[bufnr].filetype

  vim.notify(
    string.format("sibling-jump: %s for buffer %d (filetype: %s)", status, bufnr, filetype),
    vim.log.levels.INFO
  )

  return enabled_buffers[bufnr] ~= nil
end

-- Setup function to configure keymaps
function M.setup(opts)
  opts = opts or {}

  -- Store configuration for manual buffer enable/disable
  stored_config.next_key = opts.next_key or "<C-j>"
  stored_config.prev_key = opts.prev_key or "<C-k>"
  stored_config.block_loop_key = opts.block_loop_key or nil

  -- Update configuration
  config.center_on_jump = opts.center_on_jump ~= nil and opts.center_on_jump or false
  
  -- Setup block-loop feature if key is configured
  if opts.block_loop_key then
    -- Lazy load block_loop module
    block_loop = require("sibling_jump.block_loop")
    
    -- Block-loop can have separate center_on_jump setting
    local block_loop_center = opts.block_loop_center_on_jump
    if block_loop_center == nil then
      -- Default: use main center_on_jump setting
      block_loop_center = config.center_on_jump
    end
    block_loop.set_config({ center_on_jump = block_loop_center })
    
    -- Normal mode keymap
    vim.keymap.set("n", opts.block_loop_key, function()
      block_loop.jump_to_boundary({ mode = "normal" })
    end, { noremap = true, silent = true, desc = "Jump to block boundary" })
    
    -- Visual mode keymap
    vim.keymap.set("v", opts.block_loop_key, function()
      block_loop.jump_to_boundary({ mode = "visual" })
    end, { noremap = true, silent = true, desc = "Jump to block boundary (visual)" })
  end

  local filetypes = opts.filetypes or nil -- Optional filetype restriction

  -- If filetypes are specified, use FileType autocommand for buffer-local keymaps
  if filetypes then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function(ev)
        M.enable_for_buffer(ev.buf, { silent = true })
      end,
      desc = "Set sibling-jump keymaps for specific filetypes",
    })

    -- Also set for current buffer if it matches
    local current_ft = vim.bo.filetype
    if current_ft and vim.tbl_contains(filetypes, current_ft) then
      M.enable_for_buffer(0, { silent = true })
    end
  else
    -- No filetype restriction: set global keymaps (original behavior)
    vim.keymap.set("n", stored_config.next_key, function()
      M.jump_to_sibling({ forward = true })
    end, { noremap = true, silent = true, desc = "Jump to next sibling node" })

    vim.keymap.set("n", stored_config.prev_key, function()
      M.jump_to_sibling({ forward = false })
    end, { noremap = true, silent = true, desc = "Jump to previous sibling node" })
  end

  -- Create user commands for manual buffer control
  vim.api.nvim_create_user_command("SiblingJumpBufferEnable", function()
    M.enable_for_buffer()
  end, { desc = "Enable sibling-jump for current buffer" })

  vim.api.nvim_create_user_command("SiblingJumpBufferDisable", function()
    M.disable_for_buffer()
  end, { desc = "Disable sibling-jump for current buffer" })

  vim.api.nvim_create_user_command("SiblingJumpBufferToggle", function()
    M.toggle_for_buffer()
  end, { desc = "Toggle sibling-jump for current buffer" })

  vim.api.nvim_create_user_command("SiblingJumpBufferStatus", function()
    M.status_for_buffer()
  end, { desc = "Check sibling-jump status for current buffer" })
end

-- Expose block_loop for manual access (lazy-loaded)
function M.block_loop()
  if not block_loop then
    block_loop = require("sibling_jump.block_loop")
  end
  return block_loop
end

return M
