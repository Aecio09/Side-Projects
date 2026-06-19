local Colors = require("tui.Colors")
local Repo = require("core.Repository")
local Diff = require("core.Diff")

local Interface = {}
Interface.__index = Interface

function Interface.new()
    return setmetatable({ repo = nil, running = true }, Interface)
end

function Interface:print_banner()
    Colors.clear()
    print(Colors.header("╔══════════════════════════════════════╗"))
    print(Colors.header("║") .. Colors.apply("        git-lua  v0.1              ", "aquamarine", "bold") .. Colors.header("║"))
    print(Colors.header("║") .. Colors.gray("   versionamento local de arquivos ") .. Colors.header("║"))
    print(Colors.header("╚══════════════════════════════════════╝"))
    print()
    if self.repo then
        print(Colors.info("  Repositório: ") .. Colors.bold(self.repo.name))
        print(Colors.info("  Caminho: ") .. Colors.gray(self.repo.root_path))
    else
        print(Colors.warn("  Nenhum repositório aberto."))
        print(Colors.gray("  Use /init <caminho> ou /open <caminho>"))
    end
    print()
    print(Colors.gray("  Digite /help para ver os comandos disponíveis."))
    print(Colors.gray("  ─────────────────────────────────────"))
    print()
end

function Interface:prompt()
    local name = self.repo and self.repo.name or "~"
    io.write(Colors.prompt(name) .. Colors.prompt(" ❯ "))
    local line = io.read("*l")
    if not line then
        self.running = false
        return nil
    end
    return line:match("^%s*(.-)%s*$")
end

local function parse_args(input)
    local args = {}
    local i = 1
    while i <= #input do
        local c = input:sub(i, i)
        if c == '"' or c == "'" then
            local close = input:find(c, i + 1, true)
            if close then
                table.insert(args, input:sub(i + 1, close - 1))
                i = close + 1
            else
                table.insert(args, input:sub(i + 1))
                break
            end
        elseif c ~= " " then
            local next_space = input:find(" ", i, true)
            if next_space then
                table.insert(args, input:sub(i, next_space - 1))
                i = next_space
            else
                table.insert(args, input:sub(i))
                break
            end
        end
        i = i + 1
    end
    return args
end

local function find_flag(args, short, long)
    for i, a in ipairs(args) do
        if a == short or a == long then
            local val = args[i + 1]
            table.remove(args, i)
            if val then table.remove(args, i) end
            return val
        end
    end
    return nil
end

function Interface:require_repo()
    if not self.repo then
        print(Colors.error("  ✗ Nenhum repositório aberto."))
        print(Colors.gray("    Use /init <caminho> ou /open <caminho>"))
        return false
    end
    return true
end

--------------------------------------------------------------------------------

function Interface:cmd_help()
    print()
    print(Colors.header("  Comandos disponíveis:"))
    print()
    local cmds = {
        { "/init <caminho>",                "Inicializa um novo repositório" },
        { "/open <caminho>",                "Abre um repositório existente" },
        { "/status",                        "Mostra status dos arquivos" },
        { "/commit <arquivo> -m \"msg\"",   "Versiona um arquivo" },
        { "/log <arquivo>",                 "Histórico de versões" },
        { "/diff <arquivo>",                "Diff do arquivo vs última versão" },
        { "/diff <arquivo> <v1> <v2>",      "Diff entre duas versões" },
        { "/restore <arquivo> <versão>",    "Restaura versão no disco" },
        { "/ls [caminho]",                  "Lista diretórios na árvore" },
        { "/clear",                         "Limpa a tela" },
        { "/help",                          "Mostra esta ajuda" },
        { "/quit",                          "Sai do programa" },
    }
    for _, c in ipairs(cmds) do
        print("  " .. Colors.prompt(string.format("%-35s", c[1])) .. Colors.gray(c[2]))
    end
    print()
end

