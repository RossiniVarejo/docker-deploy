# Migration Readiness — Opção A → Opção B

> Este documento mapeia explicitamente cada decisão de design da Opção A (n8n modular) para o componente equivalente da Opção B (n8n thin + serviço backend). Se as decisões forem mantidas, a migração vira "reescrever em código" — sem rearqueologia.

## Mapeamento componente-a-componente

| Opção A (n8n)                                 | Opção B (serviço backend)                                          | Notas                                                                           |
| --------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| `martex-router` (Master workflow)             | `POST /webhooks/chatwoot` handler                                  | n8n vira gateway: recebe webhook, valida header, faz `POST` para o serviço.     |
| `ValidateAuth` (IF node)                      | Middleware `verifyWebhookToken()`                                  | Mesma regra: header X-Webhook-Token.                                            |
| `FilterEvent` (IF node)                       | Middleware `filterChatwootEvent()`                                 | Mesma regra: `event=message_created`, `incoming`, `contact`, `!private`.        |
| `NormalizeInput` (Set node)                   | Função `toCanonicalContext(rawEvent)`                              | Retorna o mesmo shape do "item canônico" definido em `architecture.md`.         |
| `Switch(step)` (Switch node)                  | `router.dispatch(state.step)`                                      | Mapa de `step → handler` em código.                                             |
| Sub-fluxos `wf-*` (cada um um workflow)       | Módulos `handlers/{topic}.ts`                                      | 1 arquivo por sub-fluxo. `wf-track-order` → `handlers/trackOrder.ts`.           |
| `util-send-message`                           | `chatwoot.sendMessage(conversationId, content)`                    | Interface de input/output igual.                                                |
| `util-set-state`                              | `state.merge(conversationId, patch)`                               | Aceita patch idempotente.                                                       |
| `util-add-label`                              | `chatwoot.addLabels(conversationId, labels)`                       |                                                                                 |
| `util-toggle-status`                          | `chatwoot.setStatus(conversationId, status)`                       |                                                                                 |
| `util-escalate`                               | `escalate(conversationId, reason, message?)`                       | Mesma composição: label + send + state + reopen.                                |
| `util-gen-protocol`                           | `generateProtocol(conversationId)`                                 | Mesmo formato `YYYYMMDD-HHMMSS-xxxx`.                                           |
| `util-log-event` v1 (Code com console.log)    | `logger.event(name, payload)`                                      | v2 (Sheets/Postgres) cabe direto no serviço.                                    |
| `cron-timeout-sweeper` (Schedule trigger)     | Job agendado (BullMQ / node-cron / k8s cron)                       | Mesma lógica, mais flexibilidade.                                               |
| `cron-postsale-dispatcher` (Schedule trigger) | Job agendado                                                       | Idem.                                                                           |
| `mock-order-lookup` (Code node)               | `orderProvider.getOrder(id)` com implementação `MockOrderProvider` | Interface `OrderProvider` — substituível por `RealOrderProvider` que chama API. |
| `mock-stock-check`                            | `stockProvider.check(sku, size, color)`                            | Mesmo padrão.                                                                   |
| `mock-warranty-check`                         | `warrantyProvider.check(orderId)`                                  | Mesmo padrão.                                                                   |
| Templates em `templates.md`                   | `templates/pt-BR.yaml` carregado no boot                           | Chaves idênticas (`welcome.menu`, ...).                                         |
| `state-machine.md` (tabela manual)            | `enum ConversationState` + função `nextState()`                    | Mesma tabela vira tipos + função pura testável.                                 |
| `custom_attributes.step` no Chatwoot          | `conversation_state` em Postgres + espelho em Chatwoot             | O Chatwoot continua exibindo o estado para o operador humano.                   |

## Stack sugerido para Opção B

### Opção preferida — Go (recomendada para este projeto)

State machine + alta concorrência + binário único → Go é encaixe natural.

- **HTTP**: `chi` (minimalista, idiomatic) ou `gin` se preferir DSL mais alta.
- **DB**: PostgreSQL com `pgx` + migrations via `golang-migrate` ou `goose`.
- **Estado**: tabela `conversation_state` keyed por `conversation_id` (espelho do `custom_attributes.step` no Chatwoot).
- **Filas/Workers**: `asynq` (Redis-backed) ou `river` (Postgres-backed) — escolha por familiaridade.
- **Logs**: `log/slog` (stdlib).
- **Validação**: `go-playground/validator`.
- **Templates**: `text/template` da stdlib carregado de `templates/pt-BR.yaml` no boot.
- **LLM**: `anthropics/anthropic-sdk-go` (Claude) ou `sashabaranov/go-openai`.
- **Observabilidade**: OpenTelemetry Go SDK → Grafana/Datadog.
- **Testes**: stdlib `testing` + `stretchr/testify` + `httptest` para handlers.
- **Build/Deploy**: Docker multi-stage (binário static) → Cloud Run / k8s / nomad.

