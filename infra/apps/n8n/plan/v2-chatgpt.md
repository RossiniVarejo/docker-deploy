# PRD — Plataforma de Atendimento Conversacional martex

**Versão:** 1.0
**Data:** Maio/2026
**Cliente:** AMMO VAREJO S.A. — martex
**Objetivo:** Implementação da plataforma conversacional omnichannel com automação inteligente, integração operacional e escalada humana.

---

# 1. Visão Geral

A martex deseja implementar uma plataforma de atendimento automatizado capaz de:

- Reduzir o volume operacional do SAC;
- Melhorar a experiência do cliente;
- Diminuir tempo de resposta;
- Padronizar atendimento;
- Automatizar processos repetitivos;
- Escalar automaticamente casos críticos;
- Integrar ERP, e-commerce, logística e canais de atendimento;
- Garantir contexto completo para atendimento humano.

O fluxo funcional já foi mapeado no documento v3 do chatbot.

---

# 2. Problema Atual

O modelo tradicional de SAC possui:

- Alto custo operacional;
- Repetição de chamados;
- Falta de contexto entre canais;
- Escalada manual;
- Falta de rastreabilidade;
- Atendimento inconsistente;
- Dependência excessiva de humano;
- Dificuldade de mensuração de CX.

Além disso, o fluxo definido exige:

- timeout inteligente;
- fallback controlado;
- controle de estado;
- retomada de sessão;
- envio de anexos;
- escalada com contexto;
- pós-venda automatizado;
- rastreamento de protocolo.

---

# 3. Objetivo do Produto

Construir uma plataforma conversacional moderna, escalável e orientada à experiência do cliente.

---

# 4. Decisão Arquitetural Recomendada

## Arquitetura recomendada

### Aplicação própria

Responsável por:

- estado da conversa;
- histórico;
- protocolo;
- regras de negócio;
- fallback;
- timeout;
- contexto;
- escalada;
- experiência do cliente.

### n8n

Responsável por:

- integrações;
- webhooks;
- disparos;
- automações;
- jobs agendados;
- sincronizações;
- notificações;
- conectores externos.

---

# 5. Justificativa Técnica

O fluxo não é apenas um chatbot simples.

Ele exige:

| Requisito              | Complexidade |
| ---------------------- | ------------ |
| Estado conversacional  | Alta         |
| Timeout inteligente    | Alta         |
| Escalada contextual    | Alta         |
| Retomada de sessão     | Alta         |
| Pós-venda automatizado | Média        |
| Análise de intenção    | Média        |
| LGPD                   | Alta         |
| Histórico persistente  | Alta         |

Isso torna inadequado centralizar toda lógica apenas em n8n.

---

# 6. Escopo MVP

## Fluxos incluídos

### Atendimento

- Boas-vindas
- Triagem
- Acompanhar pedido
- Prazo de entrega
- Troca/devolução
- Produto com defeito
- Informações sobre produto
- Outro assunto

### Operação

- Escalada humana
- Fallback
- Timeout
- Encerramento
- Protocolo único
- Histórico

### Pós-venda

- D+2/D+3
- Satisfação
- Fidelização
- Escalada prioritária

---

# 7. Fora do Escopo Inicial

- Voicebot
- Atendimento multilíngue completo
- IA generativa aberta
- CRM avançado
- Recomendação inteligente avançada
- Marketplace integrations
- Analytics preditivo

---

# 8. Arquitetura Técnica

## Backend

- Node.js
- Fastify
- TypeScript

## Banco

- PostgreSQL

## Infraestrutura

- Docker
- Cloud Run ou Kubernetes
- Redis opcional
- Pub/Sub opcional

## Integrações

- n8n
- WhatsApp API
- ERP
- Transportadora
- E-mail
- Plataforma humana

---

# 9. Modelo Conversacional

## Estados principais

```text
START
TRIAGEM
AGUARDANDO_DADOS
CONSULTANDO_PEDIDO
AGUARDANDO_FOTO
FALLBACK_1
FALLBACK_2
ESCALADO_HUMANO
TIMEOUT
ENCERRADO
POS_VENDA
```

---

# 10. Regras de Experiência

## Obrigatórias

- Nunca deixar cliente em loop;
- Escalar após 2 falhas;
- Nunca pedir dado já informado;
- Preservar histórico;
- Humanizar linguagem;
- Priorizar tom emocional;
- Escalar Procon/Reclame Aqui imediatamente;
- Não encerrar timeout durante upload de anexos.

