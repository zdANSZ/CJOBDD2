-- RestauranteDB - 30 consultas do relatório
USE RestauranteDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Consulta 1 - Itens de uma comanda
SELECT c.id_comanda,
       cat.nome                          AS categoria,
       p.nome                            AS produto,
       i.quantidade,
       i.preco_unitario,
       i.quantidade * i.preco_unitario   AS subtotal
FROM comanda c
INNER JOIN item_comanda i ON i.id_comanda     = c.id_comanda
INNER JOIN produto p      ON p.id_produto     = i.id_produto
INNER JOIN categoria cat  ON cat.id_categoria = p.id_categoria
WHERE c.id_comanda = 307
ORDER BY cat.id_categoria, p.nome;
GO

-- Consulta 2 - Produtos que nunca foram vendidos
SELECT p.id_produto,
       p.nome,
       cat.nome      AS categoria,
       p.preco_venda,
       CASE p.ativo WHEN 1 THEN N'Sim' ELSE N'Não' END AS ativo
FROM produto p
INNER JOIN categoria cat ON cat.id_categoria = p.id_categoria
LEFT JOIN item_comanda i ON i.id_produto     = p.id_produto
WHERE i.id_item IS NULL
ORDER BY p.nome;
GO

-- Consulta 3 - Faturamento por categoria
SELECT cat.nome                             AS categoria,
       COUNT(DISTINCT p.id_produto)         AS produtos_vendidos,
       SUM(i.quantidade)                    AS itens,
       SUM(i.quantidade * i.preco_unitario) AS faturamento
FROM categoria cat
INNER JOIN produto p      ON p.id_categoria = cat.id_categoria
INNER JOIN item_comanda i ON i.id_produto   = p.id_produto
INNER JOIN comanda c      ON c.id_comanda   = i.id_comanda
WHERE c.status = N'Fechada'
GROUP BY cat.nome
ORDER BY faturamento DESC;
GO

-- Consulta 4 - Resumo mensal de atendimento
SELECT YEAR(t.data)                         AS ano,
       MONTH(t.data)                        AS mes,
       COUNT(*)                             AS comandas,
       SUM(ISNULL(t.qtd_pessoas, 0))        AS pessoas_salao,
       SUM(t.total)                         AS faturamento,
       CAST(AVG(t.total) AS DECIMAL(10,2))  AS ticket_medio
FROM (SELECT data, qtd_pessoas, total
      FROM vw_comanda_resumo
      WHERE status = N'Fechada') AS t
GROUP BY YEAR(t.data), MONTH(t.data)
ORDER BY ano, mes;
GO

-- Consulta 5 - Garçons com mais de 30 comandas em outubro
SELECT f.nome                         AS garcom,
       COUNT(*)                       AS comandas,
       SUM(v.qtd_pessoas)             AS pessoas,
       SUM(v.valor_taxa)              AS taxa_servico_gerada
FROM funcionario f
INNER JOIN cargo cg            ON cg.id_cargo   = f.id_cargo
INNER JOIN comanda c           ON c.id_funcionario = f.id_funcionario
INNER JOIN vw_comanda_resumo v ON v.id_comanda  = c.id_comanda
WHERE cg.nome = N'Garçom'
  AND c.status = N'Fechada'
  AND c.data_abertura >= '2026-10-01'
  AND c.data_abertura <  '2026-11-01'
GROUP BY f.nome
HAVING COUNT(*) > 30
ORDER BY comandas DESC;
GO

-- Consulta 6 - Produtos mais caros que a média da categoria
SELECT cat.nome    AS categoria,
       p.nome,
       p.preco_venda,
       (SELECT CAST(AVG(p2.preco_venda) AS DECIMAL(10,2))
        FROM produto p2
        WHERE p2.id_categoria = p.id_categoria
          AND p2.ativo = 1)               AS media_categoria
FROM produto p
INNER JOIN categoria cat ON cat.id_categoria = p.id_categoria
WHERE p.ativo = 1
  AND p.preco_venda > (SELECT AVG(p2.preco_venda)
                       FROM produto p2
                       WHERE p2.id_categoria = p.id_categoria
                         AND p2.ativo = 1)
ORDER BY cat.nome, p.preco_venda DESC;
GO

