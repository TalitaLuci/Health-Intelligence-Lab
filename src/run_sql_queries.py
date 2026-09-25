"""
run_sql_queries.py
-------------------
Carrega os dados tratados (data/processed/) num banco DuckDB em memória e
executa as queries de sql/market_analysis.sql e sql/pasa_analysis.sql.

Serve tanto como demonstração funcional do SQL do projeto quanto como
validação cruzada: os resultados aqui devem bater com os calculados em
Python nos notebooks 02 e 03.

Uso:
    python src/run_sql_queries.py
"""

import duckdb
import pandas as pd
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
PROCESSED = BASE / 'data' / 'processed'
SQL_DIR = BASE / 'sql'


def carregar_dados(con):
    fato = pd.read_csv(PROCESSED / 'fato_financeiro.csv')
    dim_operadora = pd.read_csv(PROCESSED / 'dim_operadora.csv')
    dim_trimestre = pd.read_csv(PROCESSED / 'dim_trimestre.csv')

    con.register('fato_financeiro', fato)
    con.register('dim_operadora', dim_operadora)
    con.register('dim_trimestre', dim_trimestre)


def rodar_arquivo_sql(con, caminho):
    """Executa cada statement de um arquivo .sql (separados por ';') e imprime o resultado."""
    texto = caminho.read_text(encoding='utf-8')
    brutos = [s.strip() for s in texto.split(';') if s.strip()]

    # Mantém o statement inteiro (com comentários) para execução, mas só o
    # considera válido se sobrar alguma linha de SQL de verdade (não-comentário).
    statements_validos = []
    for s in brutos:
        linhas_uteis = [l for l in s.split('\n') if l.strip() and not l.strip().startswith('--')]
        if linhas_uteis:
            statements_validos.append(s)

    for i, stmt in enumerate(statements_validos, start=1):
        print(f"\n{'='*80}\n{caminho.name} — statement {i}\n{'='*80}")
        try:
            resultado = con.execute(stmt).fetchdf()
            print(resultado.to_string(index=False))
        except Exception as e:
            print(f"[ERRO ao executar statement {i}]: {e}")


def main():
    con = duckdb.connect(database=':memory:')
    carregar_dados(con)

    rodar_arquivo_sql(con, SQL_DIR / 'market_analysis.sql')
    rodar_arquivo_sql(con, SQL_DIR / 'pasa_analysis.sql')


if __name__ == '__main__':
    main()