---

# 11. Fluxo de Escalada

## Deve escalar automaticamente quando:

- Pedido não localizado;
- Cliente solicita humano;
- Produto com defeito;
- Atraso logístico;
- Tom agressivo;
- Reclame Aqui/Procon;
- Mais de 3 mudanças de assunto;
- Valor elevado;
- Falha recorrente de entendimento.

---

# 12. Histórico Conversacional

## Requisitos

- Persistência completa;
- Auditoria;
- Contexto por sessão;
- Histórico enviado ao humano;
- Protocolo único;
- Retenção configurável;
- LGPD ready.

---

# 13. Estrutura de Banco

## Tabelas

| Tabela              | Objetivo  |
| ------------------- | --------- |
| conversations       | sessão    |
| messages            | histórico |
| protocols           | protocolo |
| conversation_events | mudanças  |
| escalations         | escaladas |
| attachments         | anexos    |
| intents             | intenções |
| timeout_events      | timeout   |
| post_sale_jobs      | pós-venda |

---

# 14. Integrações

## ERP/E-commerce

- Consulta pedido
- Status
- NF
- Troca
- Produto

## Transportadora

- Tracking
- Prazo
- Atualização

## Atendimento Humano

- Ticket
- Histórico
- SLA

## Mensageria

- WhatsApp
- E-mail
- SMS opcional

---

# 15. Segurança & LGPD

## Obrigatório

- Criptografia;
- Mascaramento de CPF;
- Controle de acesso;
- Logs auditáveis;
- Segregação de ambientes;
- Secret Manager;
- Controle de anexos;
- Retenção configurável.

---

# 16. Métricas Obrigatórias

## Operacionais

- Tempo médio resposta
- Tempo até humano
- SLA
- Volume

## Experiência

- CSAT
- Resolução automática
- Taxa de fallback
- Abandono

## Negócio

- Redução operacional
- Reclamações evitadas
- Conversão pós-venda

---

# 17. Roadmap

## Fase 1 — MVP (4–6 semanas)

### Entregas

- Fluxos principais
- Histórico
- Escalada
- Webchat
- Integrações básicas

---

## Fase 2 — Produção (6–10 semanas)

### Entregas

- WhatsApp
- Timeout avançado
- Pós-venda
- Observabilidade
- Dashboards

---

## Fase 3 — Inteligência

### Entregas

- NLP
- Sentimento
- Priorização
- Analytics
- Recomendação

---

# 18. Critérios de Sucesso

| Meta                 | Objetivo |
| -------------------- | -------- |
| Resolução automática | >60%     |
| Redução operacional  | >40%     |
| CSAT                 | >4.5     |
| Histórico preservado | 100%     |
| Escalada contextual  | 100%     |

---

# 19. Recomendação Final

## Recomendação oficial

### NÃO usar:

- n8n como cérebro principal do atendimento.

### USAR:

- Aplicação própria como motor conversacional;
- n8n como camada operacional de integração.

---

# 20. Arquitetura Final Recomendada

```text
Cliente
   ↓
Webchat / WhatsApp
   ↓
API Conversacional
   ↓
Motor de Estado
   ↓
PostgreSQL
   ↓
n8n
 ├─ ERP
 ├─ Transportadora
 ├─ E-mail
 ├─ CRM
 ├─ Atendimento humano
 └─ Pós-venda
```

Continuando o PRD, agora com uma visão mais executável para o time de desenvolvimento sênior.

---

# 21. Requisitos Funcionais Detalhados

## RF01 — Início de atendimento

Quando o cliente iniciar uma conversa no site, app ou WhatsApp, o sistema deve abrir uma nova sessão de atendimento.

### Comportamento esperado

- Criar uma `conversation`;
- Gerar ou associar um `customer_context`;
- Exibir mensagem de boas-vindas;
- Apresentar opções principais como botões;
- Registrar o canal de origem;
- Registrar data/hora de início;
- Criar um identificador único da sessão.

### Canais suportados no MVP

| Canal    | Prioridade |
| -------- | ---------- |
| Webchat  | Alta       |
| WhatsApp | Alta       |
| App      | Futuro     |

---

## RF02 — Menu de triagem

O bot deve apresentar as opções principais:

