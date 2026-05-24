# Convenções — Nomenclatura, PR e Code Review

## Nomenclatura de workflows

Todo workflow do n8n usa um prefixo que indica seu papel:

| Prefixo      | Papel                                    | Exemplos                                               |
| ------------ | ---------------------------------------- | ------------------------------------------------------ |
| `martex-`    | Master / orquestrador                    | `martex-router`                                        |
| `wf-`        | Sub-fluxo de negócio                     | `wf-welcome`, `wf-track-order`, `wf-trade-return`      |
| `util-`      | Utilitário (interface estável)           | `util-send-message`, `util-set-state`, `util-escalate` |
| `cron-`      | Agendado (Schedule trigger)              | `cron-timeout-sweeper`, `cron-postsale-dispatcher`     |
| `mock-`      | Mock substituível por API real           | `mock-order-lookup`, `mock-stock-check`                |
| `data-`      | Dados de referência (raramente alterado) | `data-message-templates`, `data-holidays-br`           |
| `_archived-` | Workflow descontinuado mas mantido       | `_archived-Martex-Chatbot-v4`                          |

Regras adicionais:

- Sempre kebab-case.
- Sufixo de versão **apenas** se há quebra de contrato (`util-set-state-v2`). Versão "patch" é só `versionId` no JSON.
- Nome curto e descritivo. Se precisar explicar, vai em sticky note dentro do workflow.

## Nomenclatura de nós dentro do workflow

- **IF / Switch**: começa com `Is`, `Has` ou `Filter` (ex.: `IsValidOption`, `HasWelcomeLabel`).
- **HTTP Request**: verbo + ação (ex.: `SendWelcomeMenu`, `LabelEscalated`, `ReopenConversation`).
- **Set**: verbo + objeto (ex.: `NormalizeInput`, `SetStateAwaitingMenu`, `IncrementAttempts`).
- **Code**: descreve o que faz, não como (`MockOrderLookup`, `GenerateProtocol`).
- **NoOp**: começar com `NoOp` (ex.: `NoOpEscalated`).
- **Sticky notes**: começar com `Note:` ou `## <título>` no conteúdo.

IDs internos dos nós são opacos — o nome é o que importa.

## Estrutura de arquivos no repo

```
n8n/
├── plan/                           # este diretório (documentação)
├── workflows/                      # workflows ativos exportados (a criar)
│   ├── martex-router.json
│   ├── wf-welcome.json
│   ├── wf-track-order.json
│   ├── ...
│   ├── util-send-message.json
│   ├── ...
│   ├── cron-timeout-sweeper.json
│   └── mock-order-lookup.json
├── archive/                        # workflows descontinuados (a criar)
│   └── _archived-Martex-Chatbot-v4.json
├── DigiC-TagAndRoute-v2.json       # legado (manter por enquanto)
├── DigiC-TagAndRoute-v3.json       # legado
└── Martex-Chatbot-v4.json         # mover para archive/ ao iniciar Fase 0
```

## Fluxo de PR

1. **Pegue uma task** em [`tasks.md`](./tasks.md). Marque-a como "em andamento" em um comentário do PR.
2. **Crie/edite o workflow** no n8n. Teste manualmente via Webhook Test ou Chatwoot real.
3. **Exporte o workflow**: menu do n8n → "Download" → salve como `workflows/<nome>.json`.
4. **Atualize o checkbox** em `tasks.md` (de `[ ]` para `[x]`).
5. **Atualize o status** na tabela do [`README.md`](./README.md) (⚪ → 🟡 → 🟢).
6. **Se mudou copy**: atualize `templates.md` com o texto novo (chave + valor).
7. **Se mudou estado/transição**: atualize `state-machine.md`.
8. **Se mudou contrato de utilitário**: atualize `architecture.md` — e avise no PR.
9. Abra PR com:
   - **Título**: `[T<id>] <descrição curta>` — ex.: `[T0.5] Extrair Etapa 1 para wf-welcome`.
   - **Descrição**: o que muda, como testar, cenários cobertos.
   - **Reviewers**: 1 dev + 1 power-user.

## Code review

### Quem revisa o quê

| Revisor    | Foco                                                                                   |
| ---------- | -------------------------------------------------------------------------------------- |
| Dev        | Lógica, contratos, idempotência, segurança, performance, dependências entre workflows. |
| Power-user | Copy, UX da conversa, fidelidade ao documento martex, fluxos de menu.                  |

