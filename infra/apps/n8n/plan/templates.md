# Templates — Copies oficiais martex

Fonte: `martex_chatbot_v3.docx` (v3.0, Maio 2026). Cada bloco tem um **nome estável** (`<etapa>.<key>`) usado em `architecture.md` e nos workflows.

> **Regra**: toda nova copy começa neste arquivo. Workflow só recebe copy depois de aprovada aqui.

## Placeholders

Padrão `{nome}` (chaves simples). Lista canônica:

- `{order_number}`, `{tracking_code}`, `{carrier}`, `{delivery_date}`
- `{refund_method}`, `{refund_days}`, `{days_to_ship}`
- `{protocol}`, `{nome}`, `{tema}`, `{data}`, `{prazo}`
- `{produto}`, `{tamanho}`, `{preço}`, `{forma_pagamento}`

## E1 — Boas-vindas

### `welcome.menu`

```
Olá! Seja bem-vindo(a) à Central de Experiência do Cliente da martex. Sou a assistente virtual e estou aqui para te ajudar.

O que você precisa hoje?
1️⃣ Acompanhar pedido
2️⃣ Trocar ou devolver
3️⃣ Prazo de entrega
4️⃣ Produto com defeito
5️⃣ Informações sobre produto
6️⃣ Outro assunto
```

## E2.1 — Acompanhar Pedido

### `track-order.ask-id`

```
Para consultar seu pedido, preciso de algumas informações. Por favor, informe o número do pedido (você o encontra no e-mail de confirmação) ou o CPF cadastrado.
```

### `track-order.ask-id-retry`

```
Não localizei o pedido. Pode conferir o número do pedido ou seu CPF e enviar novamente?
```

### `track-order.status.separacao`

```
Seu pedido [#{order_number}] está em separação no nosso centro de distribuição. A previsão de envio é em até {days_to_ship} dias úteis. Assim que o rastreio for gerado, você receberá por e-mail.
```

### `track-order.status.transito`

```
Seu pedido já foi despachado! Código de rastreio: {tracking_code} — você pode acompanhar em {carrier}. Previsão de entrega: {delivery_date}.
```

### `track-order.status.entregue`

```
Nosso sistema indica que o pedido foi entregue em {delivery_date}. Tudo certo com a entrega? Se tiver qualquer problema, posso te ajudar.
```

### `track-order.status.cancelado`

```
Identificamos que esse pedido foi cancelado. O reembolso foi processado para {refund_method} em até {refund_days} dias. Tem mais alguma dúvida?
```

### `track-order.escalate.not-found`

```
Não consegui localizar esse pedido com as informações fornecidas. Vou te conectar com um atendente humano que vai resolver isso agora. Aguarde um momento!
```

## E2.2 — Troca ou Devolução

### `trade-return.menu`

```
Entendido! Para iniciar uma troca ou devolução, me conta: qual é o motivo?

🔸 Arrependimento (prazo de 7 dias)
🔸 Tamanho ou cor errado
🔸 Produto com defeito
🔸 Produto diferente do pedido
```

### `trade-return.regret.conditions`

```
Você tem direito à devolução por arrependimento em até 7 dias corridos após a entrega, sem custo.

Para isso, preciso confirmar que:
✅ O produto está sem uso e com a embalagem original
✅ Você tem a nota fiscal

Tudo certo? Então me informe o número do pedido para eu abrir o protocolo.
```

### `trade-return.regret.expired`

```
Infelizmente o prazo de 7 dias para arrependimento já passou. Mas vou te conectar com um atendente para verificar o que podemos fazer pelo seu caso.
```

### `trade-return.wrong-size.ask`

```
Vamos resolver isso. Me informe o número do pedido e qual seria o produto correto (tamanho/cor desejado).
```

### `trade-return.wrong-size.available`

```
Ótima notícia! O produto no tamanho/cor desejado está disponível. Vou abrir o protocolo de troca. Você receberá as instruções de devolução por e-mail e o novo produto será enviado assim que recebermos o item. Protocolo: {protocol}.
```

### `trade-return.wrong-size.unavailable`

```
Infelizmente o produto que você precisa está esgotado no momento. Vou te conectar com um atendente para verificar alternativas ou providenciar o reembolso.
```

## E2.3 — Prazo de Entrega

### `delivery-time.intro`

