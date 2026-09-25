# Guia de construção — Dashboard PASA no Power BI

Três arquivos formam o modelo, todos em `data/processed/` (fonte única de
verdade do projeto — não existe cópia duplicada em formato brasileiro):
`fato_financeiro.csv` · `dim_operadora.csv` · `dim_trimestre.csv`

---

## Parte 1 — Importar e modelar

### 1.1 Importar
`Página Inicial > Obter Dados > Texto/CSV` — importe os três arquivos de
`data/processed/`.

Esses CSVs usam o formato padrão (vírgula separando colunas, **ponto** como
separador decimal). Se o Power BI estiver com o locale do sistema em
**Português (Brasil)**, o Power Query pode interpretar o ponto decimal como
separador de milhar e inflar os valores (ex.: transformar R$ 1,3 milhão em
R$ 130 bilhões, ou mostrar números sem decimais nenhum). Para evitar isso:

1. Na coluna de valor (ex.: `receita_assistencial`), clique com o **botão
   direito** no cabeçalho → **Alterar Tipo → Usando Local...**
2. Em **Tipo de Dados**, escolha **Número Decimal Fixo** (evita notação
   científica em valores grandes — ver Parte 1.3 abaixo)
3. Em **Local**, escolha **Inglês (Estados Unidos)** — isso diz ao Power
   Query explicitamente que o separador decimal do arquivo é ponto,
   independente do locale do sistema
4. Repita para todas as colunas numéricas de valor monetário

Isso resolve o problema na importação, sem precisar manter uma cópia do
arquivo em outro formato.

### 1.2 Confira os tipos após importar
- `REG_ANS` deve estar como **Número Inteiro**
- Se algum valor aparecer como texto, clique no ícone do tipo no cabeçalho e corrija

### 1.3 Criar os relacionamentos
Vá em **Exibição de Modelo** (ícone à esquerda) e arraste para criar:

| De | Para | Cardinalidade |
|---|---|---|
| `fato_financeiro[REG_ANS]` | `dim_operadora[REG_ANS]` | Muitos para um (*:1) |
| `fato_financeiro[trimestre]` | `dim_trimestre[trimestre]` | Muitos para um (*:1) |

> **Por que isso importa:** esse é o "modelo estrela". A tabela fato tem os números, as dimensões têm os rótulos. Sem relacionamento, seus filtros de operadora não afetam os gráficos.

### 1.4 Ordenar os trimestres corretamente
Sem isso, o Power BI ordena alfabeticamente e "1T2026" aparece antes de "2T2025".

1. Selecione a tabela `dim_trimestre`, clique na coluna `trimestre`
2. Aba **Ferramentas de Coluna > Classificar por Coluna > `ordem`**

---

## Parte 2 — As medidas DAX

Crie uma tabela dedicada para organizar: `Página Inicial > Inserir Dados`, nomeie
`_Medidas`, salve vazia. Crie cada medida com **Nova Medida**.

### Entendendo DAX rapidamente

DAX parece Excel, mas funciona diferente num ponto crucial: **uma medida é
recalculada dentro do contexto de cada visual**. Se você põe `[Sinistralidade]` num
gráfico por trimestre, ela recalcula para cada trimestre automaticamente — você não
escreve loop nenhum.

`SUM()` soma a coluna inteira *dentro do filtro atual*. `DIVIDE()` é a divisão segura
(retorna vazio em vez de erro quando o denominador é zero) — sempre prefira ela a `/`.

---

### 2.1 Medidas base (os blocos de construção)

```dax
Receita Assistencial = SUM(fato_financeiro[receita_assistencial])
```

```dax
Sinistro = SUM(fato_financeiro[sinistro_liquido])
```

```dax
Receitas Totais = SUM(fato_financeiro[receitas_totais])
```

```dax
Despesas Totais = SUM(fato_financeiro[despesas_totais])
```

```dax
Faturado Bruto = SUM(fato_financeiro[faturado_bruto])
```

```dax
Glosa = SUM(fato_financeiro[glosa])
```

```dax
Outras Receitas Operacionais = SUM(fato_financeiro[outras_receitas_operacionais])
```

```dax
Outras Despesas Operacionais = SUM(fato_financeiro[outras_despesas_operacionais])
```

```dax
Despesa Administrativa = SUM(fato_financeiro[despesa_administrativa])
```

```dax
Residuo Receita = [Receitas Totais] - [Receita Assistencial] - [Outras Receitas Operacionais]
```

```dax
Residuo Despesa = [Despesas Totais] - [Sinistro] - [Despesa Administrativa] - [Outras Despesas Operacionais]
```

> Os dois "Residuo" cobrem itens menores não detalhados (receitas financeiras
> e patrimoniais, despesas financeiras) — existem para que o gráfico de
> composição (Parte 3, Página 2) feche exatamente com `Receitas Totais` e
> `Despesas Totais`, em vez de sugerir uma soma que não bate.

---

### 2.2 Os KPIs principais