```text
1. Acompanhar pedido
2. Trocar ou devolver
3. Prazo de entrega
4. Produto com defeito
5. Informações sobre produto
6. Outro assunto
```

O documento orienta que esse menu deve ser apresentado como **botões clicáveis**, não apenas como texto livre.

### Regras

- Se o cliente clicar em uma opção, direcionar para o fluxo correspondente;
- Se o cliente digitar texto livre, tentar identificar intenção;
- Se não identificar, acionar fallback;
- Se o cliente pedir humano, escalar imediatamente.

---

# 22. RF03 — Identificação de intenção

A plataforma deve identificar a intenção do cliente com base em:

- botão selecionado;
- texto digitado;
- palavras-chave;
- contexto anterior da conversa;
- histórico da sessão;
- intenção anterior.

## Intenções iniciais

| Intenção            | Exemplo                       |
| ------------------- | ----------------------------- |
| `track_order`       | “quero acompanhar meu pedido” |
| `exchange_return`   | “quero trocar”                |
| `delivery_deadline` | “qual o prazo?”               |
| `defective_product` | “produto veio com defeito”    |
| `product_info`      | “como lavar?”                 |
| `human_agent`       | “quero falar com atendente”   |
| `unknown`           | mensagem não classificada     |

## Recomendação técnica

No MVP, usar uma abordagem híbrida:

1. **Botões e regras determinísticas**;
2. **Palavras-chave controladas**;
3. **Classificador simples de intenção**;
4. Futuramente, NLP/IA com camada de segurança.

---

# 23. RF04 — Acompanhar pedido

O cliente poderá consultar pedido usando:

- número do pedido;
- CPF cadastrado.

## Fluxo

```text
Cliente escolhe "Acompanhar pedido"
↓
Bot solicita número do pedido ou CPF
↓
Cliente informa dado
↓
Sistema consulta base de pedidos
↓
Bot retorna status
```

## Status esperados

| Status           | Resposta                           |
| ---------------- | ---------------------------------- |
| Em separação     | Informar previsão de envio         |
| Em trânsito      | Informar rastreio e transportadora |
| Entregue         | Confirmar entrega                  |
| Cancelado        | Informar reembolso                 |
| Não localizado   | Tentar novamente                   |
| Erro de consulta | Escalar                            |

## Regras

- Após 2 tentativas sem localizar pedido, escalar;
- Se houver divergência de status, escalar;
- Se pedido estiver há mais de 30 dias sem atualização, escalar;
- Registrar todas as tentativas.

---

# 24. RF05 — Troca ou devolução

O bot deve conduzir o cliente conforme motivo informado:

```text
- Arrependimento
- Tamanho ou cor errado
- Produto com defeito
- Produto diferente do pedido
```

## Arrependimento

### Regras

- Validar prazo de 7 dias corridos após entrega;
- Confirmar produto sem uso;
- Confirmar embalagem original;
- Confirmar nota fiscal;
- Solicitar número do pedido;
- Gerar protocolo;
- Enviar instruções por e-mail.

## Tamanho ou cor errado

### Regras

- Solicitar pedido;
- Solicitar produto/tamanho/cor desejado;
- Consultar estoque;
- Se disponível, abrir protocolo;
- Se indisponível, escalar para humano.

## Produto diferente do pedido

### Regras

- Solicitar pedido;
- Solicitar foto do produto recebido;
- Solicitar nota fiscal;
- Registrar caso;
- Escalar para humano.

---

# 25. RF06 — Prazo de entrega

O cliente poderá consultar prazo de entrega usando:

- número do pedido;
- CPF.

## Regras

- Se pedido localizado, exibir previsão;
- Se houver rastreio, exibir código;
- Se pedido estiver atrasado, gerar protocolo;
- Se atraso for superior a 5 dias úteis sem atualização, escalar;
- Se houver falha da transportadora, escalar;
- Se endereço estiver incorreto ou não localizado, escalar.

---

# 26. RF07 — Produto com defeito

Esse fluxo exige atenção especial.

O bot deve coletar:

- número do pedido;
- foto do defeito;
- foto da nota fiscal;
- descrição opcional do problema.

O documento determina que casos de produto com defeito devem ser sempre escalados após o registro. O bot registra e confirma, mas a resolução deve ser confirmada por atendente.

## Regras

