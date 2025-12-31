-- sibling_jump.lua
-- Navigate between sibling nodes at the same treesitter nesting level
--
-- Usage:
--   require("sibling_jump").setup({
--     next_key = '<C-j>',         -- Key for jumping to next sibling (default: <C-j>)
--     prev_key = '<C-k>',         -- Key for jumping to previous sibling (default: <C-k>)
--     center_on_jump = false,     -- Whether to center screen after each jump (default: false)
--   })

local config_module = require("sibling_jump.config")
local utils = require("sibling_jump.utils")
local navigation = require("sibling_jump.navigation")
local node_finder = require("sibling_jump.node_finder")
local method_chains = require("sibling_jump.special_modes.method_chains")
local if_else_chains = require("sibling_jump.special_modes.if_else_chains")
local switch_cases = require("sibling_jump.special_modes.switch_cases")
local positioning = require("sibling_jump.positioning")

local M = {}

-- Plugin configuration
local config = {
  center_on_jump = false, -- Whether to center screen (zz) after each jump
}

-- Stored configuration for manual buffer enable/disable
local stored_config = {
  next_key = "<C-j>",
  prev_key = "<C-k>",
}

-- Track which buffers have sibling-jump enabled
local enabled_buffers = {}

-- Alias utility functions for backward compatibility
local is_comment_node = utils.is_comment_node
local is_skippable_node = utils.is_skippable_node
local is_meaningful_node = utils.is_meaningful_node

-- Alias for backward compatibility
local get_sibling_node = navigation.get_sibling_node


-- Collect all else clauses in an if-else-if chain
-- Returns: list of else_clause nodes (in order from first to last)
-- Note: This is for JavaScript/TypeScript only. Lua uses a different approach.


-- Main jump function
function M.jump_to_sibling(opts)
  opts = opts or {}
  local forward = opts.forward ~= false -- Default to forward

  local bufnr = vim.api.nvim_get_current_buf()

  -- Repeat for count
  for _ = 1, vim.v.count1 do
    -- Get cursor position for chain detection
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]

    -- Get tree and node for chain detection
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if lang then
      local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
      if ok and parser then
        local tree = parser:parse()[1]
        if tree then
          local root = tree:root()
          local node = root:descendant_for_range(row, col, row, col)

          -- FIRST: Check if we're in a method chain
          if node then
            local in_chain, property_node = method_chains.detect(node)
            if in_chain then
              local target_prop = method_chains.navigate(property_node, forward)
              if target_prop then
                -- Successfully found target in chain
                vim.cmd("normal! m'")
                local target_row, target_col = target_prop:start()
                vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
                if config.center_on_jump then
                  vim.cmd("normal! zz")
                end
                -- Continue to next iteration for count support
                goto continue
              else
                -- At boundary of chain, do nothing (no-op)
                return
              end
            end

            -- SECOND: Check if we're in an if-else-if chain
            local in_if_else, if_node, current_pos = if_else_chains.detect(node)
            if in_if_else then
              local target_node, target_row, target_col = if_else_chains.navigate(if_node, current_pos, forward, get_sibling_node)
              if target_node then
                -- Successfully found target in if-else chain
                vim.cmd("normal! m'")
                vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
                if config.center_on_jump then
                  vim.cmd("normal! zz")
                end
                -- Continue to next iteration for count support
                goto continue
              end
              -- At boundary of chain, fall through to regular navigation
            end

            -- THIRD: Check if we're in a switch case chain
            local in_switch, switch_node, current_case_pos = switch_cases.detect(node)
            if in_switch then
              local target_node, target_row, target_col = switch_cases.navigate(switch_node, current_case_pos, forward)
              if target_node then
                -- Successfully found target in switch case chain
                vim.cmd("normal! m'")
                vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
                if config.center_on_jump then
                  vim.cmd("normal! zz")
                end
                -- Continue to next iteration for count support
                goto continue
              end
              -- At boundary of switch cases, fall through to regular navigation
            end
          end
        end
      end
    end

    -- FALLBACK: Use regular sibling/whitespace navigation
    local current_node, parent = node_finder.get_node_at_cursor(bufnr)

    if not current_node then
      -- Silently do nothing if no node found
      return
    end

    if not parent then
      -- At root level, can't have siblings
      return
    end

    -- Special case: if we're on whitespace, jump to the closest statement
    if type(current_node) == "table" and current_node._on_whitespace then
      local target_node = forward and current_node.closest_after or current_node.closest_before

      if target_node then
        -- Add current position to jump list before moving
        vim.cmd("normal! m'")

        -- Get the appropriate cursor position (adjusted for JSX elements)
        local target_row, target_col = positioning.get_target_position(target_node)
        vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col }) -- Convert back to 1-indexed

        -- Center the screen on the new position (if enabled)
        if config.center_on_jump then
          vim.cmd("normal! zz")
        end
      end
      -- Always return after handling whitespace (no sibling navigation)
      return
    end

    -- Special case: if we're on a comment or empty line, jump to nearest meaningful node
    if type(current_node) == "table" and current_node._on_comment then
      local target_node = forward and current_node.closest_after or current_node.closest_before

      if target_node then
        -- Add current position to jump list before moving
        vim.cmd("normal! m'")

        -- Get the appropriate cursor position (adjusted for JSX elements)
        local target_row, target_col = positioning.get_target_position(target_node)
        vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })

        -- Center the screen on the new position (if enabled)
        if config.center_on_jump then
          vim.cmd("normal! zz")
        end
      end
      -- Always return after handling comment escape (no sibling navigation)
      return
    end

    -- Find sibling node
    local target_node = get_sibling_node(current_node, parent, forward)

    -- Jump to target or do nothing (no notification)
    if target_node then
      -- Special case: if target is an if_statement with else clauses and we're going backward,
      -- jump to the last else clause instead of the if
      if not forward and target_node:type() == "if_statement" then
        -- Find the last else clause by walking through nested else-if chains
        local find_last_else
        find_last_else = function(if_node)
          for i = 0, if_node:child_count() - 1 do
            local child = if_node:child(i)
            if child:type() == "else_clause" then
              -- Found an else clause - check if it contains another if (else-if) or is final else
              for j = 0, child:child_count() - 1 do
                local grandchild = child:child(j)
                if grandchild:type() == "if_statement" then
                  -- This is else-if, recurse to find deeper else
                  return find_last_else(grandchild)
                end
              end
              -- No nested if found, this is the final else
              return child
            elseif child:type() == "elseif_statement" or child:type() == "else_statement" then
              -- Lua style - return the last one found
              local last = child
              for k = i + 1, if_node:child_count() - 1 do
                local next_child = if_node:child(k)
                if next_child:type() == "elseif_statement" or next_child:type() == "else_statement" then
                  last = next_child
                end
              end
              return last
            end
          end
          return nil
        end
        
        local last_else = find_last_else(target_node)
        if last_else then
          target_node = last_else
          target_row, target_col = last_else:start()
        end
      end

      -- Add current position to jump list before moving
      vim.cmd("normal! m'")

      -- Get the appropriate cursor position (adjusted for JSX elements)
      local target_row, target_col
      if not target_row then
        target_row, target_col = positioning.get_target_position(target_node)
      end
      vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col }) -- Convert back to 1-indexed

      -- Center the screen on the new position (if enabled)
      if config.center_on_jump then
        vim.cmd("normal! zz")
      end
    else
      -- No sibling found - just stop silently (no-op)
      return
    end

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
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

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

  -- Update configuration
  config.center_on_jump = opts.center_on_jump ~= nil and opts.center_on_jump or false

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

return M
