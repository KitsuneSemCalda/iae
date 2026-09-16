# iae

Ambiente TUI para desenvolvimento agentic, inspirado no setup tmux+editor do
craftzdog, feito para rodar no [Omarchy Linux](https://omarchy.org).

Um único script (`iae`) monta uma sessão tmux com 4 painéis fixos:

- **editor** — `nvim`
- **agente** — o agente de codificação padrão do Omarchy (`omarchy-agent`, configurável via `omarchy default agent <nome>`)
- **shell** — livre, o shell padrão do sistema
- **git/logs** — `lazygit`

## Uso

```sh
./iae [caminho-do-projeto]
```

Sem argumento, usa o diretório atual. Rodar de novo no mesmo projeto reconecta
na sessão existente em vez de duplicar os painéis.

## Dependências

`tmux`, `nvim`, `omarchy-agent` e `lazygit` precisam estar no `PATH` (padrão em qualquer instalação do Omarchy).
