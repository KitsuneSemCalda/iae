# iae

Ambiente TUI para desenvolvimento agentic, inspirado no setup tmux+editor do
craftzdog, feito para rodar no [Omarchy Linux](https://omarchy.org).

Um único script (`iae`) monta uma sessão tmux com 4 painéis fixos:

- **editor** — `nvim`
- **agente** — o agente de codificação padrão do Omarchy (`omarchy-agent`, configurável via `omarchy default agent <nome>`)
- **shell** — livre, o shell padrão do sistema
- **git/logs** — `lazygit`

## Instalação

```sh
./install.sh
```

Cria um symlink de `iae` em `~/.local/bin` (padrão no Omarchy, já no `PATH`),
deixando o comando disponível em qualquer diretório. Funciona não importa de
onde você rode o script — ele resolve o próprio caminho, não o diretório
atual do shell. Para instalar em outro lugar, passe o destino como argumento:

```sh
./install.sh ~/bin
```

## Uso

```sh
iae [caminho-do-projeto]
```

Sem argumento, usa o diretório atual. Rodar de novo no mesmo projeto reconecta
na sessão existente em vez de duplicar os painéis. O nome da sessão é
derivado do caminho canônico do projeto (não só do nome da pasta), então
projetos diferentes com o mesmo nome de diretório (ex: dois `src/`) não
colidem, e symlinks pro mesmo projeto reconectam na mesma sessão.

## Dependências

`tmux`, `nvim`, `omarchy-agent` e `lazygit` precisam estar no `PATH` (padrão em qualquer instalação do Omarchy).