- Criar protocolo prioritário;
- Armazenar anexos;
- Validar formato dos arquivos;
- Registrar data/hora;
- Associar anexos ao protocolo;
- Encaminhar para humano;
- Marcar tag: `produto_com_defeito`.

## Opções apresentadas ao cliente

```text
- Troca pelo mesmo produto
- Reembolso integral
```

Mesmo após a escolha, o caso deve ser validado por humano.

---

# 27. RF08 — Informações sobre produto

O bot deve responder dúvidas simples de produto.

## Categorias

| Categoria               | Ação                |
| ----------------------- | ------------------- |
| Como lavar/cuidar       | Resposta automática |
| Tamanhos disponíveis    | Consultar catálogo  |
| Composição              | Consultar catálogo  |
| Disponibilidade em loja | Direcionar loja     |
| Produto não têxtil      | Direcionar página   |
| Dúvida específica       | Escalar             |

## Regras

- Não inventar composição de produto;
- Não responder informação técnica inexistente;
- Sempre preferir dado vindo do catálogo;
- Se não houver dado confiável, escalar.

---

# 28. RF09 — Outro assunto

Quando o cliente selecionar “Outro assunto”, o bot deve:

1. Solicitar que o cliente explique o que precisa;
2. Tentar identificar a intenção;
3. Redirecionar para fluxo existente, se possível;
4. Acionar fallback se não entender;
5. Escalar após 2 tentativas malsucedidas.

---

# 29. RF10 — Escalada humana

A plataforma deve permitir transferência para humano com todo o contexto.

## Critérios automáticos de escalada

- Cliente pede atendente;
- Pedido não localizado após 2 tentativas;
- Produto com defeito;
- Reclamação com tom negativo;
- Menção a Procon;
- Menção a Reclame Aqui;
- Menção a processo judicial;
- Atraso superior a 5 dias úteis;
- Valor do pedido acima de R$ 500;
- Mais de 3 trocas de assunto;
- Fallback recorrente.

Esses critérios já estão previstos no fluxo funcional do chatbot.

## Requisitos

Antes de transferir, o sistema deve enviar ao atendente:

- dados do cliente;
- canal;
- protocolo;
- resumo da conversa;
- mensagens completas;
- intenção detectada;
- dados coletados;
- anexos;
- motivo da escalada;
- prioridade.

---

# 30. RF11 — Protocolo único

Cada sessão deve possuir um protocolo único.

## Regras

- Nunca reaproveitar protocolo;
- Protocolo deve estar vinculado à conversa;
- Protocolo deve estar visível ao cliente;
- Protocolo deve ser enviado ao atendimento humano;
- Protocolo deve ser pesquisável no backoffice.

## Sugestão de formato

```text
MMT-202605-000001
```

Estrutura:

```text
MMT = marca
202605 = ano/mês
000001 = sequência
```

---

# 31. RF12 — Histórico de conversa

O histórico completo deve ser salvo.

## O que armazenar

- mensagens do cliente;
- mensagens do bot;
- mensagens do atendente;
- data/hora;
- canal;
- anexos;
- estado da conversa;
- eventos de sistema;
- tentativas de fallback;
- alterações de intenção;
- transferências.

## Importante

O histórico precisa ser enviado ao humano **antes da primeira resposta do atendente**, conforme regra do documento.

---

# 32. RF13 — Fallback

O bot deve controlar falhas de entendimento.

## Fallback 1

Cliente recebe nova tentativa com menu.

## Fallback 2

Bot informa dificuldade e oferece humano.

## Fallback 3

Escala automaticamente.

## Regras

- Não ultrapassar 3 tentativas;
- Registrar cada tentativa;
- Não repetir a mesma mensagem indefinidamente;
- Se detectar crise emocional, escalar imediatamente;
- Se detectar Procon/Reclame Aqui/processo, escalar imediatamente.

---

# 33. RF14 — Timeout

A plataforma deve controlar inatividade.

## Regras

| Tempo sem resposta                | Ação                |
| --------------------------------- | ------------------- |
| 10 minutos                        | Enviar lembrete     |
| 20 minutos                        | Encerrar sessão     |
| Menos de 24h após encerramento    | Oferecer retomada   |
| Cliente enviando fotos            | Não encerrar        |
| Cliente pediu para retomar depois | Não enviar lembrete |

O fluxo de timeout e retomada em menos de 24h está descrito no documento original.

---

# 34. RF15 — Pós-venda

