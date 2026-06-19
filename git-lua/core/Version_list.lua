local VersionList = {};
VersionList.__index = VersionList;

function VersionList.new()
    return setmetatable({ head = nil, count = 0 }, VersionList)
end

-- hash simples (djb2)
local function simple_hash(str)
    local h = 5381
    for i = 1, #str do
        h = ((h * 33) + string.byte(str, i)) % 0xFFFFFFFF
    end
    return string.format("%08x", h)
end

function VersionList:push(data)
    self.count = self.count + 1
    local node = {
        number = self.count,
        timestamp = os.time(),
        size = data.content and #data.content or 0,
        hash = data.content and simple_hash(data.content) or "",
        comment = data.comment or "",
        content = data.content,
        deleted = data.deleted or false,
        prev = self.head
    };
    self.head = node;
    return node;
end

function VersionList:history()
    local list = {};
    local n = self.head;
    while n do
        table.insert(list, n)
        n = n.prev
    end
    return list -- mais recente primeiro
end

function VersionList:get(number)
    local n = self.head;
    while n do
        if n.number == number then return n end
        n = n.prev
    end
    return nil
end

return VersionList;