```
Os prazos de entrega variam de acordo com a região, a transportadora e a disponibilidade do produto no estoque mais próximo de você.

Se você já realizou um pedido e quer saber o prazo de entrega, me informe o número do pedido ou o CPF cadastrado que consulto para você.
```

### `delivery-time.result`

```
Seu pedido [#{order_number}] tem previsão de entrega para {delivery_date}. Você pode acompanhar pelo código de rastreio: {tracking_code}.

Tem mais alguma dúvida?
```

### `delivery-time.delayed`

```
Identifiquei que seu pedido [#{order_number}] está com prazo excedido. Já registrei sua solicitação e um atendente entrará em contato em até 24h. Protocolo: {protocol}.
```

## E2.4 — Produto com Defeito

### `defect.ask-info`

```
Pedimos desculpas. Vamos resolver isso com prioridade.

Para registrar a reclamação, preciso de:
📋 Número do pedido
📷 Foto do defeito (pode enviar aqui no chat)
📄 Foto da nota fiscal

Pode me enviar essas informações?
```

### `defect.in-warranty`

```
Obrigada pelas informações! Seu caso foi registrado com prioridade (Protocolo: {protocol}).

Temos duas opções para você:
🔄 Troca pelo mesmo produto
💰 Reembolso integral

Qual prefere?
```

### `defect.after-choice`

```
Perfeito! Vou encaminhar isso para um especialista confirmar os próximos passos. Você receberá contato em até 24h úteis. Qualquer dúvida, pode usar o protocolo {protocol}.
```

## E2.5 — Informações sobre Produto

### `product-info.menu`

```
Posso te ajudar com informações sobre nossos produtos! O que você quer saber?

🔸 Como lavar e cuidar (têxteis)
🔸 Tamanhos disponíveis
🔸 Disponibilidade em loja
🔸 Composição e especificações técnicas
🔸 Outro
```

### `product-info.washing`

```
Para conservar melhor, recomendamos:

🌡️ Lavar em água fria ou morna (máx. 40°C)
🚫 Não usar alvejante com cloro
💨 Secar à sombra
🔥 Passar com ferro na temperatura indicada na etiqueta

Mais alguma dúvida?
```

### `product-info.specs`

```
As informações completas de composição e especificações estão na descrição de cada produto no site.

Quer que eu te envie o link direto para o produto que você tem interesse?
```

### `product-info.non-textile`

```
Para informações específicas sobre esse produto — como modo de uso, ingredientes ou especificações técnicas — você encontra todos os detalhes na página do produto em martex.com.br.

Posso te ajudar a encontrar algo mais?
```

### `product-info.in-store`

```
Para verificar estoque nas lojas físicas, recomendo entrar em contato com a loja da sua preferência. Encontre a loja em: martex.com.br/lojas
```

## E2.6 — Outro Assunto

### `other.ask`

```
Claro! Me conta o que você precisa e vou fazer o possível para ajudar.
```

### `other.classified`

```
Entendi! Parece que você quer ajuda com {tema}. Deixa eu te ajudar com isso.
```

### `other.unclear`

```
Entendi que você precisa de ajuda, mas não tenho certeza se consigo resolver isso por aqui. Vou te transferir para um dos nossos atendentes. Aguarde um momento!
```

## E3 — Escalada

### `escalate.in-hours`

```
Vou te conectar agora com um dos nossos especialistas para resolver isso com mais agilidade.

Seu protocolo é {protocol} — o atendente já vai ter acesso ao histórico da nossa conversa. Aguarde um momento!
```

### `escalate.out-of-hours`

```
Nosso atendimento humano funciona de segunda a sexta, das 9h às 18h. No momento estamos fora desse horário.

Registrei seu caso (Protocolo: {protocol}) e um atendente vai entrar em contato no próximo dia útil. Se preferir, você também pode nos acionar pelo:

📞 0800 722 2977
📧 atendimento@martex.com.br
💬 WhatsApp: (11) 99999-9999
```

## E4 — Encerramento

### `close.resolved`

```
Fico feliz em ter conseguido ajudar! 😊 Se tiver mais alguma dúvida, é só falar.

Como você avaliaria nosso atendimento hoje? (1 a 5 estrelas)
```

### `close.transferred`

```
Pronto! Você está conectado(a) com nosso time. Protocolo {protocol} — o histórico desta conversa já foi repassado.

Obrigada por entrar em contato com a martex!
```

## E5 — Fallback

### `fallback.level-1`

