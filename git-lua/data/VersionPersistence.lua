local json = require("data.dkjson")
local VersionList = require("core.Version_list")

local Persistence = {}

--------------------------------------------------------------------------------
-- SERIALIZAÇÃO (memória → JSON)
--------------------------------------------------------------------------------

--- Converte uma VersionList (linked list) em um array de tabelas simples.
-- Remove o ponteiro 'prev' pois ele é referência circular e será
-- reconstruído na deserialização.
local function serialize_version_list(vlist)
    local versions = {}
    local node = vlist.head
    while node do
        table.insert(versions, {
            number    = node.number,
            timestamp = node.timestamp,
            size      = node.size,
            hash      = node.hash,
            comment   = node.comment,
            content   = node.content,
            deleted   = node.deleted,
            -- 'prev' é omitido de propósito
        })
        node = node.prev
    end
    -- history() retorna mais recente primeiro; mantemos a mesma ordem
    return versions
end

--- Percorre a Trie recursivamente e converte cada nó em tabela serializável.
local function serialize_node(node)
    local data = {
        name = node.name,
        type = node.type,
    }

    if node.type == "file" and node.versions then
        data.versions = serialize_version_list(node.versions)
    end

    if node.children then
        data.children = {}
        for child_name, child_node in pairs(node.children) do
            data.children[child_name] = serialize_node(child_node)
        end
    end

    return data
end

--------------------------------------------------------------------------------
-- DESERIALIZAÇÃO (JSON → memória)
--------------------------------------------------------------------------------

--- Reconstrói uma VersionList a partir de um array de versões.
-- O array vem em ordem mais-recente-primeiro (como serialize_version_list
-- produz), então iteramos de trás pra frente para reconstruir os ponteiros
-- 'prev' corretamente.
local function deserialize_version_list(versions_array)
    local vlist = VersionList.new()
    if not versions_array or #versions_array == 0 then
        return vlist
    end

    -- O array está em ordem decrescente (head primeiro).
    -- Reconstruímos de trás pra frente para que o prev aponte corretamente.
    local prev = nil
    for i = #versions_array, 1, -1 do
        local v = versions_array[i]
        local node = {
            number    = v.number,
            timestamp = v.timestamp,
            size      = v.size,
            hash      = v.hash,
            comment   = v.comment,
            content   = v.content,
            deleted   = v.deleted or false,
            prev      = prev,
        }
        prev = node
    end

    vlist.head  = prev  -- o mais recente (primeiro do array original)
    vlist.count = #versions_array
    return vlist
end

--- Reconstrói um nó da Trie a partir dos dados deserializados.
local function deserialize_node(data)
    local node = {
        name     = data.name,
        type     = data.type,
        children = {},
    }

    if data.type == "file" and data.versions then
        node.versions = deserialize_version_list(data.versions)
    end

    if data.children then
        for child_name, child_data in pairs(data.children) do
            node.children[child_name] = deserialize_node(child_data)
        end
    end

    return node
end

--------------------------------------------------------------------------------
-- API PÚBLICA
--------------------------------------------------------------------------------

--- Salva um repositório inteiro em um arquivo JSON.
-- @param repo   O objeto Repository (com .name e .tree)
-- @param filepath  Caminho do arquivo JSON de saída
-- @return true em caso de sucesso, ou nil + mensagem de erro
function Persistence.save(repo, filepath)
    local data = {
        repo_name = repo.name,
        tree      = serialize_node(repo.tree.root),
    }

    local json_str = json.encode(data, { indent = true })

    local file, err = io.open(filepath, "w")
    if not file then
        return nil, "erro ao abrir arquivo para escrita: " .. (err or "")
    end

    file:write(json_str)
    file:close()
    return true
end

--- Carrega um repositório a partir de um arquivo JSON.
-- @param filepath  Caminho do arquivo JSON
-- @return Tabela com { name, tree_root } ou nil + mensagem de erro
function Persistence.load(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        return nil, "erro ao abrir arquivo para leitura: " .. (err or "")
    end

    local json_str = file:read("*a")
    file:close()

    local data, _, json_err = json.decode(json_str)
    if not data then
        return nil, "erro ao decodificar JSON: " .. (json_err or "")
    end

    local root = deserialize_node(data.tree)
    return {
        name      = data.repo_name,
        tree_root = root,
    }
end

return Persistence
