# git-lua 🌙🌊

Um sistema de versionamento local de arquivos baseado em árvore **Trie** e lista ligada de versões, implementado totalmente do zero em Lua, sem dependências externas de estruturas de dados.

O visual e a experiência do console são inspirados em interfaces de agentes de terminal modernas, utilizando tons de azul oceano (mar) e cinza lunar (lua) com redimensionamento dinâmico e tela cheia.

---

## 🏗️ Estrutura e Decisões de Projeto

### 1. Organização dos Dados: Árvore Trie (Construída do Zero)
Para organizar os caminhos (diretórios e arquivos) de forma hierárquica, escolhemos e implementamos uma **árvore Trie** (em [core/Trie.lua](file:///mnt/d/repositories/Side-Projects/git-lua/core/Trie.lua)):
*   **Justificativa**: A busca e inserção de caminhos segmentados por `/` (ex: `src/main.lua`) são altamente eficientes em uma Trie, rodando em tempo $O(L)$, onde $L$ é o número de níveis no caminho do arquivo.
*   **Hierarquia de Nós**:
    *   Nós do tipo `dir` contêm uma tabela (`children`) que mapeia os nomes de subdiretórios ou arquivos para seus respectivos nós-filho.
    *   Nós do tipo `file` representam os arquivos folha e possuem uma referência única para sua `VersionList` correspondente.

### 2. Histórico de Versões: Linked List (Lista Ligada)
O histórico de versões de cada arquivo é gerenciado por uma lista simplesmente encadeada reversa ([core/Version_list.lua](file:///mnt/d/repositories/Side-Projects/git-lua/core/Version_list.lua)):
*   **Justificativa**: O comportamento do Git necessita que a versão mais recente seja recuperada instantaneamente. A estrutura de lista ligada permite inserções no topo da cabeça (`head`) em complexidade $O(1)$.
*   **Metadados de Versão**:
    *   `number`: Número sequencial incremental da versão.
    *   `timestamp`: Unix Epoch de criação da versão (`os.time()`).
    *   `size`: Tamanho em bytes do conteúdo.
    *   `hash`: Hash do conteúdo computado utilizando o algoritmo **djb2** implementado em Lua pura.
    *   `comment`: Mensagem descritiva do commit.
    *   `content`: Conteúdo em string (armazenado nos nós folhas e persistido).
    *   `deleted`: Flag booleana que indica se aquela versão representa a remoção do arquivo do repositório.
    *   `prev`: Ponteiro para a versão anterior.

### 3. Persistência em JSON
Implementada em [data/VersionPersistence.lua](file:///mnt/d/repositories/Side-Projects/git-lua/data/VersionPersistence.lua):
*   A árvore Trie inteira é serializada recursivamente em um arquivo JSON (`.git-lua/history.json`).
*   As listas ligadas de versões são serializadas como arrays no JSON e reconstruídas na inicialização reconectando seus ponteiros `prev` de trás para frente.
*   A serialização é feita pela biblioteca pura em Lua [data/dkjson.lua](file:///mnt/d/repositories/Side-Projects/git-lua/data/dkjson.lua).

### 4. Algoritmo de Diferença: Diff LCS (Do Zero)
Para o comando de comparação de arquivos ([core/Diff.lua](file:///mnt/d/repositories/Side-Projects/git-lua/core/Diff.lua)):
*   Implementamos o clássico algoritmo de programação dinâmica **LCS (Longest Common Subsequence)** para calcular a maior subsequência comum de linhas entre dois textos.
*   Um passo de *backtracking* percorre a matriz gerada montando a lista exata de inserções (`+`), remoções (`-`) e linhas inalteradas (` `), de forma análoga ao `git diff`.

---

## 🎮 Interface de Terminal Interativa (TUI)

O sistema conta com um REPL de tela cheia ([tui/Interface.lua](file:///mnt/d/repositories/Side-Projects/git-lua/tui/Interface.lua)):
*   **Alternate Screen Buffer**: A TUI roda no buffer alternativo do terminal (`\27[?1049h`), não misturando os comandos com o histórico normal do terminal.
*   **Redimensionamento Dinâmico**: Ele captura dinamicamente a altura e largura da tela para fixar a barra de status no topo e o prompt de entrada (`~ ❯`) colado na última linha do rodapé.
*   **Interceptação de Outputs**: Toda saída dos comandos executados é capturada e redirecionada para um buffer histórico rolável para evitar que o conteúdo passe da tela física.

---

## 🛠️ Operações Suportadas (Comandos)

Digite qualquer um dos comandos dentro do REPL para interagir:

*   `/init <caminho>`: Cria um repositório no caminho especificado e o vincula ao workspace.
*   `/open <caminho>`: Abre um repositório `.git-lua` já existente na máquina.
*   `/status`: Compara o disco com o último estado salvo e mostra arquivos modificados (`M`), deletados (`D`), não rastreados (`?`) ou inalterados.
*   `/commit <arquivo> -m "msg"`: Cria uma nova versão para o arquivo lendo o conteúdo real do disco.
*   `/commit . -m "msg"`: Commita todos os arquivos novos, modificados e removidos de uma vez só (equivalente ao `git add .` + `git commit`).
*   `/log <arquivo>`: Lista todo o histórico de versões do arquivo, marcando inclusive se e quando ele foi deletado.
*   `/diff <arquivo>`: Compara o arquivo atual do disco com a última versão gravada no histórico.
*   `/diff <arquivo> <v1> <v2>`: Mostra as diferenças de linha entre duas versões específicas salvadas.
*   `/restore <arquivo> <versão>`: Recupera uma versão antiga do histórico e reescreve o arquivo fisicamente no disco. Se a versão for uma deleção, remove o arquivo do disco.
*   `/ls [diretório]`: Lista a árvore interna de arquivos e subdiretórios rastreados.
*   `/clear`: Limpa a tela de logs central da interface.
*   `/quit` ou `/exit`: Restaura a tela original do terminal e encerra o sistema.

---

## 🚦 Como Executar

Garanta que possui o interpretador `lua` instalado em sua máquina Unix/Linux e execute:

```bash
lua Main.lua
```

---

## 🛑 Conformidade de Restrições

*   **Zero dependências de árvores**: Todo o algoritmo de prefixos da Trie foi programado na unha em `core/Trie.lua`.
*   **Zero dependências de diff**: O módulo `core/Diff.lua` calcula a matriz de subsequência mais longa e monta a formatação da diferença exclusivamente via lógica local.
*   **Sem bibliotecas de TUI**: O painel interativo de tela cheia foi concebido puramente manipulando sequências de escape ANSI nativas.