**Sinistralidade** — o indicador clássico do setor:
```dax
Sinistralidade =
DIVIDE( [Sinistro], [Receita Assistencial] )
```
> Formate como **Porcentagem** (aba Ferramentas de Medida).

**Resultado Operacional** — a métrica que corrigiu nosso diagnóstico:
```dax
Resultado Operacional = [Receitas Totais] - [Despesas Totais]
```

**Margem Operacional** — o resultado em termos relativos:
```dax
Margem Operacional =
DIVIDE( [Resultado Operacional], [Receitas Totais] )
```

**Taxa de Glosa** — KPI de auditoria de contas médicas:
```dax
Taxa de Glosa =
DIVIDE( [Glosa], [Faturado Bruto] )
```

---

### 2.3 Medidas de benchmark (as mais interessantes)

Aqui entra o conceito mais importante do DAX: **`CALCULATE` muda o contexto de
filtro**. É o que permite comparar "a operadora selecionada" contra "o grupo todo"
no mesmo visual.

**Mediana do setor** — ignora o filtro de operadora e calcula a mediana de todas:
```dax
Sinistralidade Mediana Setor =
MEDIANX(
    CALCULATETABLE(
        VALUES( dim_operadora[REG_ANS] ),
        REMOVEFILTERS( dim_operadora ),
        fato_financeiro[dado_confiavel] = TRUE
    ),
    CALCULATE( [Sinistralidade] )
)
```
> **O que está acontecendo:** `REMOVEFILTERS(dim_operadora)` diz "esqueça qual
> operadora está selecionada". `MEDIANX` percorre cada operadora e calcula a
> sinistralidade dela, depois tira a mediana de todas. O filtro de *trimestre*
> continua valendo — então isso te dá a mediana do setor naquele trimestre.

**Mediana do peer group** (só fundações de previdência):
```dax
Sinistralidade Mediana Fundações =
MEDIANX(
    CALCULATETABLE(
        VALUES( dim_operadora[REG_ANS] ),
        REMOVEFILTERS( dim_operadora ),
        dim_operadora[grupo_comparacao] = "Fundação de previdência",
        fato_financeiro[dado_confiavel] = TRUE
    ),
    CALCULATE( [Sinistralidade] )
)
```

**Diferença da PASA para o peer group** — o número que conta a história:
```dax
Gap vs Fundações =
[Sinistralidade] - [Sinistralidade Mediana Fundações]
```

---

### 2.4 Medida de variação temporal

**Variação da sinistralidade vs. trimestre anterior:**
```dax
Sinistralidade Trimestre Anterior =
CALCULATE(
    [Sinistralidade],
    OFFSET( -1, ORDERBY( dim_trimestre[ordem], ASC ) )
)
```

```dax
Variação Sinistralidade =
[Sinistralidade] - [Sinistralidade Trimestre Anterior]
```

> Se `OFFSET` não estiver disponível na sua versão do Power BI, use a alternativa:
> ```dax
> Sinistralidade Trimestre Anterior =
> VAR OrdemAtual = SELECTEDVALUE( dim_trimestre[ordem] )
> RETURN
> CALCULATE(
>     [Sinistralidade],
>     REMOVEFILTERS( dim_trimestre ),
>     dim_trimestre[ordem] = OrdemAtual - 1
> )
> ```

---

## Parte 3 — Layout das páginas

Princípio geral: cada visual responde exatamente uma pergunta. Nenhum visual
extra "porque ficaria bonito" — isso inclui resistir à tentação de adicionar
mapas, pizzas ou visuais decorativos que não estejam na lista abaixo.

### Segmentador de trimestre — e um cuidado importante