```
Hmm, não consegui entender bem o que você precisa. Pode me contar de outra forma? Ou, se preferir, escolha uma das opções abaixo:

1️⃣ Acompanhar pedido
2️⃣ Trocar ou devolver
3️⃣ Prazo de entrega
4️⃣ Produto com defeito
5️⃣ Informações sobre produto
6️⃣ Falar com atendente
```

### `fallback.level-2`

```
Parece que estou com dificuldade para entender sua solicitação. Não quero te fazer perder tempo!

Vou te conectar com um atendente humano que vai resolver isso melhor. Pode ser?

✅ Sim, quero falar com atendente
🔄 Tentar de novo
```

### `fallback.level-3`

```
Tudo bem! Vou te transferir agora. Protocolo {protocol} gerado — o atendente já vai ter o contexto da nossa conversa. Um momento!
```

### `fallback.other-language`

```
Atendimento disponível em português. / Service available in English — please call +55 (11) 99999-9999.
```

## E6 — Timeout

### `timeout.10min`

```
Oi! Ainda estou por aqui. 😊 Você quer continuar o atendimento ou prefere retomar depois?

✅ Quero continuar
🔄 Retomar depois
```

### `timeout.20min`

```
Vou encerrar esta sessão por inatividade. Se precisar de ajuda, é só iniciar uma nova conversa — teremos prazer em atender você!

Caso tenha ficado alguma dúvida, você pode nos acionar pelo 0800 722 2977 ou pelo e-mail atendimento@martex.com.br.
```

### `timeout.return-within-24h`

```
Olá, {nome}! Que bom ter você de volta. 😊 Vi que você tinha uma dúvida sobre {tema}. Quer continuar de onde paramos ou é um assunto novo?

🔄 Continuar o assunto anterior
🆕 Começar novo atendimento
```

## E7 — Pós-venda

### `postsale.initial`

```
Olá, {nome}! 😊 Seu pedido foi entregue há poucos dias — tudo certo com os produtos?

Queremos garantir que sua experiência com a martex foi a melhor possível.

✅ Sim, adorei!
😐 Mais ou menos
❌ Tive um problema
```

### `postsale.positive`

```
Que ótimo! Fico muito feliz em saber disso. 🥰

Ah, e se quiser, já temos novidades que combinam com o que você comprou. Quer dar uma olhada?
```

### `postsale.positive.suggest`

```
Aqui vão algumas peças que costumam combinar com {produto}:

🛏️ {sugestao_1} — R$ {preco_1}
🛏️ {sugestao_2} — R$ {preco_2}

Acesse: {link_categoria}
```

### `postsale.positive.loyalty`

```
Como cliente martex, você tem acesso antecipado às nossas promoções. Que tal receber nossas novidades em primeira mão?

📱 Siga @martex.oficial
📧 Confirme seu e-mail para receber ofertas exclusivas
```

### `postsale.neutral.ask`

```
Entendo. Me conta o que não foi tão legal assim? Seu feedback é muito importante pra gente melhorar.
```

### `postsale.neutral.thanks`

```
Obrigada por compartilhar isso com a gente. Esse tipo de feedback é o que nos ajuda a melhorar.

Vou encaminhar para o time responsável. Se quiser resolver algo específico, posso te ajudar agora ou conectar com um atendente. Como prefere?
```

### `postsale.negative`

```
Puxa, sinto muito por isso! Definitivamente não é a experiência que queremos oferecer.

Vou te conectar com um atendente especializado para resolver isso agora com prioridade. Pode ser?
```

## Como aplicar no n8n

Em cada nó `HTTP Request` que envia mensagem, o `jsonBody` segue o padrão:

```
={
  "content": {{ JSON.stringify(`<COPY AQUI COM ${interpolações}>`) }},
  "message_type": "outgoing",
  "private": false,
  "content_type": "text"
}
```

A copy fica embutida no nó (não há carregamento dinâmico deste arquivo em runtime). Mas qualquer alteração começa aqui e propaga para os nós correspondentes via PR. Code review valida que o texto no nó bate com o template.

## Preparação para Opção B

Este arquivo vira `templates/pt-BR.yaml` no serviço backend, carregado uma vez na inicialização e referenciado por chave (`welcome.menu`, `track-order.ask-id`, etc.). Workflows n8n viram chamadas `service.send(conversationId, "welcome.menu", { ... })`.