-- Consulta 7 - Clientes sem visitas em outubro
SELECT cl.nome,
       ci.nome + N'/' + ci.uf              AS cidade,
       cl.data_cadastro,
       (SELECT MAX(CAST(c2.data_abertura AS DATE))
        FROM comanda c2
        WHERE c2.id_cliente = cl.id_cliente) AS ultima_visita
FROM cliente cl
INNER JOIN cidade ci ON ci.id_cidade = cl.id_cidade
WHERE NOT EXISTS (SELECT 1
                  FROM comanda c
                  WHERE c.id_cliente = cl.id_cliente
                    AND c.data_abertura >= '2026-10-01'
                    AND c.data_abertura <  '2026-11-01')
ORDER BY ultima_visita;
GO

-- Consulta 8 - Fornecedores de insumos de fondues e de sobremesas
SELECT f.razao_social, ci.nome AS cidade
FROM fornecedor f
INNER JOIN cidade ci ON ci.id_cidade = f.id_cidade
WHERE f.id_fornecedor IN (
        SELECT ins.id_fornecedor
        FROM insumo ins
        INNER JOIN ficha_tecnica ft ON ft.id_insumo = ins.id_insumo
        INNER JOIN produto p        ON p.id_produto = ft.id_produto
        INNER JOIN categoria cat    ON cat.id_categoria = p.id_categoria
        WHERE cat.nome = N'Fondues')
INTERSECT
SELECT f.razao_social, ci.nome
FROM fornecedor f
INNER JOIN cidade ci ON ci.id_cidade = f.id_cidade
WHERE f.id_fornecedor IN (
        SELECT ins.id_fornecedor
        FROM insumo ins
        INNER JOIN ficha_tecnica ft ON ft.id_insumo = ins.id_insumo
        INNER JOIN produto p        ON p.id_produto = ft.id_produto
        INNER JOIN categoria cat    ON cat.id_categoria = p.id_categoria
        WHERE cat.nome = N'Sobremesas')
ORDER BY razao_social;
GO

-- Consulta 9 - Comparecimento das reservas por área
SELECT a.nome    AS area,
       COUNT(*)  AS reservas,
       SUM(CASE WHEN r.status = N'Realizada'
                THEN 1 ELSE 0 END)                 AS realizadas,
       SUM(CASE WHEN r.status = N'Cancelada'
                THEN 1 ELSE 0 END)                 AS canceladas,
       SUM(CASE WHEN r.status = N'Não compareceu'
                THEN 1 ELSE 0 END)                 AS no_show,
       CAST(100.0 * SUM(CASE WHEN r.status = N'Realizada'
                             THEN 1 ELSE 0 END) / COUNT(*)
            AS DECIMAL(5,2))                       AS comparecimento_pct
FROM reserva r
INNER JOIN mesa m ON m.id_mesa = r.id_mesa
INNER JOIN area a ON a.id_area = m.id_area
WHERE r.status <> N'Confirmada'
GROUP BY a.nome
ORDER BY comparecimento_pct DESC;
GO

-- Consulta 10 - Ticket médio por dia da semana
WITH totais AS (
    SELECT id_comanda,
           total,
           DATEDIFF(DAY, '19000101', data) % 7 AS dia_semana -- 0 = seg.
    FROM vw_comanda_resumo
    WHERE status = N'Fechada'
)
SELECT CASE dia_semana
           WHEN 2 THEN N'Quarta-feira'
           WHEN 3 THEN N'Quinta-feira'
           WHEN 4 THEN N'Sexta-feira'
           WHEN 5 THEN N'Sábado'
           WHEN 6 THEN N'Domingo'
       END                                   AS dia,
       COUNT(*)                              AS comandas,
       CAST(AVG(total) AS DECIMAL(10,2))     AS ticket_medio
FROM totais
GROUP BY dia_semana
ORDER BY dia_semana;
GO

-- Consulta 11 - Os dois produtos mais vendidos de cada categoria
WITH vendas AS (
    SELECT cat.nome          AS categoria,
           p.nome            AS produto,
           SUM(i.quantidade) AS qtd_vendida,
           ROW_NUMBER() OVER (PARTITION BY cat.id_categoria
                              ORDER BY SUM(i.quantidade) DESC,
                                       p.nome) AS posicao
    FROM item_comanda i
    INNER JOIN comanda c     ON c.id_comanda     = i.id_comanda
    INNER JOIN produto p     ON p.id_produto     = i.id_produto
    INNER JOIN categoria cat ON cat.id_categoria = p.id_categoria
    WHERE c.status = N'Fechada'
    GROUP BY cat.id_categoria, cat.nome, p.nome
)
SELECT categoria, posicao, produto, qtd_vendida
FROM vendas
WHERE posicao <= 2
ORDER BY categoria, posicao;
GO

