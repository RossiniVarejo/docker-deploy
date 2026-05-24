# PRD — Chatbot martex (atendimento WhatsApp via Chatwoot)

> Fonte da spec funcional: `/Users/dionizioaf/Downloads/martex_chatbot_v3.docx` (v3.0 — Maio 2026, AMMO VAREJO S.A.)

## 1. Visão & objetivo de negócio

Oferecer um chatbot de primeira linha que atende clientes martex pelo WhatsApp (entrada via Chatwoot), resolvendo automaticamente os fluxos de menor complexidade (acompanhamento de pedido, info de produto, prazos) e direcionando os casos sensíveis (defeitos, reclamações, fora-de-prazo) para atendimento humano qualificado.

Outcomes esperados:

- Reduzir o tempo de primeira resposta de minutos para segundos.
- Liberar o time humano para casos críticos.
- Padronizar a experiência conversacional (copy oficial martex).
- Manter histórico/protocolo auditável de cada interação.

## 2. Personas

- **Cliente final (B2C)**: comprador da martex, acessa via WhatsApp. Espera resposta rápida, linguagem simpática, resolução em poucos passos.
- **Atendente humano (operador Chatwoot)**: recebe casos escalados, precisa do histórico completo e do protocolo antes de iniciar.
- **Administrador**: ajusta templates, regras de escalada, valida métricas. Pode ser dev ou power-user.

## 3. Métricas de sucesso

- **Auto-resolução** ≥ 60% das conversas que entram pelo bot (não escalam).
- **Tempo de primeira resposta** < 2s no p95.
- **CSAT médio** ≥ 4/5 (medido na Etapa 4).
- **Taxa de escalada por fallback** (3 tentativas sem entender) < 8%.
- **Tempo médio de resolução automática** < 3min.

## 4. Funcionalidades por Etapa

Baseado no documento martex v3.0:

### E1 — Boas-vindas & Triagem

Mensagem inicial padrão + menu numerado 1–6. Disparada quando a conversa não tem `step` definido. Status atual: ✅ implementado no monolito v4.

### E2.1 — Acompanhar Pedido

Pede número de pedido ou CPF. Consulta sistema (hoje mockado) e retorna mensagem por status:

- Em separação → previsão em dias úteis.
- Em trânsito → código de rastreio, transportadora, previsão de entrega.
- Entregue → data + confirmação se está tudo certo.
- Cancelado → forma de reembolso + prazo.

Critérios de escalada: pedido não localizado após 2 tentativas; divergência de status; pedido > 30 dias sem atualização. Status atual: ✅ implementado com mock.

### E2.2 — Troca ou Devolução

Submenu de motivos:

- Arrependimento (até 7 dias da entrega) — validar condições; se OK, gerar protocolo + enviar instruções por e-mail; se fora, escalar.
- Tamanho/cor errado — verificar disponibilidade do item correto em estoque; se OK, abrir protocolo; se não, escalar.
- Produto com defeito → roteia para E2.4.
- Produto diferente do pedido → escalar.

### E2.3 — Prazo de Entrega

Pede pedido/CPF e devolve previsão. Se atrasado (>5 dias sem atualização), registra protocolo e escala.

### E2.4 — Produto com Defeito

Coleta: número do pedido + foto do defeito + foto da nota fiscal. Verifica garantia (90 dias durável / 30 dias não-durável). Apresenta opções: troca pelo mesmo produto OU reembolso integral. **Sempre escala** após o registro — bot apenas registra e confirma.

### E2.5 — Informações sobre Produto

Submenu:

- Como lavar e cuidar (têxteis) → copy fixa.
- Tamanhos disponíveis → encaminha para site.
- Disponibilidade em loja → encaminha para `martex.com.br/lojas`.
- Composição e especificações → encaminha para página do produto.
- Outro → cai em fallback.

### E2.6 — Outro Assunto

