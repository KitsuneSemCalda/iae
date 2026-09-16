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
ln -sfn "$(pwd)/iae" ~/.local/bin/iae
```

Deixa o comando `iae` disponível em qualquer diretório (assumindo
`~/.local/bin` no `PATH`, já o padrão no Omarchy).

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