-- Consulta 12 - Ranking de garçons por faturamento
SELECT RANK() OVER (ORDER BY SUM(v.total) DESC)  AS posicao,
       v.atendente                                AS garcom,
       COUNT(*)                                   AS comandas,
       SUM(v.total)                               AS faturamento,
       CAST(100.0 * SUM(v.total)
            / SUM(SUM(v.total)) OVER ()
            AS DECIMAL(5,2))                      AS participacao_pct
FROM vw_comanda_resumo v
WHERE v.status = N'Fechada'
  AND v.tipo   = N'Salão'
GROUP BY v.atendente
ORDER BY posicao;
GO

-- Consulta 13 - Satisfação dos clientes por garçom
SELECT DENSE_RANK() OVER (ORDER BY AVG(a.nota_atendimento * 1.0) DESC)
                                              AS posicao,
       f.nome                                 AS garcom,
       COUNT(*)                               AS avaliacoes,
       CAST(AVG(a.nota_comida * 1.0)
            AS DECIMAL(3,2))                  AS media_comida,
       CAST(AVG(a.nota_atendimento * 1.0)
            AS DECIMAL(3,2))                  AS media_atendimento,
       CAST(100.0 * SUM(CASE WHEN a.nota_comida <= 3
                              OR a.nota_atendimento <= 3
                             THEN 1 ELSE 0 END) / COUNT(*)
            AS DECIMAL(5,2))                  AS criticas_pct
FROM avaliacao a
INNER JOIN comanda c     ON c.id_comanda     = a.id_comanda
INNER JOIN funcionario f ON f.id_funcionario = c.id_funcionario
GROUP BY f.nome
ORDER BY posicao, f.nome;
GO

-- Consulta 14 - Variação semanal do faturamento
WITH semanas AS (
    SELECT DATEPART(ISO_WEEK, data)  AS semana,
           MIN(data)                 AS primeiro_dia,
           MAX(data)                 AS ultimo_dia,
           SUM(total)                AS faturamento
    FROM vw_comanda_resumo
    WHERE status = N'Fechada'
    GROUP BY DATEPART(ISO_WEEK, data)
)
SELECT semana,
       primeiro_dia,
       ultimo_dia,
       faturamento,
       LAG(faturamento) OVER (ORDER BY semana) AS semana_anterior,
       CAST(100.0 * (faturamento - LAG(faturamento) OVER (ORDER BY semana))
            / NULLIF(LAG(faturamento) OVER (ORDER BY semana), 0)
            AS DECIMAL(6,2))                   AS variacao_pct
FROM semanas
ORDER BY semana;
GO

-- Consulta 15 - Efeito dos reajustes de preço nas vendas
SELECT p.nome                                   AS produto,
       CAST(h.data_alteracao AS DATE)           AS data_reajuste,
       h.preco_anterior,
       h.preco_novo,
       CAST(100.0 * (h.preco_novo - h.preco_anterior)
            / h.preco_anterior AS DECIMAL(5,2)) AS reajuste_pct,
       (SELECT CAST(ISNULL(SUM(i.quantidade), 0) / 14.0 AS DECIMAL(6,2))
        FROM item_comanda i
        INNER JOIN comanda c ON c.id_comanda = i.id_comanda
        WHERE i.id_produto = h.id_produto
          AND c.data_abertura >= DATEADD(DAY, -14, h.data_alteracao)
          AND c.data_abertura <  h.data_alteracao)  AS media_dia_antes,
       (SELECT CAST(ISNULL(SUM(i.quantidade), 0) / 14.0 AS DECIMAL(6,2))
        FROM item_comanda i
        INNER JOIN comanda c ON c.id_comanda = i.id_comanda
        WHERE i.id_produto = h.id_produto
          AND c.data_abertura >= h.data_alteracao
          AND c.data_abertura <  DATEADD(DAY, 14, h.data_alteracao))
                                                AS media_dia_depois
