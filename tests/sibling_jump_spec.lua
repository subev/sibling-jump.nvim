-- Tests for sibling_jump.lua
-- Run with: nvim --headless -c "PlenaryBustedFile tests/sibling_jump_spec.lua"

local eq = assert.are.same

describe("sibling_jump", function()
  local sibling_jump

  before_each(function()
    -- Reload module fresh for each test
    package.loaded["sibling_jump"] = nil
    sibling_jump = require("sibling_jump")

    -- Ensure we have a proper window for cursor operations
    if vim.api.nvim_list_wins()[1] == nil then
      vim.cmd("new")
    end
  end)

  after_each(function()
    -- Clean up any open buffers
    vim.cmd("bufdo! bwipeout!")
  end)

  describe("TypeScript type properties", function()
    it("jumps from one property to the next", function()
      -- Load fixture
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/type_properties.ts")
      vim.cmd("edit " .. fixture_path)
      local bufnr = vim.api.nvim_get_current_buf()

      -- Position cursor on contentUrl (line 4, col 4)
      vim.api.nvim_win_set_cursor(0, { 4, 4 })
      local initial_pos = vim.api.nvim_win_get_cursor(0)
      eq(4, initial_pos[1])

      -- Jump forward to slug
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(5, pos[1], "Should jump from contentUrl (L4) to slug (L5)")

      -- Jump forward to type
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(6, pos[1], "Should jump from slug (L5) to type (L6)")
    end)

    it("jumps backward between properties", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/type_properties.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at slug (line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 4 })

      -- Jump backward to contentUrl
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(4, pos[1], "Should jump from slug (L5) to contentUrl (L4)")
    end)

    it("stays at first property when jumping backward", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/type_properties.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at contentUrl (first property, line 4)
      vim.api.nvim_win_set_cursor(0, { 4, 4 })
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump backward (should be no-op)
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not move from first property")
    end)

    it("stays at last property when jumping forward", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/type_properties.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at description (last property, line 12)
      vim.api.nvim_win_set_cursor(0, { 12, 4 })
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump forward (should be no-op)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not move from last property")
    end)
  end)

  describe("JSX elements", function()
    it("jumps between sibling JSX elements", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start at HeaderContent (line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 8 })

      -- Jump to Header
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(9, pos[1], "Should jump from HeaderContent (L5) to Header (L9)")

      -- Jump to PersistentTabContainer
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(13, pos[1], "Should jump from Header (L9) to PersistentTabContainer (L13)")
    end)

    it("jumps backward between JSX elements", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start at Header (line 9)
      vim.api.nvim_win_set_cursor(0, { 9, 8 })

      -- Jump backward to HeaderContent
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(5, pos[1], "Should jump from Header (L9) to HeaderContent (L5)")
    end)

    it("stays at first JSX element when jumping backward", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start at HeaderContent (first element, line 5)
      vim.api.nvim_win_set_cursor(0, {5, 8})
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump backward (should be no-op)
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not move from first JSX element")
    end)
    
    it("does not jump to parent when inside child JSX element", function()
      -- This tests the bug where jumping from <DiscoverTab /> would jump to <PersistentTabContainer>
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start inside DiscoverTab (line 14), which is a child of PersistentTabContainer
      vim.api.nvim_win_set_cursor(0, {14, 10})
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump backward (should be no-op since DiscoverTab has no siblings)
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not jump to parent element when child has no siblings")
      
      -- Try to jump forward (also should be no-op)
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not jump to parent element when child has no siblings")
    end)
    
    it("jumps between non-self-closing JSX elements", function()
      -- Test navigation between elements with opening/closing tags like <TabContainer>...</TabContainer>
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start at PersistentTabContainer (line 13)
      vim.api.nvim_win_set_cursor(0, {13, 8})

      -- Jump forward to TabContainer (line 16)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(16, pos[1], "Should jump from PersistentTabContainer (L13) to TabContainer (L16)")

      -- Jump forward to AnotherContainer (line 19)
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(19, pos[1], "Should jump from TabContainer (L16) to AnotherContainer (L19)")
    end)
    
    it("jumps backward from non-self-closing JSX element", function()
      -- Test that cursor on opening tag can jump backward
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/jsx_elements.tsx")
      vim.cmd("edit " .. fixture_path)

      -- Start at TabContainer opening tag (line 16)
      vim.api.nvim_win_set_cursor(0, {16, 8})

      -- Jump backward to PersistentTabContainer
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(13, pos[1], "Should jump from TabContainer (L16) to PersistentTabContainer (L13)")
    end)
  end)

  describe("Destructuring patterns", function()
    it("jumps between destructured properties", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at currentTab: tab (line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 4 })

      -- Jump to setCurrentTab
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(6, pos[1], "Should jump from currentTab:tab (L5) to setCurrentTab (L6)")

      -- Jump to payload: tabPayload
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(7, pos[1], "Should jump from setCurrentTab (L6) to payload:tabPayload (L7)")
    end)

    it("jumps backward between destructured properties", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at setCurrentTab (line 6)
      vim.api.nvim_win_set_cursor(0, { 6, 4 })

      -- Jump backward to currentTab: tab
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(5, pos[1], "Should jump from setCurrentTab (L6) to currentTab:tab (L5)")
    end)
  end)

  describe("Basic statements", function()
    it("jumps between statement siblings", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/statements.ts")
      vim.cmd("edit " .. fixture_path)

      -- Force treesitter to parse the buffer
      local bufnr = vim.api.nvim_get_current_buf()
      vim.treesitter.get_parser(bufnr, "typescript"):parse()

      -- Start at const a (line 3)
      vim.api.nvim_win_set_cursor(0, { 3, 2 })

      -- Jump to const b
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(4, pos[1], "Should jump from const a (L3) to const b (L4)")

      -- Jump to const c
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(5, pos[1], "Should jump from const b (L4) to const c (L5)")

      -- Jump to if statement
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(7, pos[1], "Should jump from const c (L5) to if statement (L7)")
    end)

    it("jumps backward between statements", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/statements.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at const b (line 4)
      vim.api.nvim_win_set_cursor(0, { 4, 2 })

      -- Jump backward to const a
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(3, pos[1], "Should jump from const b (L4) to const a (L3)")
    end)
  end)

  describe("Function parameter destructuring with inline types", function()
    it("jumps between destructured parameter names (not type properties)", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at dateOfLastReminder parameter name (line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 4 })

      -- Jump forward to context parameter name (line 6)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(6, pos[1], "Should jump from dateOfLastReminder (L5) to context (L6)")
    end)

    it("jumps backward between destructured parameter names", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at context parameter name (line 6)
      vim.api.nvim_win_set_cursor(0, { 6, 4 })

      -- Jump backward to dateOfLastReminder parameter name (line 5)
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(5, pos[1], "Should jump from context (L6) to dateOfLastReminder (L5)")
    end)

    it("stays at first parameter when jumping backward", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at dateOfLastReminder (first parameter, line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 4 })
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump backward (should be no-op)
      sibling_jump.jump_to_sibling({ forward = false })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not move from first parameter")
    end)

    it("stays at last parameter when jumping forward", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at context (last parameter, line 6)
      vim.api.nvim_win_set_cursor(0, { 6, 4 })
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Try to jump forward (should be no-op, not jump to type properties)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(initial_pos[1], pos[1], "Should not move from last parameter (should not jump to type properties)")
    end)

    it("navigates between type properties separately from parameters", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at dateOfLastReminder type property (line 8)
      vim.api.nvim_win_set_cursor(0, { 8, 4 })

      -- Jump forward to context type property (line 9)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(9, pos[1], "Should jump from dateOfLastReminder type (L8) to context type (L9)")
    end)

    it("handles multiple parameters correctly", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at userId parameter (line 16)
      vim.api.nvim_win_set_cursor(0, { 16, 4 })

      -- Jump to timestamp
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(17, pos[1], "Should jump from userId (L16) to timestamp (L17)")

      -- Jump to metadata
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(18, pos[1], "Should jump from timestamp (L17) to metadata (L18)")
    end)

    it("handles mixed shorthand and renamed parameters", function()
      local fixture_path = vim.fn.expand("/Users/petur/dotfiles/tests/fixtures/function_param_destructuring.ts")
      vim.cmd("edit " .. fixture_path)

      -- Start at foo (shorthand, line 29)
      vim.api.nvim_win_set_cursor(0, { 29, 4 })

      -- Jump to bar: renamedBar (renamed, line 30)
      sibling_jump.jump_to_sibling({ forward = true })
      local pos = vim.api.nvim_win_get_cursor(0)
      eq(30, pos[1], "Should jump from foo (L29) to bar:renamedBar (L30)")

      -- Jump to baz (shorthand, line 31)
      sibling_jump.jump_to_sibling({ forward = true })
      pos = vim.api.nvim_win_get_cursor(0)
      eq(31, pos[1], "Should jump from bar:renamedBar (L30) to baz (L31)")
    end)
  end)
end)