function Interface:cmd_init(args)
    local path = args[1]
    if not path then
        print(Colors.error("  ✗ Uso: /init <caminho>"))
        return
    end

    local full = path:sub(1,1) == "/" and path or (os.getenv("PWD") .. "/" .. path)
    self.repo = Repo.init(full)
    print(Colors.success("  ✓ Repositório inicializado: ") .. Colors.bold(self.repo.name))
    print(Colors.gray("    " .. full .. "/.git-lua/"))
end

function Interface:cmd_open(args)
    local path = args[1]
    if not path then
        print(Colors.error("  ✗ Uso: /open <caminho>"))
        return
    end

    local full = path:sub(1,1) == "/" and path or (os.getenv("PWD") .. "/" .. path)
    local repo, err = Repo.open(full)
    if not repo then
        print(Colors.error("  ✗ " .. err))
        return
    end
    self.repo = repo
    print(Colors.success("  ✓ Repositório aberto: ") .. Colors.bold(self.repo.name))
end

function Interface:cmd_status()
    if not self:require_repo() then return end

    local s = self.repo:status()
    print()

    local has_changes = #s.modified > 0 or #s.new > 0 or #s.deleted > 0
    if not has_changes and #s.unchanged == 0 then
        print(Colors.gray("  Nenhum arquivo encontrado."))
        print()
        return
    end

    if #s.modified > 0 then
        print(Colors.header("  Modificados:"))
        for _, f in ipairs(s.modified) do
            print("    " .. Colors.yellow("M ") .. f)
        end
    end

    if #s.deleted > 0 then
        print(Colors.header("  Deletados:"))
        for _, f in ipairs(s.deleted) do
            print("    " .. Colors.red("D ") .. f)
        end
    end

    if #s.new > 0 then
        print(Colors.header("  Não rastreados:"))
        for _, f in ipairs(s.new) do
            print("    " .. Colors.prompt("? ") .. f)
        end
    end

    if #s.unchanged > 0 and not has_changes then
        print(Colors.success("  ✓ Todos os arquivos estão atualizados.") ..
              Colors.gray(" (" .. #s.unchanged .. " rastreados)"))
    elseif #s.unchanged > 0 then
        print(Colors.gray("  (" .. #s.unchanged .. " inalterados)"))
    end
    print()
end

function Interface:cmd_commit(args)
    if not self:require_repo() then return end

    local msg = find_flag(args, "-m", "--message")
    local path = args[1]
    if not path then
        print(Colors.error("  ✗ Uso: /commit <arquivo|.> -m \"mensagem\""))
        return
    end
    if not msg then
        io.write(Colors.yellow("  Mensagem do commit: "))
        msg = io.read("*l")
        if not msg or msg == "" then
            print(Colors.error("  ✗ Commit cancelado."))
            return
        end
    end

    if path == "." or path == "-A" or path == "--all" then
        local committed, errs = self.repo:commit_all(msg)
        if #committed == 0 and #errs == 0 then
            print(Colors.warn("  Nenhuma alteração pendente para commitar."))
            return
        end
        for _, f in ipairs(committed) do
            local node = self.repo.tree:find(f)
            local v = node.versions.head
            print(Colors.success("  ✓ Commit v" .. v.number) ..
                  Colors.gray(" │ " .. f) ..
                  Colors.gray(" │ " .. v.size .. " bytes") ..
                  Colors.gray(" │ " .. v.hash:sub(1, 8)))
        end
        for _, e in ipairs(errs) do
            print(Colors.error("  ✗ Erro em " .. e.file .. ": " .. e.err))
        end
    else
        local v, err = self.repo:commit(path, msg)
        if not v then
            print(Colors.error("  ✗ " .. err))
            return
        end
        print(Colors.success("  ✓ Commit v" .. v.number) ..
              Colors.gray(" │ " .. path) ..
              Colors.gray(" │ " .. v.size .. " bytes") ..
              Colors.gray(" │ " .. v.hash:sub(1, 8)))
    end
end

function Interface:cmd_log(args)
    if not self:require_repo() then return end

    local path = args[1]
    if not path then
        print(Colors.error("  ✗ Uso: /log <arquivo>"))
        return
    end

    local hist, err = self.repo:log(path)
    if not hist then
        print(Colors.error("  ✗ " .. err))
        return
    end

    print()
    print(Colors.header("  Histórico de " .. path))
    print()
    for _, v in ipairs(hist) do
        local time_str = os.date("%Y-%m-%d %H:%M:%S", v.timestamp)
        local status_prefix = v.deleted and " [DELETADO]" or ""
        print("  " .. Colors.yellow("v" .. v.number) ..
              Colors.gray(" │ ") .. time_str ..
              Colors.gray(" │ ") .. Colors.prompt(v.hash:sub(1, 8)) ..
              Colors.gray(" │ ") .. v.comment .. Colors.warn(status_prefix))
    end
    print()
end

function Interface:cmd_diff(args)
    if not self:require_repo() then return end

    local path = args[1]
    if not path then
        print(Colors.error("  ✗ Uso: /diff <arquivo> [v1 v2]"))
        return
    end

    local changes, err
    local label

    if args[2] and args[3] then
        local v1 = tonumber(args[2])
        local v2 = tonumber(args[3])
        if not v1 or not v2 then
            print(Colors.error("  ✗ Versões devem ser números."))
            return
        end
        changes, err = self.repo:diff(path, v1, v2)
        label = "v" .. v1 .. " → v" .. v2
    else
        changes, err = self.repo:diff_working(path)
        label = "última versão → disco"
    end

    if not changes then
        print(Colors.error("  ✗ " .. err))
        return
    end

    local added, removed = Diff.summary(changes)
    if added == 0 and removed == 0 then
        print(Colors.success("  ✓ Sem diferenças."))
        return
    end

    print()
    print(Colors.header("  Diff: " .. path) .. Colors.gray("  (" .. label .. ")"))
    print()

    for _, c in ipairs(changes) do
        if c.type == "+" then
            print("  " .. Colors.green("+ " .. c.line))
        elseif c.type == "-" then
            print("  " .. Colors.red("- " .. c.line))
        else
            print("  " .. Colors.gray("  " .. c.line))
        end
    end

    print()
    print("  " .. Colors.green("+" .. added) .. "  " .. Colors.red("-" .. removed))
    print()
end

function Interface:cmd_restore(args)
    if not self:require_repo() then return end

    local path = args[1]
    local ver = tonumber(args[2])
    if not path or not ver then
        print(Colors.error("  ✗ Uso: /restore <arquivo> <versão>"))
        return
    end

    local content, err = self.repo:restore(path, ver, true)
    if not content then
        print(Colors.error("  ✗ " .. err))
        return
    end
    print(Colors.success("  ✓ Restaurado ") .. Colors.yellow("v" .. ver) ..
          Colors.gray(" → " .. path))
end

function Interface:cmd_ls(args)
    if not self:require_repo() then return end

    local path = args[1] or ""
    local entries = self.repo.tree:list_dir(path)
    if not entries then
        print(Colors.error("  ✗ Caminho não encontrado."))
        return
    end

    print()
    local display = path == "" and "/" or path
    print(Colors.header("  " .. display))
    for _, e in ipairs(entries) do
        if e.type == "dir" then
            print("    " .. Colors.prompt(e.name .. "/"))
        else
            print("    " .. e.name)
        end
    end
    print()
end

--------------------------------------------------------------------------------

local commands = {
    help    = "cmd_help",
    init    = "cmd_init",
    open    = "cmd_open",
    status  = "cmd_status",
    commit  = "cmd_commit",
    log     = "cmd_log",
    diff    = "cmd_diff",
    restore = "cmd_restore",
    ls      = "cmd_ls",
}

local function get_terminal_size()
    local H, W = 24, 80
    local f = io.popen("stty size 2>/dev/null")
    if f then
        local res = f:read("*all")
        f:close()
        local rows, cols = res:match("(%d+)%s+(%d+)")
        if rows and cols then
            H = tonumber(rows)
            W = tonumber(cols)
        end
    end
    return H, W
end

function Interface:redraw()
    local H, W = get_terminal_size()
    Colors.clear()

    local header_border = "╔" .. string.rep("═", W - 2) .. "╗"
    local title = " git-lua v0.1 "
    local title_pos = math.floor((W - #title) / 2)
    local header_title = "║" .. string.rep(" ", title_pos - 1) .. title .. string.rep(" ", W - title_pos - #title - 1) .. "║"

    io.write(Colors.header(header_border) .. "\n")
    io.write(Colors.header(header_title) .. "\n")

    local repo_info = ""
    if self.repo then
        repo_info = " Repositório: " .. self.repo.name .. " (" .. self.repo.root_path .. ")"
    else
        repo_info = " Nenhum repositório aberto (/init <caminho> ou /open <caminho>)"
    end
    local info_line = "║" .. repo_info .. string.rep(" ", W - #repo_info - 2) .. "║"
    io.write(Colors.info(info_line) .. "\n")

    local sep = "╚" .. string.rep("═", W - 2) .. "╝"
    io.write(Colors.header(sep) .. "\n")

    local header_height = 4
    local footer_height = 2
    local log_height = H - header_height - footer_height

    local start_idx = #self.output_history - log_height + 1
    if start_idx < 1 then start_idx = 1 end

    for i = start_idx, #self.output_history do
        io.write(self.output_history[i] .. "\n")
    end

    local lines_written = (#self.output_history - start_idx + 1)
    if lines_written < 0 then lines_written = 0 end
    for i = lines_written + 1, log_height do
        io.write("\n")
    end

    io.write(Colors.gray(string.rep("─", W)) .. "\n")

    io.write("\27[" .. H .. ";1H")
    local name = self.repo and self.repo.name or "~"
    io.write(Colors.prompt(name) .. Colors.prompt(" ❯ "))
end

local function capture_print(self, fn, ...)
    local old_print = _G.print
    _G.print = function(...)
        local args = {...}
        local strs = {}
        for _, a in ipairs(args) do
            table.insert(strs, tostring(a))
        end
        local text = table.concat(strs, "\t")
        for line in (text .. "\n"):gmatch("(.-)\n") do
            table.insert(self.output_history, line)
        end
    end

    local success, err = pcall(fn, self, ...)

    _G.print = old_print
    if not success then
        error(err)
    end
end

function Interface:run()
    self.output_history = {}
    
    table.insert(self.output_history, Colors.info("  Bem-vindo ao git-lua!"))
    table.insert(self.output_history, Colors.gray("  Digite /help para listar comandos disponíveis."))

    Colors.enter_alt_screen()

    local success, err = pcall(function()
        while self.running do
            self:redraw()
            local input = io.read("*l")
            if not input then break end
            local clean_input = input:match("^%s*(.-)%s*$")
            
            if clean_input ~= "" then
                local name = self.repo and self.repo.name or "~"
                table.insert(self.output_history, Colors.prompt(name) .. Colors.prompt(" ❯ ") .. clean_input)

                local clean = clean_input:sub(1,1) == "/" and clean_input:sub(2) or clean_input
                local parts = parse_args(clean)
                local cmd = table.remove(parts, 1)

                if cmd then
                    cmd = cmd:lower()
                    if cmd == "quit" or cmd == "exit" or cmd == "q" then
                        self.running = false
                    elseif cmd == "clear" or cmd == "cls" then
                        self.output_history = {}
                    elseif commands[cmd] then
                        capture_print(self, self[commands[cmd]], parts)
                    else
                        table.insert(self.output_history, Colors.error("  ✗ Comando desconhecido: ") .. Colors.yellow(cmd))
                    end
                end
            end
        end
    end)

    Colors.exit_alt_screen()
    if not success then
        error(err)
    end
end

return Interface