FROM historico_preco h
INNER JOIN produto p ON p.id_produto = h.id_produto
ORDER BY h.data_alteracao, p.nome;
GO

-- Consulta 16 - Insumos abaixo do estoque mínimo
SELECT ins.nome                                    AS insumo,
       u.sigla                                     AS un,
       ins.estoque_atual,
       ins.estoque_minimo,
       ins.estoque_minimo * 2 - ins.estoque_atual  AS qtd_comprar,
       CAST((ins.estoque_minimo * 2 - ins.estoque_atual)
            * ins.custo_unitario AS DECIMAL(10,2))  AS custo_estimado,
       f.razao_social                              AS fornecedor,
       f.telefone
FROM insumo ins
INNER JOIN unidade_medida u ON u.id_unidade    = ins.id_unidade
INNER JOIN fornecedor f     ON f.id_fornecedor = ins.id_fornecedor
WHERE ins.estoque_atual < ins.estoque_minimo
ORDER BY custo_estimado DESC;
GO

-- Consulta 17 - Custo e margem de contribuição dos produtos
SELECT TOP (10)
       p.nome                                     AS produto,
       p.preco_venda,
       CAST(SUM(ft.quantidade * ins.custo_unitario)
            AS DECIMAL(10,2))                     AS custo,
       CAST(100.0 * (p.preco_venda
                     - SUM(ft.quantidade * ins.custo_unitario))
            / p.preco_venda AS DECIMAL(5,2))      AS margem_pct
FROM produto p
INNER JOIN ficha_tecnica ft ON ft.id_produto = p.id_produto
INNER JOIN insumo ins       ON ins.id_insumo = ft.id_insumo
WHERE p.ativo = 1
GROUP BY p.id_produto, p.nome, p.preco_venda
ORDER BY margem_pct, p.nome;
GO

-- Consulta 18 - Ficha técnica dos fondues e das massas
SELECT cat.nome                                   AS categoria,
       p.nome                                     AS produto,
       STRING_AGG(ins.nome + N' ('
                  + FORMAT(ft.quantidade, '0.###', 'pt-BR') + N' '
                  + u.sigla + N')', N', ')
           WITHIN GROUP (ORDER BY ins.nome)       AS receita
FROM produto p
INNER JOIN categoria cat    ON cat.id_categoria = p.id_categoria
INNER JOIN ficha_tecnica ft ON ft.id_produto    = p.id_produto
INNER JOIN insumo ins       ON ins.id_insumo    = ft.id_insumo
INNER JOIN unidade_medida u ON u.id_unidade     = ins.id_unidade
WHERE cat.nome IN (N'Fondues', N'Massas e Risotos')
GROUP BY cat.nome, p.nome
ORDER BY cat.nome, p.nome;
GO

-- Consulta 19 - Agenda de contatos locais
SELECT N'Cliente'                    AS tipo,
       cl.nome,
       cl.telefone,
       ISNULL(cl.email, N'(sem e-mail)') AS email
FROM cliente cl
INNER JOIN cidade ci ON ci.id_cidade = cl.id_cidade
WHERE ci.nome = N'Campos do Jordão'
UNION ALL
SELECT N'Fornecedor',
       f.razao_social,
       f.telefone,
       ISNULL(f.email, N'(sem e-mail)')
FROM fornecedor f
INNER JOIN cidade ci ON ci.id_cidade = f.id_cidade
WHERE ci.nome = N'Campos do Jordão'
ORDER BY tipo, nome;
GO

-- Consulta 20 - Recebimentos por forma de pagamento
SELECT fp.descricao                                 AS forma,
       COUNT(*)                                     AS transacoes,
       SUM(pg.valor)                                AS bruto,
       CAST(SUM(pg.valor * fp.taxa_operadora / 100)
            AS DECIMAL(10,2))                       AS taxa_operadora,
       CAST(SUM(pg.valor * (1 - fp.taxa_operadora / 100))
            AS DECIMAL(10,2))                       AS liquido,
       CAST(100.0 * SUM(pg.valor) / SUM(SUM(pg.valor)) OVER ()
            AS DECIMAL(5,2))                        AS participacao_pct
FROM pagamento pg
INNER JOIN forma_pagamento fp ON fp.id_forma = pg.id_forma
GROUP BY fp.descricao
ORDER BY bruto DESC;
GO

