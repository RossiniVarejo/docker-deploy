# Arquitetura — Opção A (n8n modular)

## Visão geral

```
Chatwoot ──webhook──> martex-router (Master)
                         │
                         ▼
                    Switch(step)
                         │
        ┌────────────────┼─────────────────┬─────────────────┐
        ▼                ▼                 ▼                 ▼
   wf-welcome       wf-track-order   wf-trade-return    ... (10 sub-fluxos)
        │                │                 │
        └────────────────┴─────────────────┴────► utilitários:
                                                  util-send-message
                                                  util-set-state
                                                  util-add-label
                                                  util-toggle-status
                                                  util-escalate
                                                  util-gen-protocol
                                                  util-log-event

Cron triggers paralelos (não passam pelo router):
   cron-timeout-sweeper     — varre conversas com step ativo
   cron-postsale-dispatcher — agenda mensagens D+2/D+3
```

## Componentes

### Master · `martex-router`

Único workflow exposto ao webhook do Chatwoot. Responsabilidades:

1. `Webhook` recebe POST.
2. `ValidateAuth` — header `X-Webhook-Token === $env.CHATWOOT_WEBHOOK_SECRET`.
3. `FilterEvent` — exige `event=message_created`, `message_type=incoming`, `sender.type=contact`, `private != true`.
4. `NormalizeInput` — extrai o item canônico (ver "Contrato de dados" abaixo).
5. `Switch(step)` — roteamento por valor de `custom_attributes.step` para o sub-fluxo correto via `Execute Workflow`.
6. Cada sub-fluxo executa e retorna (Master apenas espera).

Estimativa: ~30 nós.

### Sub-fluxos (`wf-*`)

Cada sub-fluxo é um workflow independente acionado via `Execute Workflow`. Recebe o item canônico do Master e executa sua máquina de estados própria. Pode chamar utilitários e outros sub-fluxos.

| Sub-fluxo          | Cobre Etapa            | Estima nós |
| ------------------ | ---------------------- | ---------- |
| `wf-welcome`       | E1                     | 8          |
| `wf-track-order`   | E2.1                   | 20         |
| `wf-trade-return`  | E2.2                   | 35         |
| `wf-delivery-time` | E2.3                   | 15         |
| `wf-defect`        | E2.4                   | 25         |
| `wf-product-info`  | E2.5                   | 25         |
| `wf-other-subject` | E2.6                   | 15         |
| `wf-fallback`      | E5                     | 15         |
| `wf-close`         | E4                     | 10         |
| `wf-on-resolved`   | (limpeza pós-resolved) | 8          |

### Utilitários (`util-*`)

Cada utilitário é um workflow chamável via `Execute Workflow` com contrato estável. **Não devem ser editados sem versionar o contrato.**

#### `util-send-message`

- **Input**: `{ accountId, conversationId, content }`
- **Output**: `{ ok: bool, messageId? }`
- **Ação**: POST `…/conversations/{id}/messages` com `JSON.stringify(content)` para evitar quebra por aspas/`\n`.

#### `util-set-state`

- **Input**: `{ accountId, conversationId, patch: { step?, topic?, attempts?, protocol?, ... } }`
- **Output**: `{ ok: bool }`
- **Ação**: POST `…/conversations/{id}/custom_attributes` com merge no objeto existente.
- **Idempotência**: aceitar set repetido com mesmo valor sem erro.

#### `util-add-label`

- **Input**: `{ accountId, conversationId, labels: string[] }`
- **Output**: `{ ok: bool }`
- **Ação**: POST `…/conversations/{id}/labels` com `continueOnFail` (label não-crítico).

#### `util-toggle-status`

- **Input**: `{ accountId, conversationId, status: "open" | "resolved" | "pending" }`
- **Output**: `{ ok: bool }`

#### `util-escalate`

- **Input**: `{ accountId, conversationId, reason, message? }`
- **Output**: `{ ok: bool, protocol }`
- **Ação**: composição de:
  1. `util-gen-protocol`
  2. `util-add-label` com `["escalado-humano", reason]`
  3. `util-send-message` com `message` ou copy padrão de escalada
  4. `util-set-state` com `{ step: "escalated", protocol }`
  5. `util-toggle-status` com `"open"`

#### `util-gen-protocol`

