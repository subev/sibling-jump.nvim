-- Test fixture for complex Lua function navigation with nested structures
local M = {}

function M.setup(opts)
  opts = opts or {}
  
  local config = {
    key1 = opts.key1 or "default1",
    key2 = opts.key2 or "default2",
  }
  
  local filetypes = opts.filetypes or nil
  
  if filetypes then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function(ev)
        M.enable(ev.buf)
      end,
    })
    
    local current_ft = vim.bo.filetype
    if current_ft then
      M.enable(0)
    end
  else
    vim.keymap.set("n", "<C-j>", function()
      M.jump({ forward = true })
    end)
    
    vim.keymap.set("n", "<C-k>", function()
      M.jump({ forward = false })
    end)
  end
end

return M