Ambos precisam aprovar antes do merge.

### Checklist para o dev

- [ ] Contratos de utilitários (`util-*`) preservados.
- [ ] `step` é setado **antes** de enviar mensagem (idempotência).
- [ ] Mensagens usam `JSON.stringify(...)` no body.
- [ ] URLs usam `$env.CHATWOOT_BASE_URL`.
- [ ] HTTP nodes têm `retryOnFail: true, maxTries: 3`.
- [ ] Sticky notes explicam decisões não-óbvias.
- [ ] Sem código JS dentro de Code nodes longos sem comentário.
- [ ] Nada de credencial hardcoded.
- [ ] Mock isolado em workflow `mock-*` (não dentro do sub-fluxo).

### Checklist para o power-user

- [ ] Copy idêntica a `templates.md` (chave-a-chave).
- [ ] Emojis preservados (⚠️ alguns terminais corrompem).
- [ ] Tom condiz com o documento martex v3.
- [ ] Cliente nunca fica em dead-end (sempre há próxima ação).
- [ ] Mensagens de escalada mencionam protocolo.
- [ ] Cenário testado manualmente pelo menos uma vez.

## Versionamento de workflows

- O n8n grava `versionId` automaticamente; usar para rollback rápido.
- JSON exportado no repo é a fonte de verdade durante revisão. Após merge, o workflow no n8n deve bater com o JSON.
- Mudança que quebra contrato (entrada/saída de `util-*`): criar `util-xxx-v2` em paralelo, migrar callers um a um, depois remover v1.

## Ambientes

| Ambiente  | Onde                             | Quando                      |
| --------- | -------------------------------- | --------------------------- |
| Dev local | n8n local + Chatwoot staging     | Trabalho diário, smoke test |
| Staging   | n8n hospedado + Chatwoot staging | Antes de cada deploy        |
| Prod      | n8n hospedado + Chatwoot martex  | Após aprovação do PR        |

Env vars diferem por ambiente. `CHATWOOT_BASE_URL` aponta para o ambiente correspondente.

## Quando NÃO criar um novo workflow

- A mudança é < 5 nós e cabe num workflow existente sem virar spaghetti.
- É um experimento — use um workflow `_sandbox-<seu-nome>` que nunca vai pra produção.
- É um teste de hipótese — não exporte para o repo até validar.

## Quando criar um workflow novo

- Tem trigger próprio (webhook, schedule, error).
- Tem responsabilidade isolada e nome claro.
- Será chamado por ≥ 2 callers.
- O número de nós passa de ~30 dentro de um workflow existente.

## Definition of Done (DoD)

Uma task em [`tasks.md`](./tasks.md) só pode ser marcada como ✅ se atender **todos** os itens abaixo:

- [ ] **Cenário de teste** documentado e executado manualmente pelo menos 1 vez (Chatwoot real ou Webhook Test).
- [ ] **Log estruturado**: cada transição crítica chama `util-log-event` com nome do evento no [vocabulário canônico](./architecture.md#vocabulário-canônico-de-eventos).
- [ ] **Métrica acessível**: é possível responder via `util-log-event` "esta funcionalidade foi usada N vezes hoje".
- [ ] **Fallback definido**: se o caminho feliz falhar, há um branch claro (re-tentar OU escalar). Nada de dead-end.
- [ ] **Comportamento de erro**: `retryOnFail: true, maxTries: 3` nas HTTP críticas; `continueOnFail` apenas em ações não-críticas (label, log).
- [ ] **Histórico preservado**: `custom_attributes.step` é setado **antes** de enviar mensagem (idempotência) e a transição fica visível no painel do Chatwoot.
- [ ] **LGPD**: nenhum CPF, telefone completo ou dado sensível em logs (mascarar para `***.***.***-12` ou últimos 4 dígitos).
- [ ] **Validado por CX/SAC**: power-user revisou copy e UX da conversa.
- [ ] **Validado tecnicamente**: dev revisou lógica, contratos e idempotência.
- [ ] **Documentação atualizada**: se mudou contrato → `architecture.md`; copy → `templates.md`; estado → `state-machine.md`; convenção → este arquivo.

> "Pronto" significa que esta funcionalidade pode entrar em produção e ser mantida por outra pessoa sem perguntar nada ao autor.
