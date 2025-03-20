local dap = require("dap")

local get_rust_gdb_path = function()
  local toolchain_location = string.gsub(vim.fn.system("rustc --print sysroot"), "\n", "")
  local rustgdb = toolchain_location .. "/bin/rust-gdb"
  return rustgdb
end

local has_telescope, _ = pcall(require, "telescope")

local find_program
if has_telescope then
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  find_program = function()
    return coroutine.create(function(coro)
      local opts = {}
      pickers
        .new(opts, {
          prompt_title = "Path to executable",
          finder = finders.new_oneshot_job(
            { "fd", "--hidden", "--exclude", ".git", "--no-ignore", "--type", "x" },
            {}
          ),
          sorter = conf.generic_sorter(opts),
          attach_mappings = function(buffer_number)
            actions.select_default:replace(function()
              actions.close(buffer_number)
              coroutine.resume(coro, action_state.get_selected_entry()[1])
            end)
            return true
          end,
        })
        :find()
    end)
  end
else
  find_program = function()
    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
  end
end

local default_rr_config = {
  name = "rr",
  type = "cppdbg",
  request = "launch",
  program = find_program,
  args = {},
  miDebuggerServerAddress = "127.0.0.1:50505",
  stopAtEntry = true,
  cwd = vim.fn.getcwd,
  environment = {},
  externalConsole = true,
  MIMode = "gdb",
  setupCommands = {
    {
      description = "Setup to resolve symbols",
      text = "set sysroot /",
      ignoreFailures = false,
    },
    {
      description = "Enable pretty-printing for gdb",
      text = "-enable-pretty-printing",
      ignoreFailures = false,
    },
  },
}

local default_setup_opts = {
  mappings = {
    continue = "<F7>",
    step_over = "<F8>",
    step_out = "<F9>",
    step_into = "<F10>",
    reverse_continue = "<F19>", -- <S-F7>
    reverse_step_over = "<F20>", -- <S-F8>
    reverse_step_out = "<F21>", -- <S-F9>
    reverse_step_into = "<F22>", -- <S-F10>
    step_over_i = "<F32>", -- <C-F8>
    step_out_i = "<F33>", -- <C-F8>
    step_into_i = "<F34>", -- <C-F8>
    reverse_step_over_i = "<F44>", -- <SC-F8>
    reverse_step_out_i = "<F45>", -- <SC-F9>
    reverse_step_into_i = "<F46>", -- <SC-F10>
  },
}

-- used to control which sessions should trigger
local registered_configs_names = {}

-- generate helper command for when rr has reached the end of the program and dap immediately exits
local M = {}
M.reverse_nexti_nodap = function()
  vim.ui.input(
    { prompt = "Enter <address>:<port> of the rr replay session: " },
    function(address_port)
      vim.cmd(
        '!gdb -q -ex "target remote '
          .. address_port
          .. '" -ex reverse-nexti -ex "set confirm off" -ex exit'
      )
    end
  )
end
vim.cmd('command! ReverseNextiNoDAP lua require("nvim-dap-rr").reverse_nexti_nodap()')

M.reverse_continue = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  -- s:evaluate("-exec set exec-direction reverse", function(err, resp)
  --   -- you can handle the response on this function
  -- end)
  dap.continue()
end
M.reverse_step_over = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_over()
end
M.reverse_step_out = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_out()
end
M.reverse_step_into = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_into()
end
M.reverse_step_over_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_over({ steppingGranularity = "instruction" })
end
M.reverse_step_out_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_out({ steppingGranularity = "instruction" })
end
M.reverse_step_into_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction reverse")
  dap.step_into({ steppingGranularity = "instruction" })
end

M.continue = function()
  local s = require("dap").session()
  if not s then
    dap.continue()
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.continue()
end
M.step_over = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_over()
end
M.step_out = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_out()
end
M.step_into = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_into()
end
M.step_over_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_over({ steppingGranularity = "instruction" })
end
M.step_out_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_out({ steppingGranularity = "instruction" })
end
M.step_into_i = function()
  local s = require("dap").session()
  if not s then
    return
  end
  s:evaluate("-exec set exec-direction forward")
  dap.step_into({ steppingGranularity = "instruction" })
end

local function load_dap()
  local ok, dap = pcall(require, "dap")
  assert(ok, "nvim-dap is required to use nvim-dap-rr")
  return dap
end

local action2command = function(action)
  if
    action == "continue"
    or action == "step_over"
    or action == "step_out"
    or action == "step_into"
    or action == "reverse_continue"
    or action == "reverse_step_over"
    or action == "reverse_step_out"
    or action == "reverse_step_into"
    or action == "step_over_i"
    or action == "step_out_i"
    or action == "step_into_i"
    or action == "reverse_step_over_i"
    or action == "reverse_step_out_i"
    or action == "reverse_step_into_i"
  then
    return "<cmd>lua require('nvim-dap-rr')." .. action .. "()<cr>"
  else
    error(action .. " is not a valid nvim-dap-rr action")
  end
end

local function contains(list, target)
  for _, value in ipairs(list) do
    if value == target then
      return true
    end
  end
  return false
end

function M.setup(opts)
  local dap = load_dap()
  local api = vim.api
  local keymap_restore = {}
  local buf_keymap_restore = {}
  local mappings = opts.mappings or {}

  -- iterate mappings to check actions are valid
  for action, _ in pairs(mappings) do
    action2command(action)
  end

  -- Set up mappings
  dap.listeners.after["event_initialized"]["nvim-dap-rr"] = function(session, _)
    if contains(registered_configs_names, session.config.name) then
      for action, key in pairs(mappings) do
        for _, buf in pairs(api.nvim_list_bufs()) do
          local buffer_keymaps = api.nvim_buf_get_keymap(buf, "n")
          for _, keymap in pairs(buffer_keymaps) do
            if keymap.lhs == key then
              table.insert(buf_keymap_restore, keymap)
              api.nvim_buf_del_keymap(buf, "n", key)
            end
          end
        end
        local keymaps = api.nvim_get_keymap("n")
        for _, keymap in pairs(keymaps) do
          if keymap.lhs == key then
            table.insert(keymap_restore, keymap)
            api.nvim_del_keymap("n", key)
          end
        end
        -- TODO: validate action
        api.nvim_set_keymap("n", key, action2command(action), { silent = true })
      end
    end
  end

  dap.listeners.after["event_terminated"]["nvim-dap-rr"] = function(session, _)
    if contains(registered_configs_names, session.config.name) then
      for _, key in pairs(mappings) do
        vim.keymap.del("n", key)
      end

      for _, keymap in pairs(buf_keymap_restore) do
        vim.keymap.set(
          keymap.mode,
          keymap.lhs,
          keymap.rhs or keymap.callback,
          { buffer = keymap.buffer, silent = keymap.silent == 1 }
        )
      end
      for _, keymap in pairs(keymap_restore) do
        vim.keymap.set(
          keymap.mode,
          keymap.lhs,
          keymap.rhs or keymap.callback,
          { silent = keymap.silent == 1 }
        )
      end
      buf_keymap_restore = {}
      keymap_restore = {}
    end
  end
end

-- Generates a config to add manually with dap.configurations.cpp = require("nvim-dap-rr").get_config()
function M.get_config(debuggerOpts)
  local config = vim.tbl_extend("keep", debuggerOpts or {}, default_rr_config)
  table.insert(registered_configs_names, config.name)
  return config
end

function M.get_rust_config(debuggerOpts)
  local rust_rr_config = M.get_config(debuggerOpts)
  rust_rr_config.miDebuggerPath = get_rust_gdb_path
  return rust_rr_config
end

return M