- **Input**: `{ accountId, conversationId, prefix? }`
- **Output**: `{ protocol: string }` — formato canônico `MMT-YYYYMM-NNNNNN` (ex.: `MMT-202605-000123`).
- **Ação**: gera ID sequencial via Code node (sequência mensal vem de um contador em `custom_attributes` global ou de uma planilha/DB de controle) + grava em `custom_attributes.protocol` via `util-set-state`.
- **Idempotência**: se a conversa já tem `protocol`, retorna o existente em vez de gerar novo.

#### `util-log-event`

- **Input**: `{ conversationId, event, payload }`
- **Output**: `{ ok }`
- **Ação inicial**: Code node que apenas escreve em console.log (mock). Fase 4: substituir por Google Sheets ou Postgres real, **sem mudar o contrato**.

##### Vocabulário canônico de eventos

Todo evento gravado por `util-log-event` usa um destes nomes (formato `<noun>.<verb>` ou `<noun>.<state>`):

| Evento                           | Quando emitir                                        |
| -------------------------------- | ---------------------------------------------------- |
| `conversation.started`           | primeira mensagem do cliente, `wf-welcome` disparado |
| `state.transition`               | qualquer chamada de `util-set-state`                 |
| `intent.classified`              | IA retornou classificação (E2.6 ou E5)               |
| `order.lookup.requested`         | sub-fluxo prestes a consultar `mock-order-lookup`    |
| `order.lookup.failed`            | mock/api retornou `not_found`                        |
| `order.delayed`                  | atraso > 5 dias detectado em E2.3                    |
| `exchange.requested`             | E2.2 — cliente iniciou troca                         |
| `defect.reported`                | E2.4 — protocolo criado                              |
| `attachment.received`            | foto/nota recebida pelo bot                          |
| `human.escalation.requested`     | `util-escalate` chamado                              |
| `fallback.triggered`             | `wf-fallback` ativado (incluir `level`: 1/2/3)       |
| `timeout.warning_sent`           | E6 — lembrete 10min enviado                          |
| `timeout.session_closed`         | E6 — encerramento 20min                              |
| `conversation.closed`            | `wf-close` executado com sucesso                     |
| `post_sale.scheduled`            | `cron-postsale-dispatcher` agendou disparo           |
| `post_sale.sent`                 | mensagem D+2/D+3 enviada                             |
| `post_sale.customer_unsatisfied` | cliente respondeu "❌"                               |
| `csat.submitted`                 | cliente respondeu nota 1–5                           |
| `error.unhandled`                | exception em qualquer workflow                       |

> **Preparação para B**: a tabela acima vira o `enum Event` no serviço Go/TS. Os logs gravados pela v4-A devem ser **idênticos em formato** aos da v1-B — assim análises históricas não quebram na migração.

#### Payload mínimo de cada evento

Independente do `event` específico, o objeto sempre inclui:

```json
{
  "event": "<nome do evento>",
  "ts": "<ISO timestamp>",
  "conversation_id": <int>,
  "account_id": <int>,
  "protocol": "<MMT-YYYYMM-NNNNNN ou null>",
  "channel": "whatsapp",
  "current_state": "<valor de step>",
  "payload": { ... específico do evento ... }
}
```

### Convenção de labels Chatwoot

Labels aplicadas pela `util-add-label` (e por extensão `util-escalate`) seguem nomenclatura `snake_case`:

| Label                      | Aplicada quando                              |
| -------------------------- | -------------------------------------------- |
| `escalado_humano`          | qualquer escalada via `util-escalate`        |
| `produto_com_defeito`      | E2.4 — defeito registrado                    |
| `pos_venda_prioritario`    | E7 — cliente reportou problema na pós-venda  |
| `procon_reclame_aqui`      | E5 — menção detectada                        |
| `valor_alto`               | escalada por valor de pedido > R$500         |
| `troca_temas_recorrente`   | escalada por > 3 trocas de assunto           |
| `cliente_solicitou_humano` | escalada por pedido explícito                |
| `fora_horario`             | escalada disparada fora do horário comercial |
| `troca_devolucao`          | E2.2 (qualquer motivo)                       |
| `defeito_aparente`         | E2.4 dentro de garantia                      |
| `atraso_logistico`         | E2.3 atraso > 5 dias                         |