Ambas as páginas têm um segmentador de `dim_trimestre[trimestre]`, com
**Seleção Única** ativada e o trimestre mais recente (`1T2026`) como valor
padrão. Ele controla os **cartões** (que devem mostrar sempre "o valor do
período selecionado") e os visuais de "foto" (dispersão, Top 15).

**Ele NÃO deve afetar os gráficos de linha/tendência**, que precisam mostrar
os 5 trimestres simultaneamente. Configure isso em: selecione o segmentador →
aba **Formatar** → **Editar Interações** → em cada gráfico de tendência,
clique no ícone **"Nenhum"**. Sem esse ajuste, selecionar um trimestre no
segmentador reduziria as linhas de evolução a um único ponto.

### Página 1 — Panorama do setor (autogestões)

**Objetivo:** "Como é o mercado de autogestão hoje, e como evoluiu?"
**Filtro da página:** nenhum (todas as autogestões).

| Visual | Campos | Afetado pelo segmentador? |
|---|---|---|
| Cartão — Operadoras confiáveis | `Contagem Operadoras Confiaveis` | Sim |
| Cartão — Receita do segmento | `Receita Assistencial` (com `dado_confiavel = True`) | Sim |
| Cartão — Sinistralidade mediana | `Sinistralidade Mediana Setor` | Sim |
| Cartão — Operadoras acima de 100% | `Operadoras Acima de 100%` (nova medida, ver abaixo) | Sim |
| Dispersão | Eixo X: `Receita Assistencial` · Eixo Y: `Sinistralidade` · Legenda: `grupo_comparacao` · Detalhes: `operadora` · Filtro: `dado_confiavel = True` | Sim |
| Barras horizontais — Top 15 | Eixo: `operadora` (Top 15 por `Receita Assistencial`) · Valor: `Sinistralidade` · PASA destacada em cor | Sim |
| Linha — evolução do setor | Eixo: `trimestre` · Valor: `Sinistralidade Mediana Setor` | **Não** |

Medida nova para o 4º cartão:

```dax
Operadoras Acima de 100% =
COUNTROWS(
    FILTER(
        CALCULATETABLE(
            VALUES( dim_operadora[REG_ANS] ),
            CROSSFILTER( dim_operadora[REG_ANS], fato_financeiro[REG_ANS], BOTH ),
            REMOVEFILTERS( dim_operadora ),
            fato_financeiro[dado_confiavel] = TRUE
        ),
        CALCULATE( [Sinistralidade] ) > 1
    )
)
```

> Nota: `Sinistralidade Mediana Setor` (e qualquer outra medida que use
> `REMOVEFILTERS`/`CALCULATETABLE` sobre `dim_operadora`) precisa do
> `CROSSFILTER(..., BOTH)` — ver Parte 2.3 — ou vai ignorar o filtro de
> `dado_confiavel` e contar sempre as 142 operadoras do cadastro.

---

### Página 2 — Estudo de caso PASA

**Objetivo:** a narrativa investigativa do relatório, em visual.
**Filtro da página:** `dim_operadora[operadora]` = PASA, nível "desta página".

| Visual | Campos | Afetado pelo segmentador? |
|---|---|---|
| Cartão — Sinistralidade | `Sinistralidade` | Sim |
| Cartão — Resultado Operacional | `Resultado Operacional` (cor condicional verde/vermelho) | Sim |
| Cartão — Taxa de Glosa | `Taxa de Glosa` | Sim |
| Cartão — Gap vs. peer group | `Gap vs Fundações` | Sim |
| Linha — Sinistralidade PASA × peer group | Eixo: `trimestre` · Valores: `Sinistralidade` + `Sinistralidade Mediana Fundações` | **Não** |
| Colunas empilhadas — Composição da receita | Eixo: `trimestre` · Valores: `Receita Assistencial` + `Outras Receitas Operacionais` + `Residuo Receita` | **Não** |
| Colunas empilhadas — Composição da despesa | Eixo: `trimestre` · Valores: `Sinistro` + `Despesa Administrativa` + `Outras Despesas Operacionais` + `Residuo Despesa` | **Não** |
| Colunas — Resultado Operacional | Eixo: `trimestre` · Valor: `Resultado Operacional` (cor condicional) | **Não** |
| Linha — Taxa de Glosa | Eixo: `trimestre` · Valor: `Taxa de Glosa` | **Não** |
| Caixa de texto | Ressalva metodológica: valores acumulados isolados por diferença, receita da Lei 13.127 fora da sinistralidade tradicional, limite de granularidade da DIOPS para investigar causa raiz | — |

Removido do layout original: o gráfico de barras "peer group com PASA
destacada" — ele é redundante com a linha de Sinistralidade PASA × peer group,
que já responde a mesma pergunta de forma mais completa (evolução, não só uma
foto de um trimestre).

---

## Parte 4 — Detalhes que fazem diferença numa entrevista

1. **Formate os números.** Valores em milhões com uma casa decimal, percentuais com
   uma casa. Aba Ferramentas de Medida > Formato.

2. **Use formatação condicional** no cartão de Resultado Operacional: verde se
   positivo, vermelho se negativo. (`Formato > Cor do valor > fx`)

3. **Renomeie os visuais** com títulos que digam a conclusão, não o conteúdo.
   "Sinistralidade acima do peer group em todos os trimestres" é melhor que
   "Sinistralidade por trimestre".

4. **Adicione uma caixa de texto** com a ressalva metodológica: que a DIOPS traz
   valores acumulados e você isolou os trimestres, e que a sinistralidade isolada
   não captura a receita da Lei 13.127. Mostrar que você conhece as limitações do
   próprio dado é o que separa análise de relatório automático.

---

## Parte 5 — Como explicar isso numa entrevista

Se perguntarem "o que você fez neste projeto", a resposta forte não é a lista de
ferramentas — é a sequência de raciocínio:

> "Comecei calculando sinistralidade por operadora com dados públicos da ANS.
> Quando comparei a PASA com o setor, percebi que a comparação era injusta — uma
> carteira de aposentados não se compara a uma de trabalhadores ativos. Refiz o
> benchmark contra fundações de previdência com perfil parecido, e a PASA continuou
> acima da mediana. Depois notei que a sinistralidade sozinha não explicava a saúde
> financeira: existe uma receita específica de autogestão, da Lei 13.127, que fica
> fora da conta de contraprestações. Olhando o resultado operacional completo, a
> operadora está próxima do equilíbrio. A conclusão que levo é que sinistralidade
> isolada superestima o risco em autogestão — é preciso ler os dois indicadores
> juntos."
