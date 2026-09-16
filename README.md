# iae

Ambiente TUI para desenvolvimento agentic, inspirado no setup tmux+editor do
craftzdog, feito para rodar no [Omarchy Linux](https://omarchy.org).

Um único script (`iae`) monta uma sessão tmux com 4 painéis fixos:

- **editor** — `nvim`
- **agente** — `claude`
- **shell** — livre, pra comandos gerais
- **git/logs** — `lazygit`

## Uso

```sh
./iae [caminho-do-projeto]
```

Sem argumento, usa o diretório atual. Rodar de novo no mesmo projeto reconecta
na sessão existente em vez de duplicar os painéis.

## Dependências

`tmux`, `nvim`, `claude` (Claude Code) e `lazygit` precisam estar no `PATH`.