Bot pede que cliente descreva; IA tenta classificar nas categorias 2.1–2.5. Se conseguir, encaminha para o sub-fluxo. Se falhar 2 vezes, escala.

### E3 — Escalada para Atendimento Humano

Disparada por 8 critérios:

1. Pedido não localizado após 2 tentativas.
2. Cliente pede atendente explicitamente.
3. Defeito com foto enviada (E2.4).
4. Tom muito negativo / menção a Procon / Reclame Aqui / processo.
5. Atraso > 5 dias úteis sem update.
6. Valor do pedido > R$ 500.
7. > 3 trocas de assunto na mesma sessão.
8. Bot não entende 2x seguidas (fallback nível 2 → 3).

Comportamento varia conforme horário:

- Dentro (seg–sex 9h–18h): conecta com atendente.
- Fora: registra protocolo + lista canais alternativos (0800, e-mail, WhatsApp humano).

### E4 — Encerramento do Atendimento

Mensagem de encerramento + CSAT opcional (1–5 estrelas, não bloqueia o encerramento). Protocolo final exibido. Histórico repassado ao humano se foi escalada.

### E5 — Fallback & Não Entendimento

3 níveis progressivos:

- Nível 1: "não consegui entender" + repete menu.
- Nível 2: "estou com dificuldade" + oferece falar com atendente OU tentar de novo.
- Nível 3 (ou cliente confirma escalada): transfere.

Casos especiais: palavras de crise emocional → escalar imediato; menção a Procon → escalar imediato; outro idioma → mensagem bilíngue.

### E6 — Timeout & Inatividade

- 10 min sem resposta → lembrete ("ainda estou aqui").
- 20 min sem resposta → encerra sessão.
- Retorno < 24h com protocolo aberto → oferece continuar de onde parou.

Regras: nunca disparar timeout se cliente já sinalizou "retomar depois"; pausar (não encerrar) se cliente está enviando fotos.

### E7 — Pós-venda & Fidelização

Disparo automático em D+2 ou D+3 após confirmação de entrega.

- Pergunta inicial com 3 botões: ✅ adorei / 😐 mais ou menos / ❌ tive problema.
- Ramificação A (✅): sugestão de produtos + convite a seguir nas redes.
- Ramificação B (😐): coleta feedback + envia para qualidade.
- Ramificação C (❌): escala imediato (tag: "pós-venda prioritário").

Restrições: 1x por pedido; nunca em fins de semana/feriados; cancelar se já houve reclamação aberta após a entrega.

## 5. Requisitos não-funcionais

- **Idempotência**: retry de webhook não deve duplicar mensagem. Estratégia: alterar `step` antes de enviar mensagem; checar `step` antes de processar.
- **Segurança**: todo webhook do Chatwoot deve passar por validação de header `X-Webhook-Token`.
- **Auditabilidade**: cada transição de `step` registrada no histórico do n8n + (Fase 4) num log centralizado via `util-log-event`.
- **LGPD**: protocolo guardado por 30 dias após encerramento; fotos enviadas pelo cliente armazenadas no Chatwoot conforme política existente.
- **Disponibilidade**: bot disponível 24/7; escalada respeita horário comercial (seg–sex 9h–18h).
- **Internacionalização**: PT-BR como padrão; mensagem bilíngue de fallback se detectar outro idioma.

## 6. Fora de escopo (v1)

- Pagamentos in-chat.
- Criação de pedido novo via bot.
- Integração ERP/OMS real (entra em v1.1 — hoje mockado).
- Voz / áudio / vídeo do cliente.
- Multi-loja em paralelo (por enquanto só martex).

## 7. Dependências externas

| Sistema                | Uso                                                              | Status                                  |
| ---------------------- | ---------------------------------------------------------------- | --------------------------------------- |
| API de pedidos         | E2.1, E2.2, E2.3                                                 | mockada por `MockOrderLookup` Code node |
| API de transportadora  | E2.1 (em trânsito), E2.3 (atraso)                                | mockada                                 |
| API de envio de e-mail | E2.2 (instruções de troca), E2.4 (protocolo)                     | mockada                                 |
| OpenAI (GPT)           | E2.6 (classificação de intenção)                                 | configurada                             |
| Chatwoot API           | enviar/receber mensagens, custom_attributes, labels, assignments | configurada                             |

