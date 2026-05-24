# Martex Chatbot — Pasta de Planejamento

Documentação viva do projeto de chatbot martex rodando em n8n + Chatwoot/WhatsApp. Esta pasta contém o PRD, arquitetura, estado, copies e plano de execução. Os workflows propriamente ditos ficam em `../` (arquivos `.json`).

## Status atual

| Etapa                      | Workflow alvo              | Status                  |
| -------------------------- | -------------------------- | ----------------------- |
| E1 — Boas-vindas & Triagem | `wf-welcome`               | � extraído (2026-05-21) |
| E2.1 — Acompanhar Pedido   | `wf-track-order`           | � extraído (2026-05-21) |
| E2.2 — Troca/Devolução     | `wf-trade-return`          | ⚪ a fazer              |
| E2.3 — Prazo de entrega    | `wf-delivery-time`         | ⚪ a fazer              |
| E2.4 — Produto com defeito | `wf-defect`                | ⚪ a fazer              |
| E2.5 — Info produto        | `wf-product-info`          | ⚪ a fazer              |
| E2.6 — Outro assunto       | `wf-other-subject`         | ⚪ a fazer              |
| E3 — Escalada humana       | `util-escalate`            | 🟡 versão básica no v4  |
| E4 — Encerramento + CSAT   | `wf-close`                 | ⚪ a fazer              |
| E5 — Fallback (3 níveis)   | `wf-fallback`              | ⚪ a fazer              |
| E6 — Timeout 10/20min      | `cron-timeout-sweeper`     | ⚪ a fazer              |
| E7 — Pós-venda D+2/D+3     | `cron-postsale-dispatcher` | ⚪ a fazer              |

Legenda: ⚪ não iniciado · 🟡 em andamento · 🟢 concluído

## Fase 0 — Progresso de utilitários

| Task  | Workflow                               | Status                    |
| ----- | -------------------------------------- | ------------------------- |
| T0.1  | `util-send-message`                    | 🟢 concluído (2026-05-21) |
| T0.2  | `util-set-state`                       | 🟢 concluído (2026-05-21) |
| T0.3  | `util-add-label`, `util-toggle-status` | 🟢 concluído (2026-05-21) |
| T0.4  | `util-gen-protocol`                    | 🟢 concluído (2026-05-21) |
| T0.5  | `util-escalate`                        | 🟢 concluído (2026-05-21) |
| T0.6  | `util-log-event` v1                    | 🟢 concluído (2026-05-21) |
| T0.7  | `martex-router`                        | 🟢 concluído (2026-05-21) |
| T0.8  | `wf-welcome` extraído                  | 🟢 concluído (2026-05-21) |
| T0.9  | `wf-track-order` extraído              | 🟢 concluído (2026-05-21) |
| T0.10 | Cenários A–M                           | ⚪ a fazer                |
| T0.11 | Arquivar v4                            | ⚪ a fazer                |

## Navegação

- [`PRD.md`](./PRD.md) — visão, personas, métricas, escopo
- [`architecture.md`](./architecture.md) — desenho da Opção A, contratos, utilitários
- [`state-machine.md`](./state-machine.md) — valores de `custom_attributes.step` e transições
- [`templates.md`](./templates.md) — todas as copies martex, nomeadas
- [`tasks.md`](./tasks.md) — backlog executável com checkboxes
- [`conventions.md`](./conventions.md) — nomenclatura, PR, code review
- [`migration-to-b.md`](./migration-to-b.md) — preparações para futura migração para serviço backend

## Setup local

1. n8n self-hosted ou n8n.cloud com acesso ao Chatwoot.
2. Importar workflows da pasta `../` (ordem: utilitários → master → sub-fluxos).
3. Configurar env vars no n8n:
   ```
   CHATWOOT_BASE_URL=https://talk.akaops.com.br
   CHATWOOT_API_ACCESS_TOKEN=<token>
   CHATWOOT_WEBHOOK_SECRET=<gerar valor longo>
   ```
4. No Chatwoot: Settings → Integrations → Webhooks → URL do `martex-router` + header `X-Webhook-Token: <CHATWOOT_WEBHOOK_SECRET>` + evento `message_created`.

## Como contribuir

1. Pegue uma task em [`tasks.md`](./tasks.md) (T-prefixadas).
2. Crie o workflow no n8n, exporte JSON e salve em `../<nome-workflow>.json`.
3. Atualize o checkbox em `tasks.md` e a tabela de status acima.
4. Code review: 1 dev valida lógica/contratos; 1 power-user valida copy/UX. Ver [`conventions.md`](./conventions.md).