-- Consulta 21 - Faturamento por mês e tipo de atendimento (ROLLUP)
SELECT CASE WHEN GROUPING(MONTH(data)) = 1 THEN N'Total geral'
            ELSE FORMAT(MONTH(data), '00') END    AS mes,
       CASE WHEN GROUPING(tipo) = 1 THEN N'Subtotal'
            ELSE tipo END                          AS tipo,
       COUNT(*)                                    AS comandas,
       SUM(total)                                  AS faturamento
FROM vw_comanda_resumo
WHERE status = N'Fechada'
GROUP BY ROLLUP (MONTH(data), tipo)
ORDER BY GROUPING(MONTH(data)), MONTH(data), GROUPING(tipo), tipo;
GO

-- Consulta 22 - Desempenho das entregas por bairro
SELECT ed.bairro,
       COUNT(*)                                        AS entregas,
       AVG(DATEDIFF(MINUTE, c.data_abertura,
                    e.data_entrega))                   AS tempo_total_min,
       AVG(DATEDIFF(MINUTE, e.data_saida,
                    e.data_entrega))                   AS deslocamento_min,
       MAX(e.taxa_entrega)                             AS taxa,
       SUM(e.taxa_entrega)                             AS taxas_arrecadadas
FROM entrega e
INNER JOIN endereco ed ON ed.id_endereco = e.id_endereco
INNER JOIN comanda c   ON c.id_comanda   = e.id_comanda
GROUP BY ed.bairro
ORDER BY entregas DESC, ed.bairro;
GO

-- Consulta 23 - Clientes que mais gastaram (função escalar)
SELECT TOP (10)
       cl.nome                                       AS cliente,
       ci.nome                                       AS cidade,
       COUNT(c.id_comanda)                           AS visitas,
       SUM(dbo.fn_total_comanda(c.id_comanda))       AS total_gasto,
       CAST(AVG(dbo.fn_total_comanda(c.id_comanda))
            AS DECIMAL(10,2))                        AS gasto_medio
FROM cliente cl
INNER JOIN cidade ci  ON ci.id_cidade = cl.id_cidade
INNER JOIN comanda c  ON c.id_cliente = cl.id_cliente
WHERE c.status = N'Fechada'
GROUP BY cl.id_cliente, cl.nome, ci.nome
ORDER BY total_gasto DESC, cl.nome;
GO

-- Consulta 24 - Faturamento de um período (procedimento armazenado)
EXEC dbo.sp_faturamento_periodo
     @inicio = '2026-10-08',
     @fim    = '2026-10-12';
GO

-- Consulta 25 - Baixa automática de estoque (gatilho e transação)
BEGIN TRANSACTION;

DECLARE @antes TABLE (id_insumo INT, estoque DECIMAL(10,3));

INSERT INTO @antes (id_insumo, estoque)
SELECT ft.id_insumo, ins.estoque_atual
FROM ficha_tecnica ft
INNER JOIN insumo ins ON ins.id_insumo = ft.id_insumo
INNER JOIN produto p  ON p.id_produto  = ft.id_produto
WHERE p.nome = N'Fondue de Queijo';

INSERT INTO item_comanda (id_comanda, id_produto, quantidade, preco_unitario)
SELECT 421, id_produto, 2, preco_venda
FROM produto
WHERE nome = N'Fondue de Queijo';

SELECT ins.nome              AS insumo,
       a.estoque             AS estoque_antes,
       ins.estoque_atual     AS estoque_depois,
       m.quantidade          AS movimentacao,
       m.origem
FROM @antes a
INNER JOIN insumo ins ON ins.id_insumo = a.id_insumo
INNER JOIN movimentacao_estoque m
        ON m.id_insumo = a.id_insumo
       AND m.origem    = N'Comanda 421'
ORDER BY ins.nome;

ROLLBACK TRANSACTION;
GO

-- Consulta 26 - Compras por fornecedor no período
WITH notas AS (
    SELECT c.id_compra,
           c.id_fornecedor,
           SUM(ic.quantidade * ic.custo_unitario) AS valor_nota
    FROM compra c
    INNER JOIN item_compra ic ON ic.id_compra = c.id_compra
    GROUP BY c.id_compra, c.id_fornecedor
)
SELECT f.razao_social                                 AS fornecedor,
       COUNT(*)                                       AS notas,
       (SELECT COUNT(DISTINCT ic.id_insumo)
        FROM item_compra ic
        INNER JOIN compra c2 ON c2.id_compra = ic.id_compra
        WHERE c2.id_fornecedor = f.id_fornecedor)     AS insumos,
       CAST(SUM(n.valor_nota) AS DECIMAL(10,2))       AS total_comprado,
       CAST(AVG(n.valor_nota) AS DECIMAL(10,2))       AS media_por_nota
