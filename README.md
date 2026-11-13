# CJOBDD2 – Projeto Final SQL

**Aluno:** Daniel Santos de Castilho
**Disciplina:** Banco de Dados 2 (CJOBDD2) – Prof. Paulo Giovani de Faria Zeferino
**Curso:** Tecnologia em Análise e Desenvolvimento de Sistemas – IFSP Campus Campos do Jordão

## Sistema de Gestão de Restaurante

Relatório: [`Projeto Final SQL - Daniel Santos de Castilho.pdf`](Projeto%20Final%20SQL%20-%20Daniel%20Santos%20de%20Castilho.pdf)

Banco de dados relacional (SQL Server / T-SQL) com **24 tabelas** para a gestão de reservas, comandas, entregas, pagamentos, avaliações, cardápio, compras e estoque de um restaurante.

### Scripts (executar no SSMS, nesta ordem)

Testados no Microsoft SQL Server 2022 Express.


1. `scripts/01_criacao_banco.sql` – cria o banco `RestauranteDB` e as 24 tabelas
2. `scripts/02_carga_dados.sql` – insere os dados (4.693 registros)
3. `scripts/03_objetos.sql` – visão, função, procedimento armazenado e 3 gatilhos
4. `scripts/04_consultas.sql` – as 30 consultas do relatório

### Diagramas

- `diagramas/modelo_conceitual.brM3` – modelo conceitual (abrir no brModelo 3)
- `diagramas/modelo_logico.drawio` – modelo lógico em pé de galinha (abrir em https://app.diagrams.net)
- Imagens PNG dos dois modelos na mesma pasta
