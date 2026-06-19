local Diff = {}

local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

local function lcs_matrix(a, b)
    local m, n = #a, #b
    local C = {}
    for i = 0, m do
        C[i] = {}
        for j = 0, n do
            if i == 0 or j == 0 then
                C[i][j] = 0
            elseif a[i] == b[j] then
                C[i][j] = C[i-1][j-1] + 1
            else
                C[i][j] = math.max(C[i-1][j], C[i][j-1])
            end
        end
    end
    return C
end

local function backtrack(C, a, b, i, j)
    local result = {}
    while i > 0 and j > 0 do
        if a[i] == b[j] then
            table.insert(result, 1, { type = " ", line = a[i] })
            i, j = i - 1, j - 1
        elseif C[i-1][j] >= C[i][j-1] then
            table.insert(result, 1, { type = "-", line = a[i] })
            i = i - 1
        else
            table.insert(result, 1, { type = "+", line = b[j] })
            j = j - 1
        end
    end
    while i > 0 do
        table.insert(result, 1, { type = "-", line = a[i] })
        i = i - 1
    end
    while j > 0 do
        table.insert(result, 1, { type = "+", line = b[j] })
        j = j - 1
    end
    return result
end

function Diff.compute(old_text, new_text)
    local old_lines = split_lines(old_text)
    local new_lines = split_lines(new_text)
    local C = lcs_matrix(old_lines, new_lines)
    return backtrack(C, old_lines, new_lines, #old_lines, #new_lines)
end

function Diff.format(changes)
    local out = {}
    for _, c in ipairs(changes) do
        table.insert(out, c.type .. " " .. c.line)
    end
    return table.concat(out, "\n")
end

function Diff.summary(changes)
    local added, removed = 0, 0
    for _, c in ipairs(changes) do
        if c.type == "+" then added = added + 1
        elseif c.type == "-" then removed = removed + 1
        end
    end
    return added, removed
end

return Diff