FROM notas n
INNER JOIN fornecedor f ON f.id_fornecedor = n.id_fornecedor
GROUP BY f.id_fornecedor, f.razao_social
ORDER BY total_comprado DESC;
GO

-- Consulta 27 - Faturamento por categoria e mês (PIVOT)
SELECT categoria,
       ISNULL([9], 0)                   AS setembro,
       ISNULL([10], 0)                  AS outubro,
       ISNULL([10], 0) - ISNULL([9], 0) AS diferenca
FROM (SELECT cat.nome                         AS categoria,
             MONTH(c.data_abertura)           AS mes,
             i.quantidade * i.preco_unitario  AS valor
      FROM item_comanda i
      INNER JOIN comanda c     ON c.id_comanda     = i.id_comanda
      INNER JOIN produto p     ON p.id_produto     = i.id_produto
      INNER JOIN categoria cat ON cat.id_categoria = p.id_categoria
      WHERE c.status = N'Fechada') AS origem
PIVOT (SUM(valor) FOR mes IN ([9], [10])) AS pvt
ORDER BY outubro DESC;
GO

-- Consulta 28 - Produtos pedidos juntos com mais frequência
SELECT TOP (10)
       pa.nome           AS produto_a,
       pb.nome           AS produto_b,
       COUNT(*)          AS comandas_juntos
FROM item_comanda a
INNER JOIN item_comanda b ON b.id_comanda = a.id_comanda
                         AND a.id_produto < b.id_produto
INNER JOIN produto pa     ON pa.id_produto = a.id_produto
INNER JOIN produto pb     ON pb.id_produto = b.id_produto
INNER JOIN comanda c      ON c.id_comanda  = a.id_comanda
WHERE c.status = N'Fechada'
GROUP BY pa.nome, pb.nome
ORDER BY comandas_juntos DESC, pa.nome, pb.nome;
GO

-- Consulta 29 - Segmentação de clientes em quartis de gasto
WITH gastos AS (
    SELECT cl.nome,
           SUM(v.total) AS total_gasto
    FROM cliente cl
    INNER JOIN vw_comanda_resumo v ON v.id_cliente = cl.id_cliente
    WHERE v.status = N'Fechada'
    GROUP BY cl.id_cliente, cl.nome
)
SELECT nome,
       total_gasto,
       NTILE(4) OVER (ORDER BY total_gasto DESC) AS quartil,
       CASE NTILE(4) OVER (ORDER BY total_gasto DESC)
           WHEN 1 THEN N'Ouro'
           WHEN 2 THEN N'Prata'
           WHEN 3 THEN N'Bronze'
           ELSE        N'Ocasional'
       END                                       AS segmento
FROM gastos
ORDER BY total_gasto DESC;
GO

-- Consulta 30 - Saldo semanal de estoque de um insumo
WITH semanal AS (
    SELECT DATEPART(ISO_WEEK, m.data_movimentacao)      AS semana,
           MIN(CAST(m.data_movimentacao AS DATE))       AS inicio,
           SUM(CASE WHEN m.tipo = N'Entrada'
                    THEN m.quantidade ELSE 0 END)       AS entradas,
           SUM(CASE WHEN m.tipo = N'Saída'
                    THEN m.quantidade ELSE 0 END)       AS saidas,
           SUM(CASE WHEN m.tipo = N'Ajuste'
                    THEN m.quantidade ELSE 0 END)       AS ajustes
    FROM movimentacao_estoque m
    INNER JOIN insumo ins ON ins.id_insumo = m.id_insumo
    WHERE ins.nome = N'Queijo Gruyère'
    GROUP BY DATEPART(ISO_WEEK, m.data_movimentacao)
)
SELECT semana,
       inicio,
       ajustes,
       entradas,
       saidas,
       SUM(ajustes + entradas + saidas)
           OVER (ORDER BY semana ROWS UNBOUNDED PRECEDING) AS saldo
FROM semanal
ORDER BY semana;
GO