### Alternativa — TypeScript

Caso o time tenha mais afinidade com Node:

- **Runtime**: Node 22 LTS.
- **HTTP**: NestJS (estruturado) ou Fastify (enxuto).
- **DB**: Postgres via Prisma ou drizzle-orm.
- **Filas**: BullMQ (Redis) para crons e retries.
- **Templates**: YAML/JSON carregado no boot, sem reload em runtime.
- **Observabilidade**: OpenTelemetry → Grafana/Datadog.
- **Testes**: Vitest/Jest, mocks com `OrderProvider` etc.

A escolha entre Go e TS não altera o contrato definido neste documento — todos os mapeamentos da tabela acima funcionam nas duas stacks. Decida por afinidade do time e padrão da casa.

## Checklist de readiness (validar ao fim de cada fase do roadmap A)

A migração para B fica "tranquila" quando estes 6 pontos forem ✅:

- [ ] **R1** — Contratos de utilitários (`util-*`) documentados em `architecture.md`, nunca quebrados sem versionar. Cada utilitário tem entrada/saída clara.
- [ ] **R2** — Templates centralizados em `templates.md` com chaves estáveis. Toda nova copy começa lá.
- [ ] **R3** — Máquina de estados (`step`) documentada em `state-machine.md`. Todos os valores em uso aparecem na tabela. Transições explícitas.
- [ ] **R4** — Mocks isolados em workflows `mock-*` separados. Não há lógica de mock embutida em sub-fluxos.
- [ ] **R5** — Logs estruturados via `util-log-event` nas transições críticas (set state, escalada, erro, fallback).
- [ ] **R6** — `custom_attributes` schema documentado, com todos os campos opcionais e obrigatórios listados em `architecture.md`.

Se R1–R6 estão ✅, a migração se resume a:

1. Escrever os módulos handlers + providers em TS.
2. Reescrever cada `wf-*` como teste de integração (cenários A–M já especificados).
3. Trocar o `Webhook` do n8n por um `HTTP Request` que repassa o evento ao serviço.
4. Desativar os sub-fluxos no n8n. Manter apenas o Master como gateway + crons (ou migrá-los também).

## Anti-patterns a evitar agora (que dificultariam B no futuro)

- **❌ Lógica de negócio dentro de Code nodes longos** — vira "JS encapsulado em JSON" difícil de migrar. Use IF/Switch visualizáveis.
- **❌ Estado em workflow variables** — n8n não persiste workflow variables entre execuções. Sempre `custom_attributes` ou base externa.
- **❌ Templates inline em vários sub-fluxos** — se a copy `welcome.menu` aparece em 3 lugares diferentes, qualquer edição vira caça aos 3. Mantenha em `templates.md` e referencie.
- **❌ Mocks misturados com lógica real** — `wf-track-order` chamando o mock direto em vez de via `mock-order-lookup` separado.
- **❌ Estados implícitos** — fluxos que dependem da ordem das mensagens ou de timing, sem refletir em `step`.

## Gatilhos para começar a migrar

Quando algum destes acontecer **persistentemente** (≥ 2 sprints consecutivas):

1. **Incidentes por edição inadvertida** ≥ 2/mês.
2. **Volume** > 3 000 conversas/dia com latência sentida ou queue lag.
3. **> 3 devs** envolvidos em paralelo no fluxo (conflitos de PR aumentam).
4. **Spec estabilizou** — não muda copy/regra a cada sprint (testes valem a pena).
5. **Necessidade de features que n8n não oferece bem** — ex.: pipeline ML interno, A/B testing nativo, multi-tenant, observabilidade fina.

Não migrar antes desses sinais aparecerem — Opção A entrega valor mais rápido enquanto eles não aparecem.

## Custo estimado da migração

Considerando R1–R6 ✅ ao fim das Fases 0–3 da Opção A:

- **Scaffolding do serviço (Go ou TS + DB + filas + auth)**: 1–2 semanas (1 dev sênior).
- **Reescrita dos handlers** (Etapa por Etapa, com testes): 2–4 semanas.
- **Migração dos crons + observabilidade**: 1 semana.
- **Validação paralela** (rodar A e B simultaneamente em sombra): 1–2 semanas.