> Cada label deve ser pré-criada no Chatwoot (Settings → Labels). `util-add-label` usa `continueOnFail` para evitar quebrar se a label não existir — mas no deploy inicial, garantir que todas estão criadas.

### Cron jobs

#### `cron-timeout-sweeper`

- Trigger: `Schedule Trigger` a cada 5min.
- Busca em Chatwoot conversas com `step ∈ { awaiting-menu-choice, track-order:awaiting-id, ... }` e `last_activity_at < now - 10min`.
- Para cada: dispara lembrete via `util-send-message` se ainda não enviou; se `last_activity_at < now - 20min`, encerra.

#### `cron-postsale-dispatcher`

- Trigger: `Schedule Trigger` a cada 1h, seg–sex 9h–18h.
- Lista pedidos entregues em D-2 / D-3 (consulta mock por enquanto).
- Para cada pedido: cria/abre conversa Chatwoot do contato + envia mensagem inicial de pós-venda.
- Restrição: 1x por pedido (consulta `custom_attributes.postsale_sent`).

## Contrato de dados (item canônico)

Trafegado entre Master ↔ sub-fluxos ↔ utilitários:

```ts
type CanonicalItem = {
  accountId: number; // conta Chatwoot
  conversationId: number; // conversa Chatwoot
  content: string; // texto enviado pelo cliente (trim)
  senderId?: number; // ID do contato
  labels: string[]; // labels atuais da conversa
  customAttrs: {
    step: string; // valor da máquina de estados — ver state-machine.md
    topic?: string; // metadado opcional ("track-order", "trade-return", ...)
    attempts?: number; // contador de tentativas no passo atual
    protocol?: string; // protocolo gerado por util-gen-protocol
    [k: string]: unknown; // outros atributos específicos do sub-fluxo
  };
};
```

> **Preparação para B**: este shape vira o tipo `ConversationContext` em TypeScript no serviço backend.

## Schema de `custom_attributes`

Documentado em detalhe em [`state-machine.md`](./state-machine.md). Resumo:

- `step` (string, obrigatório quando há fluxo ativo) — valor da máquina de estados.
- `topic` (string, opcional) — etapa em curso.
- `attempts` (number, opcional) — contador de tentativas.
- `protocol` (string, opcional) — protocolo após escalada/registro.
- `fallback_attempts` (number, opcional) — contador específico do fallback E5.
- `postsale_sent` (boolean, opcional) — usado pelo `cron-postsale-dispatcher` para idempotência.
- `topic_switches` (number, opcional) — usado pelo critério E3 #7 (>3 trocas).

## Mocks

Cada integração externa que ainda não tem API real fica num workflow `mock-*`:

- `mock-order-lookup` — substitui consulta de pedido (E2.1, E2.2, E2.3).
- `mock-stock-check` — substitui consulta de disponibilidade (E2.2 troca tamanho/cor).
- `mock-warranty-check` — substitui consulta de garantia (E2.4).
- `mock-email-sender` — substitui envio de e-mail (E2.2, E2.4).

Quando a API real existir, a substituição é trocar o conteúdo do workflow `mock-*` por um `HTTP Request` mantendo o mesmo shape de saída.

## Idempotência

Princípios aplicados em todos os sub-fluxos:

1. **Set state ANTES de send message** — se o webhook for repetido, o segundo evento já vê o novo `step` e segue por outro caminho.
2. **`util-set-state` aceita patch idempotente** — chamar 2x com mesmo valor é OK.
3. **`util-gen-protocol` é gravado em `custom_attributes`** — segunda chamada não gera protocolo novo se já existe (verificar antes).

## Observabilidade

- **Error Workflow** do n8n configurado em `Workflow Settings → Error Workflow` apontando para `util-log-event` + (futuro) alerta em Slack.
- Cada `util-set-state` registra evento `state.transition` via `util-log-event`.
- Cada `util-escalate` registra `escalation.triggered` com `reason`.

## Variáveis de ambiente

```
CHATWOOT_BASE_URL=https://talk.akaops.com.br
CHATWOOT_API_ACCESS_TOKEN=<token>
CHATWOOT_WEBHOOK_SECRET=<secret usado no header X-Webhook-Token>
# Futuro (Fase 1+):
ORDER_API_URL=<url-da-api-real>
ORDER_API_TOKEN=<token>
LOG_SHEET_ID=<id da planilha de auditoria, se Google Sheets>
```
