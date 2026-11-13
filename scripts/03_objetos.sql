-- RestauranteDB - visão, função, procedimento e gatilhos
USE RestauranteDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE VIEW vw_comanda_resumo AS
SELECT c.id_comanda,
       CAST(c.data_abertura AS DATE)              AS data,
       c.tipo,
       c.status,
       m.numero                                   AS mesa,
       f.nome                                     AS atendente,
       c.id_cliente,
       ISNULL(cl.nome, N'Não identificado')       AS cliente,
       c.qtd_pessoas,
       SUM(i.quantidade * i.preco_unitario)       AS subtotal,
       CAST(SUM(i.quantidade * i.preco_unitario)
            * c.taxa_servico / 100 AS DECIMAL(10,2)) AS valor_taxa,
       ISNULL(e.taxa_entrega, 0)                  AS taxa_entrega,
       CAST(SUM(i.quantidade * i.preco_unitario)
            * (1 + c.taxa_servico / 100) AS DECIMAL(10,2))
           + ISNULL(e.taxa_entrega, 0)            AS total
FROM comanda c
INNER JOIN funcionario f  ON f.id_funcionario = c.id_funcionario
INNER JOIN item_comanda i ON i.id_comanda     = c.id_comanda
LEFT JOIN mesa m          ON m.id_mesa        = c.id_mesa
LEFT JOIN cliente cl      ON cl.id_cliente    = c.id_cliente
LEFT JOIN entrega e       ON e.id_comanda     = c.id_comanda
GROUP BY c.id_comanda, c.data_abertura, c.tipo, c.status, m.numero,
         f.nome, c.id_cliente, cl.nome, c.qtd_pessoas, c.taxa_servico,
         e.taxa_entrega;
GO

CREATE FUNCTION dbo.fn_total_comanda (@id_comanda INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @total DECIMAL(10,2);

    SELECT @total = CAST(SUM(i.quantidade * i.preco_unitario)
                         * (1 + c.taxa_servico / 100) AS DECIMAL(10,2))
    FROM comanda c
    INNER JOIN item_comanda i ON i.id_comanda = c.id_comanda
    WHERE c.id_comanda = @id_comanda
    GROUP BY c.taxa_servico;

    SELECT @total = ISNULL(@total, 0) + ISNULL(MAX(e.taxa_entrega), 0)
    FROM entrega e
    WHERE e.id_comanda = @id_comanda;

    RETURN @total;
END;
GO

CREATE PROCEDURE dbo.sp_faturamento_periodo
    @inicio DATE,
    @fim    DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @fim < @inicio
    BEGIN
        RAISERROR(N'A data final deve ser maior ou igual à inicial.', 16, 1);
        RETURN;
    END;

    SELECT cat.nome                              AS categoria,
           SUM(i.quantidade)                     AS itens_vendidos,
           SUM(i.quantidade * i.preco_unitario)  AS faturamento
    FROM comanda c
    INNER JOIN item_comanda i ON i.id_comanda     = c.id_comanda
    INNER JOIN produto p      ON p.id_produto     = i.id_produto
    INNER JOIN categoria cat  ON cat.id_categoria = p.id_categoria
    WHERE c.status = N'Fechada'
      AND CAST(c.data_abertura AS DATE) BETWEEN @inicio AND @fim
    GROUP BY cat.nome
    ORDER BY faturamento DESC;
END;
GO

CREATE TRIGGER trg_baixa_estoque
ON item_comanda
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- registra uma saída por comanda e insumo consumido
    INSERT INTO movimentacao_estoque (id_insumo, tipo, quantidade, origem)
    SELECT ft.id_insumo,
           N'Saída',
           -SUM(ft.quantidade * n.quantidade),
           N'Comanda ' + CAST(n.id_comanda AS NVARCHAR(10))
    FROM inserted n
    INNER JOIN ficha_tecnica ft ON ft.id_produto = n.id_produto
    GROUP BY ft.id_insumo, n.id_comanda;

    -- atualiza o saldo (a restrição CHECK impede estoque negativo)
    UPDATE ins
    SET ins.estoque_atual = ins.estoque_atual - x.consumo
    FROM insumo ins
    INNER JOIN (SELECT ft.id_insumo,
                       SUM(ft.quantidade * n.quantidade) AS consumo
                FROM inserted n
                INNER JOIN ficha_tecnica ft ON ft.id_produto = n.id_produto
                GROUP BY ft.id_insumo) AS x
        ON x.id_insumo = ins.id_insumo;
END;
GO

CREATE TRIGGER trg_entrada_estoque
ON item_compra
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO movimentacao_estoque (id_insumo, tipo, quantidade, origem)
    SELECT n.id_insumo, N'Entrada', n.quantidade,
           N'Compra NF ' + c.numero_nf
    FROM inserted n
    INNER JOIN compra c ON c.id_compra = n.id_compra;

    UPDATE ins
    SET ins.estoque_atual = ins.estoque_atual + x.qtd
    FROM insumo ins
    INNER JOIN (SELECT id_insumo, SUM(quantidade) AS qtd
                FROM inserted
                GROUP BY id_insumo) AS x
        ON x.id_insumo = ins.id_insumo;
END;
GO

CREATE TRIGGER trg_historico_preco
ON produto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(preco_venda)
        INSERT INTO historico_preco (id_produto, preco_anterior, preco_novo)
        SELECT d.id_produto, d.preco_venda, i.preco_venda
        FROM deleted d
        INNER JOIN inserted i ON i.id_produto = d.id_produto
        WHERE i.preco_venda <> d.preco_venda;
END;
GO
