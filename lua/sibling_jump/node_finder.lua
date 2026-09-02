-- Node finder module for sibling-jump.nvim
-- Decides which node the cursor line stands for and which nodes it can jump between.
--
-- Grammar-agnostic: units are found by tree shape and position, never by node-type names.
--   1. Members of a list (a parent with `,`/`|` separators): navigate the list.
--   2. Otherwise the innermost node starting on the cursor line that has peers: children of its parent
--      at the same column (statements in a body, class members, switch entries), or for a line of a
--      chained expression, the chain's lines plus the chain's own statement peers.
--      A lone statement in a block has no peers, so navigation stays put.

local utils = require("sibling_jump.utils")

local M = {}

local LIST_SEPARATORS = { [","] = true, ["|"] = true }

local function is_separator(node)
  return node ~= nil and not node:named() and LIST_SEPARATORS[node:type()] == true
end

local function is_list_like(parent)
  for child in parent:iter_children() do
    if is_separator(child) then
      return true
    end
  end
  return false
end

local function same_start(a, b)
  local ar, ac = a:start()
  local br, bc = b:start()
  return ar == br and ac == bc
end

local function navigable_children(parent)
  local out = {}
  for child in parent:iter_children() do
    if child:named() and not utils.is_skippable_node(child) then
      table.insert(out, child)
    end
  end
  return out
end

-- Left-recursive lists (A | B | C parse as ((A | B) | C)) share their start; use the outermost one
local function outermost_list(list)
  while list:parent() and list:parent():type() == list:type() and is_list_like(list:parent())
    and same_start(list, list:parent()) do
    list = list:parent()
  end
  return list
end

-- Members of a list: named children next to a separator, nested same-type lists flattened
local function list_members(list, out)
  out = out or {}
  for child in list:iter_children() do
    if child:named() and not utils.is_skippable_node(child) then
      if child:type() == list:type() and is_list_like(child) and same_start(child, list) then
        list_members(child, out)
      elseif is_separator(child:prev_sibling()) or is_separator(child:next_sibling()) then
        table.insert(out, child)
      end
    end
  end
  return out
end

local is_line_leading = utils.is_line_leading

local function start_row(node)
  return (node:start())
end

-- Children of `parent` at the candidate's column that share its group. A line-leading token at a
-- smaller column (`}` before `else`) closes a group, so the two bodies of an if never count as peers.
-- Children on the parent's own first row are its header (a function's name, a call's callee) and are
-- excluded unless they start exactly where the parent starts, or the candidate is on that row.
local function statement_peers(candidate, parent)
  local cand_row, cand_col = candidate:start()
  local parent_row = parent:start()
  -- A node on its parent's first row that is not the parent's start is part of the header
  -- (`def name`, `<Tag`): whatever sits below at the same column is the body, not a peer
  if cand_row == parent_row and not same_start(candidate, parent) then
    return {}
  end
  local groups, group = {}, {}
  for child in parent:iter_children() do
    local row, col = child:start()
    if row ~= parent_row and col < cand_col and is_line_leading(child) and not utils.is_comment_node(child) then
      table.insert(groups, group)
      group = {}
    elseif child:named() and not utils.is_skippable_node(child) and col == cand_col then
      local header = row == parent_row and cand_row ~= parent_row and not same_start(child, parent)
      if not header then
        table.insert(group, child)
      end
    end
  end
  table.insert(groups, group)
  for _, g in ipairs(groups) do
    for _, member in ipairs(g) do
      if start_row(member) == cand_row then
        return g
      end
    end
  end
  return {}
end

-- A left-recursive chain (`a.b().c()` parses as call(nav(call(nav(a))))) is a run of nodes sharing one
-- start position whose types repeat. Returns that run, outermost first, or nil when `parent` is not
-- part of one. A body that merely starts at its first statement has no repeated types and is not a chain.
local function chain_column(parent)
  local run = {}
  local up = parent
  while up:parent() and same_start(up:parent(), up) do
    up = up:parent()
  end
  local cur = up
  while cur do
    table.insert(run, cur)
    local first = cur:named_child(0)
    cur = (first and same_start(first, cur)) and first or nil
  end
  local counts = {}
  for _, node in ipairs(run) do
    counts[node:type()] = (counts[node:type()] or 0) + 1
  end
  -- Trim the unique-typed ends: the body above the chain, the identifier it starts from
  local first, last = 1, #run
  while first <= last and counts[run[first]:type()] < 2 do
    first = first + 1
  end
  while last >= first and counts[run[last]:type()] < 2 do
    last = last - 1
  end
  local column, has_parent = {}, false
  for i = first, last do
    table.insert(column, run[i])
    has_parent = has_parent or run[i]:id() == parent:id()
  end
  if #column < 2 or not has_parent then
    return nil
  end
  return column
end

local function sorted_by_row(members)
  table.sort(members, function(a, b)
    return start_row(a) < start_row(b)
  end)
  return members
end

