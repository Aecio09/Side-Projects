local Trie = require("core.Trie")
local Persistence = require("data.VersionPersistence")
local Diff = require("core.Diff")

local Repo = {}
Repo.__index = Repo

local REPO_DIR = ".git-lua"
local HISTORY_FILE = "history.json"

function Repo.new(name, root_path)
    return setmetatable({
        name = name,
        root_path = root_path,
        tree = Trie.new()
    }, Repo)
end

function Repo.from_data(data, root_path)
    local repo = setmetatable({
        name = data.name,
        root_path = root_path,
        tree = Trie.new()
    }, Repo)
    repo.tree.root = data.tree_root
    return repo
end

function Repo:_history_path()
    return self.root_path .. "/" .. REPO_DIR .. "/" .. HISTORY_FILE
end

function Repo:_full_path(rel_path)
    return self.root_path .. "/" .. rel_path
end

function Repo:_read_file(rel_path)
    local f = io.open(self:_full_path(rel_path), "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

function Repo:_write_file(rel_path, content)
    local full = self:_full_path(rel_path)
    local dir = full:match("(.+)/[^/]+$")
    if dir then os.execute('mkdir -p "' .. dir .. '"') end
    local f = io.open(full, "w")
    if not f then return nil, "erro ao escrever: " .. rel_path end
    f:write(content)
    f:close()
    return true
end

function Repo:_scan_working_dir()
    local files = {}
    local base = self.root_path
    local ignore = REPO_DIR .. "/"
    local handle = io.popen('find "' .. base .. '" -type f 2>/dev/null')
    if not handle then return files end

    for line in handle:lines() do
        line = line:gsub("\r", "")
        local rel = line:sub(#base + 2)
        if rel ~= "" and rel:sub(1, #ignore) ~= ignore then
            table.insert(files, rel)
        end
    end
    handle:close()
    table.sort(files)
    return files
end

function Repo:_collect_tracked(node, prefix)
    local files = {}
    if node.type == "file" then
        local latest = node.versions and node.versions.head
        if latest and not latest.deleted then
            table.insert(files, prefix)
        end
        return files
    end
    if node.children then
        for name, child in pairs(node.children) do
            local path = prefix == "" and name or (prefix .. "/" .. name)
            for _, f in ipairs(self:_collect_tracked(child, path)) do
                table.insert(files, f)
            end
        end
    end
    return files
end

--------------------------------------------------------------------------------

function Repo.init(root_path)
    local repo_dir = root_path .. "/" .. REPO_DIR
    os.execute('mkdir -p "' .. repo_dir .. '"')

    local name = root_path:match("([^/]+)$") or "repo"
    local repo = Repo.new(name, root_path)
    repo:save()
    return repo
end

function Repo.open(root_path)
    local path = root_path .. "/" .. REPO_DIR .. "/" .. HISTORY_FILE
    local f = io.open(path, "r")
    if not f then return nil, "repositório não encontrado em: " .. root_path end
    f:close()

    local data, err = Persistence.load(path)
    if not data then return nil, err end
    return Repo.from_data(data, root_path)
end

function Repo:commit(path, comment)
    local node = self.tree:find(path)
    local content = self:_read_file(path)

    if not content then
        if node and node.versions and node.versions.head and not node.versions.head.deleted then
            local version = node.versions:push({ deleted = true, comment = comment })
            self:save()
            return version
        else
            return nil, "arquivo não encontrado: " .. path
        end
    end

    if node and node.versions and node.versions.head then
        if not node.versions.head.deleted and node.versions.head.content == content then
            return nil, "nenhuma alteração detectada"
        end
    end

    local file_node = node or self.tree:insert_file(path)
    local version = file_node.versions:push({ content = content, comment = comment })
    self:save()
    return version
end

function Repo:commit_all(comment)
    local s = self:status()
    local committed = {}
    local errs = {}

    for _, f in ipairs(s.modified) do
        local v, err = self:commit(f, comment)
        if v then table.insert(committed, f)
        else table.insert(errs, { file = f, err = err }) end
    end

    for _, f in ipairs(s.new) do
        local v, err = self:commit(f, comment)
        if v then table.insert(committed, f)
        else table.insert(errs, { file = f, err = err }) end
    end

    for _, f in ipairs(s.deleted) do
        local v, err = self:commit(f, comment)
        if v then table.insert(committed, f)
        else table.insert(errs, { file = f, err = err }) end
    end

    return committed, errs
end

function Repo:log(path)
    local node = self.tree:find(path)
    if not node or node.type ~= "file" then return nil, "arquivo não encontrado" end
    return node.versions:history()
end

function Repo:restore(path, version_number, write_to_disk)
    local node = self.tree:find(path)
    if not node then return nil, "arquivo não encontrado" end
    local v = node.versions:get(version_number)
    if not v then return nil, "versão não encontrada" end

    if v.deleted then
        if write_to_disk then
            os.remove(self:_full_path(path))
        end
        return nil, "arquivo deletado nesta versão"
    end

    if write_to_disk then
        self:_write_file(path, v.content)
    end
    return v.content
end

function Repo:status()
    local disk_files = self:_scan_working_dir()
    local tracked_files = self:_collect_tracked(self.tree.root, "")

    local on_disk = {}
    for _, f in ipairs(disk_files) do on_disk[f] = true end

    local tracked = {}
    for _, f in ipairs(tracked_files) do tracked[f] = true end

    local result = {
        new       = {},
        modified  = {},
        deleted   = {},
        unchanged = {},
    }

    for _, f in ipairs(disk_files) do
        if not tracked[f] then
            table.insert(result.new, f)
        else
            local content = self:_read_file(f)
            local node = self.tree:find(f)
            if node and node.versions and node.versions.head then
                if not node.versions.head.deleted and node.versions.head.content == content then
                    table.insert(result.unchanged, f)
                else
                    table.insert(result.modified, f)
                end
            end
        end
    end

    for _, f in ipairs(tracked_files) do
        if not on_disk[f] then
            table.insert(result.deleted, f)
        end
    end

    table.sort(result.new)
    table.sort(result.modified)
    table.sort(result.deleted)
    table.sort(result.unchanged)
    return result
end

function Repo:diff(path, v1, v2)
    local node = self.tree:find(path)
    if not node then return nil, "arquivo não encontrado" end

    local ver1 = node.versions:get(v1)
    local ver2 = node.versions:get(v2)
    if not ver1 then return nil, "versão " .. v1 .. " não encontrada" end
    if not ver2 then return nil, "versão " .. v2 .. " não encontrada" end

    local content1 = ver1.deleted and "" or ver1.content
    local content2 = ver2.deleted and "" or ver2.content
    return Diff.compute(content1, content2)
end

function Repo:diff_working(path)
    local node = self.tree:find(path)
    if not node or not node.versions or not node.versions.head then
        return nil, "arquivo não rastreado"
    end

    local head = node.versions.head
    local head_content = head.deleted and "" or head.content
    local disk_content = self:_read_file(path) or ""

    return Diff.compute(head_content, disk_content)
end

function Repo:save()
    return Persistence.save(self, self:_history_path())
end

return Repo