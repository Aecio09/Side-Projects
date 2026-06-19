local Trie = {};
Trie.__index = Trie;

function Trie.new()
    return setmetatable({
        root = {name = "/", type = "dir", children = {}, version = 0}
    }, Trie)
end

local function splitPath(path)
    local parts = {};
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part);
    end
    return parts;
end

function Trie:insert_file(path)
    local parts = splitPath(path);
    local current = self.root;

    for i, part in ipairs(parts) do
        local is_last = (i == #parts);
        if not current.children[part] then
            current.children[part] = {
                name = part,
                type = is_last and "file" or "dir",
                children = {},
                versions = is_last and require("core.Version_list").new() or nil
            };
        end
        current = current.children[part];
    end
    return current;
end

function Trie:find(path)
    local parts = splitPath(path);
    local current = self.root;

    for _, part in ipairs(parts) do
        current = current.children[part];
        if not current then return nil end
    end
    return current;
end

function Trie:list_dir(path)
    local node = path == "" and self.root or self:find(path);
    if not node then return nil end
    local entries = {};
    for name, child in pairs(node.children) do
        table.insert(entries, { name = name, type = child.type })
    end
    table.sort(entries, function(a,b) return a.name < b.name end)
    return entries;
end

return Trie;