-- Nodes starting on `row`, from `node` outward
local function nodes_on_row(node, row)
  local list = {}
  local cur = node
  while cur and cur:parent() and start_row(cur) == row do
    table.insert(list, cur)
    cur = cur:parent()
  end
  return list
end

-- What the candidate navigates among: its statement peers, or for a line of a chain, the chain's
-- line-leading pieces merged with the statement peers of the statement the chain belongs to.
local function peers(candidate, parent)
  local column = chain_column(parent)
  if not column then
    return statement_peers(candidate, parent)
  end
  local rows, members = {}, {}
  local function add(node)
    local row = start_row(node)
    if not rows[row] then
      rows[row] = true
      table.insert(members, node)
    end
  end
  local root = column[1]
  for _, owner in ipairs(nodes_on_row(root, start_row(root))) do
    local statement_level = statement_peers(owner, owner:parent())
    if #statement_level > 1 then
      for _, peer in ipairs(statement_level) do
        add(peer)
      end
      break
    end
  end
  add(root)
  for _, node in ipairs(column) do
    for _, child in ipairs(navigable_children(node)) do
      if is_line_leading(child) then
        add(child)
      end
    end
  end
  return sorted_by_row(members)
end

-- The outermost node that ends on this row and began above it: what a lone closing token stands for
local function closed_node(node, row)
  local found = nil
  local cur = node:parent()
  while cur and cur:parent() do
    local sr, _, er = cur:range()
    if er == row and sr < row then
      found = cur
    elseif er > row then
      break
    end
    cur = cur:parent()
  end
  return found
end

local function has_named(nodes)
  for _, n in ipairs(nodes) do
    if n:named() then
      return true
    end
  end
  return false
end

-- Returns: unit node, its parent, and the list of nodes it navigates among
local function find_unit(node, row)
  -- On a separator, navigate as the member beside it on this line
  if is_separator(node) then
    local following, previous = node:next_named_sibling(), node:prev_named_sibling()
    if following and start_row(following) == row then
      node = following
    elseif previous and start_row(previous) == row then
      node = previous
    end
  end

  local candidates = nodes_on_row(node, row)
  if not has_named(candidates) then
    -- A lone token (`}`, `?`) stands for what follows it on the line, else for the node it closes
    local following = node:next_named_sibling()
    if following and start_row(following) == row then
      candidates = nodes_on_row(following, row)
    else
      local closed = closed_node(node, row)
      candidates = closed and { closed } or {}
    end
  end

  for _, c in ipairs(candidates) do
    local p = c:parent()
    if c:named() and is_list_like(p) and (is_separator(c:prev_sibling()) or is_separator(c:next_sibling())) then
      local list = outermost_list(p)
      local members = list_members(list)
      if #members > 1 then
        return c, list, members
      end
    end
  end

  -- Innermost first: a statement's own peers beat the two bodies of the `if` that contains it
  for _, c in ipairs(candidates) do
    if c:named() then
      local members = peers(c, c:parent())
      if #members > 1 then
        return c, c:parent(), members
      end
    end
  end

  return nil, "No navigable unit on this line"
end

-- Line-leading pieces of the chained expression `node` is, first to last; empty when it is not one
function M.chain_lines(node)
  local first = node:named_child(0)
  local column = (first and same_start(first, node)) and chain_column(first) or nil
  if not column or column[1]:id() ~= node:id() then
    return {}
  end
  local rows, lines = {}, {}
  for _, piece in ipairs(column) do
    for _, child in ipairs(navigable_children(piece)) do
      if is_line_leading(child) and not rows[start_row(child)] then
        rows[start_row(child)] = true
        table.insert(lines, child)
      end
    end
  end
  return sorted_by_row(lines)
end

-- On a blank line or a comment: offer the nearest navigable children of the enclosing container
local function marker(container, row, flag)
  local before, after
  for _, child in ipairs(navigable_children(container)) do
    local child_row = child:start()
    if child_row < row then
      before = child
    elseif child_row > row and not after then
      after = child
    end
  end
  if not before and not after then
    return nil, "Nothing to jump to from here"
  end
  return { [flag] = true, closest_before = before, closest_after = after, parent = container }, container
end

-- Get the navigation unit at the cursor
-- Returns: node, parent, members  |  marker table, container  |  nil, reason
function M.get_node_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  -- In leading whitespace, tree-sitter returns the enclosing block instead of the statement
  local first_nonws_col = utils.line_start_col(bufnr, row)
  if first_nonws_col >= 0 and col < first_nonws_col then
    col = first_nonws_col
  end

  local node = utils.get_node_at(bufnr, row, col)
  if not node then
    return nil, "No node at cursor"
  end
  if first_nonws_col < 0 then
    return marker(node, row, "_on_whitespace")
  end
  if utils.is_comment_node(node) then
    local container = node
    while container:parent() and utils.is_comment_node(container) do
      container = container:parent()
    end
    return marker(container, row, "_on_comment")
  end

  return find_unit(node, row)
end

return M