A substituição dos mocks por APIs reais segue o padrão definido em [`architecture.md`](./architecture.md#mocks) — encapsulados em workflows `mock-*` separados.

## 8. Requisitos Funcionais (RF)

| ID   | Nome                      | Resumo                                                                                                        | Etapa coberta |
| ---- | ------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------- |
| RF01 | Início de atendimento     | Criar `conversation`, gerar protocolo, enviar boas-vindas, registrar canal e timestamp.                       | E1            |
| RF02 | Menu de triagem           | Apresentar 6 opções; aceitar clique OU texto livre (classificar via IA).                                      | E1            |
| RF03 | Identificação de intenção | Detectar intenção por botão + palavras-chave + contexto. Híbrido: regras determinísticas + IA classificadora. | E2.6, E5      |
| RF04 | Acompanhar pedido         | Consultar status por pedido OU CPF. Escalar após 2 falhas / divergência / >30 dias.                           | E2.1          |
| RF05 | Troca/Devolução           | 4 motivos com regras de prazo, estoque e protocolo.                                                           | E2.2          |
| RF06 | Prazo de entrega          | Consulta + escalada se atraso > 5 dias.                                                                       | E2.3          |
| RF07 | Produto com defeito       | Coletar pedido + fotos + nota. Sempre escalar após registro.                                                  | E2.4          |
| RF08 | Info de produto           | Submenu fixo + link site. Nunca inventar composição.                                                          | E2.5          |
| RF09 | Outro assunto             | IA classifica; falha 2x → escala.                                                                             | E2.6          |
| RF10 | Escalada humana           | 8 critérios automáticos + envio de contexto completo ao atendente.                                            | E3            |
| RF11 | Protocolo único           | Formato `MMT-YYYYMM-NNNNNN`, vinculado à conversa, pesquisável.                                               | E3, E4        |
| RF12 | Histórico de conversa     | Persistência completa (cliente + bot + agente + eventos) + envio ao humano antes da 1ª resposta.              | transversal   |
| RF13 | Fallback                  | 3 níveis progressivos; nunca loop > 3 tentativas.                                                             | E5            |
| RF14 | Timeout                   | 10min lembrete · 20min encerra · retomada < 24h · não interrompe upload.                                      | E6            |
| RF15 | Pós-venda                 | D+2/D+3, 1x por pedido, nunca fim de semana/feriado.                                                          | E7            |

## 9. Requisitos Não Funcionais (RNF)

### RNF01 — Disponibilidade

- MVP: 99,5%
- Produção madura: 99,9%

### RNF02 — Performance (alvos p95)

| Operação                  | Alvo  |
| ------------------------- | ----- |
| Resposta simples do bot   | < 1s  |
| Consulta de pedido        | < 3s  |
| Início de escalada humana | < 5s  |
| Upload de anexo           | < 10s |

### RNF03 — Segurança & LGPD

- HTTPS obrigatório em toda integração.
- `CHATWOOT_API_ACCESS_TOKEN` e `CHATWOOT_WEBHOOK_SECRET` apenas via Secret Manager / env vars.
- Logs **nunca** contêm CPF completo (mascarar para `***.***.***-12`).
- Anexos seguem retenção do Chatwoot; protocolo retido 30 dias após encerramento.
- Auditoria de toda transição de `step` via `util-log-event`.
- Controle de acesso por perfil (ver "Papéis" em `migration-to-b.md`).

### RNF04 — Observabilidade

Todo log/evento deve incluir:

- `conversation_id`
- `protocol` (quando existir)
- `customer_id` (quando identificado)
- `channel` (WhatsApp por padrão)
- `current_state` (= `custom_attributes.step`)
- `intent` (quando detectada)
- `escalation_reason` (quando aplicável)

## 10. Política de IA no MVP

**Princípio**: IA não responde livremente ao cliente. Bot fala em copy controlada (ver [`templates.md`](./templates.md)).

IA é permitida apenas para:

- Classificar intenção (E2.6, E5).
- Resumir conversa para o humano antes de escalar.
- Detectar sentimento (crítico para gatilho de escalada por tom negativo).
- Sugerir tag/label.
- Identificar risco (Procon, Reclame Aqui, ameaça).

IA **não é permitida** no MVP para:

- Compor resposta ao cliente.
- Inventar info de produto, prazo ou política.
- Tomar decisão de escalada sem regra de negócio bater junto.

Em produção futura (post-v1), respostas geradas por IA podem entrar **com base controlada** (RAG sobre catálogo + políticas), revisão de tom, fallback seguro e bloqueio de respostas sensíveis.

## 11. Critérios de Aceite (testáveis)

### Atendimento

- Cliente consegue iniciar conversa em qualquer horário.
- Menu aparece corretamente com as 6 opções.
- Bot reage corretamente ao clique de opção numerada.
- Bot tenta classificar texto livre antes de cair em fallback.
- Bot gera protocolo único por sessão.
- Bot consulta pedido com sucesso para os 5 status do mock.
- Bot escala quando algum dos 8 critérios é atingido.
- Humano recebe histórico completo + protocolo antes de iniciar.

### Fallback

- 1ª falha pede reformulação + repete menu.
- 2ª falha oferece humano OU "tentar de novo".
- 3ª falha escala sem perguntar.
- Não existe loop infinito (máximo 3 tentativas).

### Timeout

- 10min envia lembrete.
- 20min encerra a sessão.
- Retorno < 24h permite retomada.
- Upload de foto pausa o timer (não encerra durante upload).

### Pós-venda

- Disparo ocorre em D+2 ou D+3.
- Não dispara em fim de semana / feriado.
- Não dispara se já houve reclamação aberta após a entrega.
- Cliente que reporta "❌ tive um problema" é escalado com tag `pos_venda_prioritario`.

## 12. Métricas — versão expandida

### Operacionais

- Tempo médio de primeira resposta (p95 < 2s).
- Tempo médio até atendente humano (em escaladas, p95 < 5s).
- SLA de resposta cumprido (%).
- Volume de atendimentos por hora/dia/mês.

### Experiência

- CSAT médio (≥ 4/5).
- Taxa de auto-resolução (≥ 60%).
- Taxa de fallback (% conversas que caíram em E5).
- Taxa de abandono (cliente parou de responder antes do fim).

### Negócio

- Redução do volume operacional do SAC humano (alvo ≥ 40%).
- Reclamações críticas evitadas (Procon/Reclame Aqui detectadas e escaladas rápido).
- Conversão de pós-venda (cliques em sugestões de produto).

## 13. Priorização MoSCoW

### Must have (v1)

- Triagem (E1) ✅
- Acompanhar pedido (E2.1) ✅
- Escalada humana (E3)
- Histórico (Chatwoot nativo + `util-log-event`)
- Protocolo (`util-gen-protocol`)
- Fallback (E5)
- Timeout (E6)
- Consulta pedido (via `mock-order-lookup` → futuramente API real)
- LGPD básica (mascaramento + retenção)

### Should have (v1.1)

- Pós-venda (E7)
- Dashboard de métricas
- CSAT (E4)
- Classificação de intenção mais robusta (E2.6, E5)
- API real de pedidos (substituir mock)

### Could have (v2)

- Recomendação de produto pós-venda
- IA para resumo automático ao atendente
- Análise de sentimento
- Campanhas direcionadas

### Won't have (agora)

- Voicebot
- IA generativa para respostas livres
- Multilíngue completo
- CRM avançado próprio
- Marketplace integrations
- Analytics preditivo