O sistema deve disparar mensagem de pós-venda entre 48h e 72h após confirmação de entrega.

## Regras

- Nunca disparar em finais de semana ou feriados;
- Disparar no máximo 1 vez por pedido;
- Cancelar se já houver reclamação aberta;
- Cancelar se houver troca/devolução em andamento;
- Escalar se cliente relatar problema;
- Tag para casos negativos: `pos_venda_prioritario`.

---

# 35. Requisitos Não Funcionais

## RNF01 — Disponibilidade

Meta recomendada:

```text
99,5% no MVP
99,9% em produção madura
```

## RNF02 — Performance

| Operação                | Tempo alvo |
| ----------------------- | ---------- |
| Resposta simples do bot | < 1s       |
| Consulta de pedido      | < 3s       |
| Escalada humana         | < 5s       |
| Upload de anexo         | < 10s      |

## RNF03 — Segurança

- HTTPS obrigatório;
- Autenticação entre serviços;
- Secrets fora do código;
- Logs sem CPF completo;
- Controle de acesso por perfil;
- Auditoria de ações;
- Retenção de anexos configurável.

## RNF04 — Observabilidade

Todo atendimento deve ter:

- `conversation_id`;
- `protocol_id`;
- `customer_id`, quando identificado;
- `channel`;
- `trace_id`;
- `current_state`;
- `intent`;
- `escalation_reason`.

---

# 36. APIs Internas Sugeridas

## Criar conversa

```http
POST /conversations
```

## Enviar mensagem

```http
POST /conversations/{id}/messages
```

## Consultar estado

```http
GET /conversations/{id}
```

## Escalar para humano

```http
POST /conversations/{id}/escalate
```

## Registrar anexo

```http
POST /conversations/{id}/attachments
```

## Gerar protocolo

```http
POST /protocols
```

## Disparar evento para n8n

```http
POST /automation/events
```

---

# 37. Eventos para n8n

A aplicação deve disparar eventos para o n8n, e não depender do n8n para controlar toda a conversa.

## Eventos sugeridos

```text
conversation.started
order.lookup.requested
order.lookup.failed
order.delayed
exchange.requested
defect.reported
human.escalation.requested
conversation.closed
post_sale.scheduled
post_sale.customer_unsatisfied
```

---

# 38. Responsabilidades por Camada

| Camada             | Responsabilidade                       |
| ------------------ | -------------------------------------- |
| Aplicação própria  | Experiência, estado, histórico, regras |
| n8n                | Integrações, disparos, automações      |
| Banco              | Persistência e auditoria               |
| Canal              | Entrega de mensagens                   |
| Atendimento humano | Resolução complexa                     |
| Observabilidade    | Monitoramento                          |

---

# 39. Backoffice mínimo

O MVP deve ter uma tela administrativa simples.

## Funcionalidades

- Buscar protocolo;
- Ver conversa;
- Ver cliente;
- Ver status;
- Ver anexos;
- Ver motivo de escalada;
- Ver logs;
- Reenviar para atendimento humano;
- Encerrar conversa;
- Adicionar tag.

---

# 40. Painel de indicadores

## Indicadores mínimos

| Indicador              | Descrição             |
| ---------------------- | --------------------- |
| Atendimentos iniciados | volume total          |
| Resolvidos pelo bot    | automação efetiva     |
| Escalados              | carga humana          |
| Fallback               | falha de entendimento |
| Abandono               | cliente saiu          |
| Tempo médio            | eficiência            |
| CSAT                   | satisfação            |
| Reclamações críticas   | risco reputacional    |

---

# 41. Papéis e Permissões

## Perfis

| Perfil         | Acesso                         |
| -------------- | ------------------------------ |
| Admin          | Tudo                           |
| Supervisor SAC | Conversas, métricas, escaladas |
| Atendente      | Conversas atribuídas           |
| CX/Qualidade   | Relatórios e tags              |
| TI/Dev         | Logs técnicos                  |
| Auditor        | Leitura                        |

---

# 42. Critérios de Aceite

## Atendimento

- Cliente consegue iniciar conversa;
- Menu aparece corretamente;
- Bot entende clique;
- Bot tenta classificar texto livre;
- Bot gera protocolo;
- Bot consulta pedido;
- Bot escala quando necessário;
- Humano recebe histórico completo.

## Fallback

- Primeira falha pede reformulação;
- Segunda oferece humano;
- Terceira escala;
- Não existe loop infinito.

