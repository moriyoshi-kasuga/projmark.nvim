local M = {}

local default_config = {
  data_file = vim.fn.stdpath("data") .. "/projmark.json",
  project_root_order = { "git", "lsp" },
}

local config = vim.deepcopy(default_config)

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "projmark" })
end

local function format_error(err)
  if err == nil then
    return "unknown error"
  end
  local text = tostring(err):gsub("\n.*", "")
  return text ~= "" and text or "unknown error"
end

local function run_vim_cmd(cmd, context)
  local ok, err = pcall(vim.cmd, cmd)
  if not ok then
    notify((context or "command failed") .. ": " .. format_error(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function read_json_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end
  if not lines or #lines == 0 then
    return {}
  end
  local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not ok_decode then
    return {}
  end
  if type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function write_json_file(path, data)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local ok, encoded = pcall(vim.fn.json_encode, data)
  if not ok then
    return false
  end
  local ok_write, _ = pcall(vim.fn.writefile, { encoded }, path)
  return ok_write
end

local function get_lsp_root()
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf })
  for _, client in ipairs(clients) do
    local root = client.config.root_dir
    if type(root) == "string" and root ~= "" then
      return root
    end
  end
  return nil
end

local function get_git_root()
  local file = vim.fn.expand("%:p")
  if file == "" then
    return nil
  end
  local dir = vim.fn.fnamemodify(file, ":p:h")
  while dir and dir ~= "" do
    local git_dir = dir .. "/.git"
    if vim.fn.isdirectory(git_dir) == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

local function get_project_root()
  for _, source in ipairs(config.project_root_order) do
    if source == "git" then
      local git_root = get_git_root()
      if git_root then
        return git_root
      end
    elseif source == "lsp" then
      local lsp_root = get_lsp_root()
      if lsp_root then
        return lsp_root
      end
    end
  end
  return nil
end

local function load_state()
  return read_json_file(config.data_file)
end

local function save_state(state)
  return write_json_file(config.data_file, state)
end

local function save_state_or_notify(state)
  if not save_state(state) then
    notify("failed to save projmark state", vim.log.levels.ERROR)
  end
end

local function get_project_state(state, root)
  state[root] = state[root] or {}
  return state[root]
end

local function is_lowercase_mark(mark)
  return type(mark) == "string" and mark:match("^[a-z]$") ~= nil
end

local function is_uppercase_mark(mark)
  return type(mark) == "string" and mark:match("^[A-Z]$") ~= nil
end

local function with_project_root(fn)
  local root = get_project_root()
  if not root then
    notify("project root not found", vim.log.levels.ERROR)
    return nil
  end
  return fn(root)
end

local function handle_uppercase_mark(mark, command, is_cmd)
  if not is_uppercase_mark(mark) then
    return false
  end
  if is_cmd then
    run_vim_cmd(command .. " " .. mark, "failed to execute command for mark " .. mark)
  else
    run_vim_cmd("normal! " .. command .. mark, "failed to execute motion for mark " .. mark)
  end
  return true
end

local function set_project_mark(mark)
  if handle_uppercase_mark(mark, "m") then
    return
  end
  if not is_lowercase_mark(mark) then
    return
  end

  with_project_root(function(root)
    local state = load_state()
    local project = get_project_state(state, root)

    local file = vim.fn.expand("%:p")
    if file == "" then
      notify("current buffer has no file", vim.log.levels.ERROR)
      return
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    project[mark] = {
      file = file,
      line = pos[1],
      col = pos[2],
    }

    save_state_or_notify(state)
  end)
end

local function delete_project_mark(mark)
  if handle_uppercase_mark(mark, "delmarks", true) then
    return
  end
  if not is_lowercase_mark(mark) then
    return
  end

  with_project_root(function(root)
    local state = load_state()
    local project = state[root]
    if not project or not project[mark] then
      return
    end
    project[mark] = nil
    if next(project) == nil then
      state[root] = nil
    end
    save_state_or_notify(state)
  end)
end

local function goto_project_mark(mark)
  if handle_uppercase_mark(mark, "'") then
    return
  end
  if not is_lowercase_mark(mark) then
    run_vim_cmd("normal! '" .. mark, "failed to jump to mark " .. mark)
    return
  end

  with_project_root(function(root)
    local state = load_state()
    local project = state[root]
    if not project or not project[mark] then
      notify("mark not set", vim.log.levels.ERROR)
      return
    end

    local target = project[mark]
    local file = target.file
    if vim.fn.filereadable(file) ~= 1 then
      notify("file not found: " .. file, vim.log.levels.ERROR)
      return
    end

    if not run_vim_cmd("edit " .. vim.fn.fnameescape(file), "failed to open mark file") then
      return
    end

    local line = tonumber(target.line) or 1
    local col = tonumber(target.col) or 0
    local line_count = vim.api.nvim_buf_line_count(0)
    if line < 1 then
      line = 1
    end
    if line > line_count then
      line = line_count
    end
    if col < 0 then
      col = 0
    end
    local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1] or ""
    if col > #line_text then
      col = #line_text
    end
    local ok_set, err_set = pcall(vim.api.nvim_win_set_cursor, 0, { line, col })
    if not ok_set then
      notify("failed to move cursor: " .. format_error(err_set), vim.log.levels.ERROR)
    end
  end)
end

local function mark_setter()
  local char = vim.fn.getcharstr()
  if char == "" then
    return
  end
  set_project_mark(char)
end

local function mark_jumper()
  local char = vim.fn.getcharstr()
  if char == "" then
    return
  end
  goto_project_mark(char)
end

local function mark_deleter()
  local char = vim.fn.getcharstr()
  if char == "" then
    return
  end
  delete_project_mark(char)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})

  local normal = { "n", "o", "x" }
  local map_opts = { noremap = true, silent = true }

  vim.keymap.set(normal, "m", mark_setter, map_opts)
  vim.keymap.set(normal, "'", mark_jumper, map_opts)
  vim.keymap.set(normal, "d", function()
    local char = vim.fn.getcharstr()
    if char ~= "m" then
      vim.api.nvim_feedkeys("d" .. char, "n", false)
      return
    end
    mark_deleter()
  end, map_opts)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local state = load_state()
      save_state_or_notify(state)
    end,
  })
end

return M
