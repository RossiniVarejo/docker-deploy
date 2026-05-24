# Tasks — Execução do Chatbot martex (Opção A)

Backlog executável. Cada task é PR-sized. Marque o checkbox ao concluir e atualize o status correspondente no [`README.md`](./README.md).

## Convenções

- **ID**: `T<fase>.<sequência>` (ex.: `T0.1`).
- **Estimativa**: P=Pequena (<½ dia) · M=Média (½–1 dia) · G=Grande (1–3 dias).
- **Dependências**: tasks anteriores que precisam estar prontas.
- **DoD** (Definition of Done) em cada task: workflow exportado em `../`, cenário coberto, checkbox marcado, status atualizado.

---

## Fase 0 — Refatoração da v4 para estrutura modular

> **Meta da fase**: rodar os mesmos cenários A–M da v4 contra a nova estrutura sem regressão. Sem novas features ainda.

- [x] **T0.1** · `util-send-message` (P) — sub-workflow gatilhado por `Execute Workflow`, recebe `{ accountId, conversationId, content }`, faz POST `…/messages` com `JSON.stringify(content)`. Retorna `{ ok, messageId? }`. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/util-send-message.json`
- [x] **T0.2** · `util-set-state` (P) — idempotente, merge em `custom_attributes`. Aceita `{ accountId, conversationId, patch }`. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/util-set-state.json`
- [x] **T0.3** · `util-add-label`, `util-toggle-status` (P) — wrappers com retry e `continueOnFail`. Dep: nenhuma. ✅ 2026-05-21 · workflows em `AI-Flow/workflows/util-add-label.json` e `AI-Flow/workflows/util-toggle-status.json`
- [x] **T0.4** · `util-gen-protocol` (P) — gera ID `YYYYMMDD-HHMMSS-xxxx` via Code node, grava em `custom_attributes.protocol` via `util-set-state`. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/util-gen-protocol.json`
- [x] **T0.5** · `util-escalate` (M) — compõe label + send + state + reopen. Aceita `reason` para incluir no label. Dep: T0.1–T0.4. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/util-escalate.json`
- [x] **T0.6** · `util-log-event` v1 (P) — mock que apenas faz `console.log`. Interface estável para a v2 (Sheets/Postgres) na Fase 4. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/util-log-event.json`
- [x] **T0.7** · `martex-router` (M) — Master: Webhook → ValidateAuth → FilterEvent → NormalizeInput → Switch(step) → `Execute Workflow` no sub-fluxo. Dep: T0.1–T0.6. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/martex-router.json`
- [x] **T0.8** · `wf-welcome` extraído (M) — Etapa 1 da v4 isolada. Dep: T0.7. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/wf-welcome.json`
- [x] **T0.9** · `wf-track-order` extraído (G) — Etapa 2.1 da v4 isolada. `MockOrderLookup` continua dentro até Fase 1 separar para `mock-order-lookup`. Dep: T0.7. ✅ 2026-05-21 · workflow em `AI-Flow/workflows/wf-track-order.json`
- [ ] **T0.10** · Rodar cenários A–M (M) — manualmente via Chatwoot ou via Postman direto no webhook. Corrigir regressões. Dep: T0.8–T0.9.
- [ ] **T0.11** · Arquivar v4 (P) — renomear `Martex-Chatbot-v4.json` para `_archived-Martex-Chatbot-v4.json` ou mover para `../archive/`. Atualizar README.

**Saída esperada da Fase 0**: 7 utilitários + Master + 2 sub-fluxos rodando, v4 monolito arquivado, sem regressão.

---

## Fase 1 — Etapas 2.2 a 2.6

> **Meta**: cobrir todos os sub-fluxos por tema. Cliente passa a ter respostas para qualquer escolha do menu.

- [ ] **T1.1** · `mock-order-lookup` extraído (P) — tira o Code node de `wf-track-order` para um workflow próprio. Dep: T0.9.
- [ ] **T1.2** · `mock-stock-check` (P) — devolve disponibilidade fictícia por SKU.
- [ ] **T1.3** · `mock-warranty-check` (P) — devolve dentro/fora de garantia conforme dias desde compra.
- [ ] **T1.4** · `mock-email-sender` (P) — devolve `{ sent: true }` sem fazer nada.
- [ ] **T1.5** · `wf-trade-return` (G) — Etapa 2.2 completa: submenu 4 motivos → validação 7 dias → geração de protocolo OU escalada. Dep: T1.2, T1.3, T1.4.
- [ ] **T1.6** · `wf-delivery-time` (M) — Etapa 2.3: consulta `mock-order-lookup` → mensagem com previsão; atraso → escalada. Dep: T1.1.
- [ ] **T1.7** · `wf-defect` (G) — Etapa 2.4: coleta pedido + 2 fotos + nota → gera protocolo → **sempre escala**. Dep: T0.5, T1.3.
- [ ] **T1.8** · `wf-product-info` (M) — Etapa 2.5: submenu 5 opções com copies fixas + link site.
- [ ] **T1.9** · `wf-other-subject` (G) — Etapa 2.6: IA classifica em 2.1–2.5 → `Execute Workflow` correspondente; falha 2x → escala. Dep: T1.5–T1.8.
- [ ] **T1.10** · Atualizar `martex-router` Switch para incluir os novos `step` (G) — `trade-return:*`, `delivery-time:*`, `defect:*`, `product-info:*`, `other:*`. Dep: T1.5–T1.9.
- [ ] **T1.11** · Bateria de cenários (M) — cobrir cada motivo de troca, cada status de defeito, cada sub-opção de produto. Adicionar à suíte de testes manual.

**Saída esperada da Fase 1**: bot cobre menu inteiro 1–6, escalada manual ainda usa critério único (não localizado/inválido).

---

## Fase 2 — Cross-cutting (fallback, escalada refinada, encerramento)

> **Meta**: comportamento de qualidade — fallback progressivo, escalada por todos os 8 critérios, encerramento com CSAT.

- [ ] **T2.1** · `wf-fallback` (G) — Etapa 5: 3 níveis com contador `custom_attributes.fallback_attempts`. Dep: Fase 1 completa.
- [ ] **T2.2** · Refinar `util-escalate` (M) — aceitar 8 reasons distintas (procon, valor-alto, troca-temas, defeito-foto, fora-horario, ...) → cada uma com label específica.
- [ ] **T2.3** · Detector de "fala com humano" (P) — Set node em `martex-router` que detecta frases tipo "quero falar com atendente", "humano", "pessoa real" → força escalada antes do Switch.
- [ ] **T2.4** · Detector de Procon / Reclame Aqui / crise (M) — regex no input do cliente, gatilho de escalada imediato.
- [ ] **T2.5** · Detector de outro idioma (P) — heurística simples (caracteres não-PT) → mensagem bilíngue + escalada se persistir.
- [ ] **T2.6** · Contador `topic_switches` (P) — incrementa quando cliente troca de tema; ≥3 → escala.
- [ ] **T2.7** · `wf-close` (M) — Etapa 4: encerramento + CSAT opcional (1–5 estrelas via texto) → grava em `custom_attributes.csat`.
- [ ] **T2.8** · `wf-on-resolved` (M) — Webhook trigger separado escutando `conversation_resolved` → reseta `step`, mantém `protocol` por 30 dias (LGPD).

**Saída esperada da Fase 2**: bot trata "todos" os caminhos do documento martex v3 em tempo real (síncrono).

---

## Fase 3 — Agendados (Etapa 6 e 7)

> **Meta**: comportamento assíncrono. Timeout e pós-venda.

- [ ] **T3.1** · `cron-timeout-sweeper` (G) — Schedule a cada 5min. Para cada conversa com step ativo + `last_activity_at > 10min` → lembrete via `util-send-message`; `> 20min` → encerra via `wf-close`. Idempotência via flag `custom_attributes.timeout_reminded_at`.
- [ ] **T3.2** · `cron-postsale-dispatcher` (G) — Schedule a cada 1h em horário comercial. Lista pedidos entregues D-2/D-3 (mock por enquanto). Para cada: cria/abre conversa Chatwoot + envia mensagem com 3 botões. Idempotência: `custom_attributes.postsale_sent`.
- [ ] **T3.3** · Ramificações pós-venda (M) — `wf-postsale-positive`, `wf-postsale-neutral`, `wf-postsale-negative`. A última escala obrigatoriamente.
- [ ] **T3.4** · Regras de horário (P) — `cron-postsale-dispatcher` só dispara seg–sex 9h–18h. Lista de feriados em um workflow `data-holidays-br` (ou Code node).

**Saída esperada da Fase 3**: comportamento completo cobrindo as 7 etapas do documento.

---

## Fase 4 — Operacional (pode rodar em paralelo com Fase 3)

> **Meta**: confiabilidade e observabilidade em produção.

- [ ] **T4.1** · Error Workflow do n8n (M) — Workflow Settings → Error Workflow. Aponta para `util-log-event` v2 + alerta em Slack/e-mail.
- [ ] **T4.2** · `util-log-event` v2 (M) — substituir mock por Google Sheets ou Postgres. **Contrato igual ao da v1** — não pode quebrar callers.
- [ ] **T4.3** · Suite de cenários formalizada (M) — planilha com 25+ cenários cobrindo as 7 etapas + casos de erro. Executar antes de cada deploy.
- [ ] **T4.4** · `.env.example` (P) — listar todas as env vars + descrição em `architecture.md`.
- [ ] **T4.5** · Dashboard de métricas (M) — query Postgres ou planilha que mostra: % de auto-resolução, % de escalada, tempo médio, CSAT médio.

---

## Fase 5 — Preparação contínua para Opção B

> **Não é uma fase com data — é um checklist validado ao fim de cada outra fase.**

- [ ] **T5.1** · Contrato dos utilitários estável e documentado em `architecture.md`. Não muda sem versionar.
- [ ] **T5.2** · Templates centralizados em `templates.md`. Toda nova copy começa por lá.
- [ ] **T5.3** · `custom_attributes.step` documentado em `state-machine.md` com todos os valores.
- [ ] **T5.4** · Workflows `mock-*` isolados — não há mocks dentro de sub-fluxos.
- [ ] **T5.5** · Logs via `util-log-event` em todas as transições críticas (set state, escalada, erro).
- [ ] **T5.6** · README + PRD atualizados a cada fase.

> Quando esses 6 pontos estiverem ✅ no fim de cada fase, a migração para a Opção B fica reduzida a "reescrever em código" — sem rearqueologia.

---

## Backlog não priorizado (post-v1)

- Pagamento in-chat (PIX, link).
- Criação de pedido novo via bot.
- Integração ERP/OMS real (substitui `mock-*`).
- Multi-loja em paralelo.
- Voz/áudio.
- A/B testing de copies.