**Total**: 5–9 semanas. Sem R1–R6 prontos, dobra esse tempo.

---

## Referência futura — desenho do serviço backend (B)

Conteúdo extraído de `v2-chatgpt.md` e adaptado. Serve de norte para quem implementar a Opção B no futuro — não é compromisso de hoje.

### APIs internas sugeridas

```http
POST   /conversations                        # cria sessão
POST   /conversations/{id}/messages          # registra mensagem (in/out)
GET    /conversations/{id}                   # estado + histórico
POST   /conversations/{id}/escalate          # dispara escalada
POST   /conversations/{id}/attachments       # registra anexo
POST   /protocols                            # gera protocolo
GET    /protocols/{code}                     # busca por código MMT-...
POST   /automation/events                    # publica evento para n8n consumir
GET    /health, /ready, /metrics             # operacional
```

Eventos publicados em `POST /automation/events` seguem o mesmo vocabulário canônico já usado em `util-log-event` da Opção A — ver [`architecture.md`](./architecture.md#vocabulário-canônico-de-eventos).

### Schema de banco (sugestão — Postgres)

| Tabela                | Conteúdo principal                                                                         |
| --------------------- | ------------------------------------------------------------------------------------------ |
| `conversations`       | id, channel, customer_id, started_at, closed_at, current_state, protocol, csat             |
| `messages`            | id, conversation_id, sender_kind (bot/agent/customer/system), content, sent_at, intent?    |
| `protocols`           | code (MMT-...), conversation_id, created_at, status                                        |
| `conversation_events` | id, conversation_id, event (canônico), payload (jsonb), ts                                 |
| `escalations`         | id, conversation_id, reason, agent_id?, created_at, resolved_at                            |
| `attachments`         | id, conversation_id, message_id, kind (photo/nf), url, mime, size, received_at             |
| `intents`             | id, conversation_id, message_id, label, confidence, classifier_version                     |
| `timeout_events`      | id, conversation_id, kind (warning/closed), fired_at                                       |
| `post_sale_jobs`      | id, order_id, conversation_id?, scheduled_for, sent_at, result (positive/neutral/negative) |

Índices recomendados: `(conversation_id, ts)` em events/messages; `code` em protocols; `(scheduled_for, sent_at)` em post_sale_jobs.

### Estrutura de monorepo (sugestão — Go)

```
martex-chatbot/
├── cmd/
│   ├── api/                  # entrypoint do serviço HTTP
│   ├── worker/               # entrypoint dos workers (asynq/river)
│   └── migrate/              # CLI de migrations
├── internal/
│   ├── chat/                 # state machine + handlers por sub-fluxo
│   ├── chatwoot/             # client HTTP do Chatwoot
│   ├── order/                # OrderProvider + implementações (mock, real)
│   ├── protocol/             # gerador MMT-...
│   ├── templates/            # carregamento de pt-BR.yaml
│   ├── events/               # publisher / canonical event names
│   ├── observability/        # otel, slog setup
│   └── storage/              # repositórios sobre Postgres (pgx)
├── pkg/                      # exports reutilizáveis (se houver)
├── migrations/               # SQL goose/migrate
├── templates/
│   └── pt-BR.yaml            # vindo de templates.md (Opção A)
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
└── docs/
    ├── architecture.md
    └── runbooks/
```

Equivalente em TS: `apps/api`, `apps/worker`, `packages/domain`, `packages/database`, `packages/integrations`.

### Backoffice mínimo (post-B)

Funcionalidades sugeridas para a tela administrativa:

- Buscar por protocolo (`MMT-YYYYMM-NNNNNN`)
- Ver conversa + histórico + anexos
- Ver cliente + tags
- Ver motivo de escalada
- Reenviar para atendimento humano
- Encerrar conversa manualmente
- Adicionar/remover tag

### Papéis e permissões

| Perfil         | Acesso                                     |
| -------------- | ------------------------------------------ |
| Admin          | Tudo                                       |
| Supervisor SAC | Conversas, métricas, escaladas, reatribuir |
| Atendente      | Conversas atribuídas a si                  |
| CX/Qualidade   | Relatórios, tags, leitura ampla            |
| TI/Dev         | Logs técnicos, configurações               |
| Auditor        | Leitura completa, sem ações                |

> Tudo nesta seção é referência para o time que vier a fazer a Opção B. Hoje, em Opção A, o Chatwoot nativo já cumpre boa parte (busca, atribuição, tags). O que falta é o relatório por protocolo e a visão consolidada de eventos — entra na Fase 4 da Opção A via dashboard.
