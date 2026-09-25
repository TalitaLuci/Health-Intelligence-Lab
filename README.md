# Health Intelligence Lab (Projeto em construção)

Análise de inteligência de mercado e sinistro no setor de saúde suplementar
brasileiro, construída a partir de dados públicos da ANS (Agência Nacional de
Saúde Suplementar). O projeto tem duas camadas: uma análise setorial ampla,
reutilizável para qualquer contexto de BI em saúde suplementar, e um estudo de
caso aplicado a uma operadora específica.

## Estrutura do projeto

### Camada 1 — Panorama do setor de Autogestão
Análise das 142 operadoras de Autogestão ativas no Brasil (cadastro ANS),
cobrindo 5 trimestres (1T2025–1T2026): sinistralidade, resultado financeiro,
taxa de glosa e comparação entre grupos de perfil semelhante (ex.: fundações
de previdência com carteira majoritariamente de aposentados vs. autogestões de
empresas com força de trabalho ativa).

### Camada 2 — Estudo de caso: PASA (Plano de Assistência à Saúde do
Aposentado da Vale)
Aplicação da mesma metodologia a uma operadora específica, com aprofundamento
analítico: identificação de vieses de comparação, reconciliação de métricas
financeiras e leitura crítica dos limites do dado público.

## Fontes de dados (ANS — Dados Abertos)

| Base | Uso |
|---|---|
| Demonstrações Contábeis (DIOPS) | Receitas, despesas, sinistro, glosa — 5 trimestres |
| Relação de Operadoras Ativas | Cadastro, modalidade, UF |
| Caderno de Informação da Saúde Suplementar | Contexto agregado de mercado |

## Metodologia — pontos que valem destaque

- **Correção de acumulado:** a DIOPS publica saldos acumulados no ano; os
  valores trimestrais isolados foram obtidos por diferença entre acumulados
  consecutivos.
- **Tratamento de outliers:** operadoras com receita trimestral abaixo de
  R$ 100 mil foram sinalizadas como dado pouco confiável (percentuais de
  sinistralidade se distorcem com receita muito baixa) e não excluídas
  silenciosamente — ficam marcadas para decisão explícita de uso.
- **Benchmark ajustado ao perfil de carteira:** a comparação inicial contra
  "todas as autogestões" foi identificada como enviesada para operadoras de
  carteira majoritariamente idosa; o benchmark foi refeito contra um grupo de
  fundações de previdência/seguridade com perfil populacional comparável.
- **Reconciliação de sinistralidade vs. resultado operacional:** identificada
  uma receita específica do regime de autogestão (Lei 13.127) que fica fora da
  conta de contraprestações usada no cálculo tradicional de sinistralidade.
  A leitura de saúde financeira foi corrigida para considerar o resultado
  operacional completo, não a sinistralidade isolada.
- **Taxa de glosa:** decomposição do sinistro em faturado bruto, glosas e
  recuperação por coparticipação, permitindo acompanhar a taxa de glosa como
  KPI de auditoria de contas médicas ao longo do tempo.

## Arquivos

- `etl_sinistralidade_autogestao.py` — ETL da sinistralidade por operadora
- `powerbi/fato_financeiro.csv`, `dim_operadora.csv`, `dim_trimestre.csv` —
  modelo de dados em formato estrela para BI
- `powerbi/GUIA_dashboard_powerbi.md` — construção do dashboard e medidas DAX
- `diagnostico_pasa_consolidado.md` — relatório do estudo de caso PASA
- `pasa_serie_consolidada.csv`, `pasa_benchmark_fundacoes_1T2026.csv` — dados
  de suporte do estudo de caso

## Stack

Python (pandas) para ETL · Power BI (DAX) para visualização · dados públicos
ANS.
