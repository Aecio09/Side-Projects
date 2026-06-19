local Colors = {}

local codes = {
    reset   = "\27[0m",
    bold    = "\27[1m",
    dim     = "\27[2m",
    italic  = "\27[3m",
    under   = "\27[4m",

    -- Paleta 256-cores: Mar e Lua
    deep_ocean = "\27[38;5;26m",  -- Azul royal/mar profundo
    moonlight  = "\27[38;5;153m", -- Azul prateado muito claro (luar)
    aquamarine = "\27[38;5;39m",  -- Ciano oceânico brilhante
    silver     = "\27[38;5;251m", -- Cinza prateado lunar
    deep_space = "\27[38;5;239m", -- Cinza escuro (espaço sideral)
    
    red        = "\27[38;5;203m", -- Vermelho suave para erros
    green      = "\27[38;5;120m", -- Verde suave para sucesso
    yellow     = "\27[38;5;221m", -- Amarelo/Dourado suave
}

function Colors.apply(text, ...)
    local prefix = ""
    for _, name in ipairs({...}) do
        prefix = prefix .. (codes[name] or "")
    end
    return prefix .. text .. codes.reset
end

function Colors.red(t)     return Colors.apply(t, "red") end
function Colors.green(t)   return Colors.apply(t, "green") end
function Colors.yellow(t)  return Colors.apply(t, "yellow") end
function Colors.gray(t)    return Colors.apply(t, "deep_space") end
function Colors.white(t)   return Colors.apply(t, "moonlight") end
function Colors.bold(t)    return Colors.apply(t, "bold") end

-- Mapeamento semântico
function Colors.success(t) return Colors.apply(t, "green", "bold") end
function Colors.error(t)   return Colors.apply(t, "red", "bold") end
function Colors.warn(t)    return Colors.apply(t, "yellow") end
function Colors.info(t)    return Colors.apply(t, "moonlight") end
function Colors.header(t)  return Colors.apply(t, "deep_ocean", "bold") end
function Colors.prompt(t)  return Colors.apply(t, "aquamarine", "bold") end
function Colors.text(t)    return Colors.apply(t, "silver") end

function Colors.clear()
    io.write("\27[2J\27[H")
end

function Colors.enter_alt_screen()
    io.write("\27[?1049h\27[H")
end

function Colors.exit_alt_screen()
    io.write("\27[?1049l")
end

return Colors
