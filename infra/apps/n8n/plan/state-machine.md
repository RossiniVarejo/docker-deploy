# State Machine — `custom_attributes.step`

`custom_attributes.step` é a fonte de verdade do estado conversacional. Vive no objeto da conversa Chatwoot, é lido pelo Master no `NormalizeInput` e gravado pelos sub-fluxos via `util-set-state` antes de enviar qualquer mensagem.

## Convenção de naming

- Estados terminais ou neutros: 1 palavra (`completed`, `escalated`).
- Estados aguardando input do cliente: `<topic>:awaiting-<thing>` (ex.: `track-order:awaiting-id`).
- Estados internos de sub-fluxo: `<topic>:<step-name>` (ex.: `trade-return:awaiting-reason`, `defect:awaiting-photos`).

Sempre kebab-case. Sem espaços. Topic em singular.

## Tabela canônica

| step | descrição | entra a partir de | sai para |
|------|-----------|-------------------|----------|
| _vazio_ ou ausente | conversa nova, bot ainda não interagiu | (default Chatwoot) | `awaiting-menu-choice` |
| `completed` | atendimento resolvido pelo bot; conversa "limpa" | qualquer sub-fluxo após sucesso | `awaiting-menu-choice` (nova interação) |
| `awaiting-menu-choice` | bot enviou menu 1–6, aguarda escolha | após `wf-welcome`; após `completed`; após retry | `track-order:awaiting-id`, `trade-return:awaiting-reason`, `delivery-time:awaiting-id`, `defect:awaiting-order`, `product-info:awaiting-subtopic`, `other:awaiting-text`, `escalated`, ou retry de si mesmo |
| `track-order:awaiting-id` | aguarda número do pedido ou CPF (E2.1) | escolha "1" | `completed` (status OK), `escalated` (2 falhas), retry de si mesmo |
| `trade-return:awaiting-reason` | aguarda motivo da troca (E2.2) | escolha "2" | `trade-return:awaiting-order-id`, `trade-return:awaiting-stock-info`, `defect:awaiting-order` (delega), `escalated` |
| `trade-return:awaiting-order-id` | aguarda pedido para validar 7 dias | motivo = arrependimento | `trade-return:confirming-conditions`, `escalated` |
| `trade-return:confirming-conditions` | aguarda confirmação "embalagem + nota OK" | após validação de prazo | `completed` (protocolo gerado), `escalated` |
| `trade-return:awaiting-stock-info` | aguarda pedido + descrição do produto correto | motivo = tamanho/cor errado | `completed`, `escalated` (sem estoque) |
| `delivery-time:awaiting-id` | aguarda pedido ou CPF para prazo (E2.3) | escolha "3" | `completed`, `escalated` (atraso > 5 dias) |
| `defect:awaiting-order` | aguarda número do pedido (E2.4) | escolha "4" ou delegação de E2.2 | `defect:awaiting-photos` |
| `defect:awaiting-photos` | aguarda foto do defeito + foto da nota | após número do pedido | `defect:awaiting-choice` |
| `defect:awaiting-choice` | aguarda escolha "troca" ou "reembolso" | após fotos | `escalated` (sempre escala após registro) |
| `product-info:awaiting-subtopic` | aguarda sub-opção 1–5 (E2.5) | escolha "5" | `completed` |
| `other:awaiting-text` | aguarda texto livre do cliente (E2.6) | escolha "6" | qualquer step de E2.1–2.5 (se IA classificar), `escalated` (2 falhas) |
| `escalated` | humano assumiu a conversa | qualquer ponto via `util-escalate` | (humano fecha → `conversation_resolved` → `wf-on-resolved` zera) |
| `closed-csat-pending` | bot pediu CSAT, aguarda nota | após `wf-close` | `completed` (com ou sem CSAT) |
| `postsale-awaiting-reply` | mensagem de pós-venda enviada (E7) | `cron-postsale-dispatcher` | `postsale-positive`, `postsale-neutral`, `postsale-negative`, ou `completed` (sem resposta após 24h) |
| `postsale-negative` | cliente reportou problema (E7 ramo C) | escolha "❌" | `escalated` |

## Transições inválidas

Se um sub-fluxo recebe um valor de `step` que não espera (ex.: `wf-track-order` é chamado com `step = "trade-return:awaiting-reason"`), o comportamento é:

1. Logar via `util-log-event` com `{ event: "invalid-transition", expected: [...], got }`.
2. Disparar `wf-fallback` (E5) com a mensagem atual.

Nenhum sub-fluxo deve "consertar" estado errado silenciosamente — sempre cair para o fallback formal.

## Reset de estado

Acontece em 3 momentos:
1. Após sucesso de fluxo: sub-fluxo grava `step = "completed"`.
2. Após `conversation_resolved` no Chatwoot: `wf-on-resolved` grava `step = ""` (limpa também `attempts`, mantém `protocol` por 30 dias).
3. Após 20min de timeout: `cron-timeout-sweeper` chama `wf-close` que grava `step = "completed"`.

## Counters

Contadores ficam em `custom_attributes`:
- `attempts` — incrementa a cada retry dentro do mesmo step. Zera quando muda de step.
- `fallback_attempts` — incrementa a cada vez que `wf-fallback` é chamado. Zera no fim de fluxo bem-sucedido.
- `topic_switches` — incrementa quando cliente muda de topic (ex.: estava em track-order, agora pediu trade-return). ≥3 → escala (E3 critério #7).

## Preparação para Opção B

Os valores acima viram um `enum ConversationState` em TypeScript:

```ts
enum ConversationState {
  None = "",
  Completed = "completed",
  AwaitingMenuChoice = "awaiting-menu-choice",
  TrackOrderAwaitingId = "track-order:awaiting-id",
  TradeReturnAwaitingReason = "trade-return:awaiting-reason",
  // ...
  Escalated = "escalated",
}
```

A tabela de transições vira uma função `nextState(current, event): State` totalmente testável.