## Timeout

- 10 minutos envia lembrete;
- 20 minutos encerra;
- Retorno em menos de 24h permite retomada;
- Upload de foto pausa timeout.

## Pós-venda

- Disparo ocorre D+2/D+3;
- Não dispara em final de semana/feriado;
- Não dispara se houver chamado aberto;
- Cliente insatisfeito é escalado.

---

# 43. Riscos do Projeto

| Risco                        | Impacto | Mitigação                      |
| ---------------------------- | ------- | ------------------------------ |
| n8n virar motor principal    | Alto    | Definir fronteira arquitetural |
| Integração ERP instável      | Alto    | Retry, fila e fallback         |
| Bot gerar frustração         | Alto    | Escalada rápida                |
| LGPD mal tratada             | Alto    | Mascaramento e retenção        |
| Histórico perdido            | Alto    | Persistência obrigatória       |
| Fluxo visual complexo demais | Médio   | Estado em aplicação            |
| IA responder errado          | Médio   | IA limitada no MVP             |

---

# 44. Decisão sobre IA

## MVP

Não usar IA generativa para responder livremente ao cliente.

Usar IA apenas para:

- classificar intenção;
- resumir conversa para humano;
- detectar sentimento;
- sugerir tag;
- identificar risco.

## Produção futura

Após validação, IA pode ajudar em respostas, mas com:

- base controlada;
- revisão de tom;
- fallback seguro;
- bloqueio de respostas sensíveis;
- logs e auditoria.

---

# 45. Definição de Pronto

Uma funcionalidade só deve ser considerada pronta quando:

- possui teste;
- possui log;
- possui métrica;
- possui fallback;
- possui comportamento de erro;
- salva histórico;
- respeita LGPD;
- foi validada por CX;
- foi validada por SAC;
- foi validada tecnicamente.

---

# 46. Recomendação de Stack

## Backend

```text
Node.js + Fastify + TypeScript
```

Motivos:

- performance;
- baixo overhead;
- boa estrutura para APIs;
- facilidade de integração;
- validação por schema;
- OpenAPI.

## Banco

```text
PostgreSQL
```

Motivos:

- histórico relacional;
- auditoria;
- integridade;
- busca por protocolo;
- suporte a JSONB.

## Automação

```text
n8n
```

Uso:

- ERP;
- e-mail;
- WhatsApp;
- transportadora;
- pós-venda;
- jobs agendados.

---

# 47. Estrutura de Repositório Sugerida

```text
chatbot-platform/
  apps/
    api/
    admin/
    widget/
  packages/
    domain/
    database/
    integrations/
    shared/
  infra/
    docker/
    terraform/
  docs/
    prd/
    architecture/
    runbooks/
```

---

# 48. Entregáveis do Projeto

## Produto

- API conversacional;
- Webchat;
- Integração WhatsApp;
- Backoffice;
- Motor de estado;
- Histórico;
- Protocolo;
- Escalada;
- Pós-venda.

## Técnico

- Banco PostgreSQL;
- Workflows n8n;
- Logs;
- Dashboards;
- Documentação;
- Testes;
- Deploy.

## Operacional

- Manual SAC;
- Manual supervisor;
- Playbook de escalada;
- Matriz de tags;
- Indicadores.

---

# 49. Priorização MoSCoW

## Must have

- Triagem;
- Acompanhar pedido;
- Escalada humana;
- Histórico;
- Protocolo;
- Fallback;
- Timeout;
- Consulta pedido;
- LGPD básica.

## Should have

- Pós-venda;
- Dashboard;
- CSAT;
- WhatsApp;
- Classificação de intenção.

## Could have

- Recomendação de produto;
- IA para resumo;
- Sentimento;
- Campanhas.

## Won’t have agora

- Voicebot;
- IA livre;
- Multilíngue completo;
- CRM avançado.

---

# 50. Conclusão Executiva

A recomendação é tratar o chatbot como **produto de experiência do cliente**, não apenas como automação.

O caminho mais seguro é:

```text
Aplicação própria = cérebro da experiência
n8n = braço operacional das integrações
PostgreSQL = memória e auditoria
Atendimento humano = resolução complexa
```

Essa abordagem reduz risco operacional, melhora rastreabilidade, aumenta qualidade de atendimento e prepara a martex para escalar o SAC com controle e boa experiência.
