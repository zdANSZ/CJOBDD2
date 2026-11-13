-- RestauranteDB - criação do banco e das 24 tabelas (SQL Server / T-SQL)

CREATE DATABASE RestauranteDB;
GO

USE RestauranteDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- exigido pelo índice único filtrado
GO

/* ---------- Tabelas de domínio ---------- */

CREATE TABLE cargo (
    id_cargo   INT IDENTITY(1,1) NOT NULL,
    nome       NVARCHAR(30)  NOT NULL,
    descricao  NVARCHAR(150) NULL,
    CONSTRAINT pk_cargo      PRIMARY KEY (id_cargo),
    CONSTRAINT uq_cargo_nome UNIQUE (nome)
);

CREATE TABLE area (
    id_area    INT IDENTITY(1,1) NOT NULL,
    nome       NVARCHAR(20)  NOT NULL,
    descricao  NVARCHAR(150) NULL,
    CONSTRAINT pk_area      PRIMARY KEY (id_area),
    CONSTRAINT uq_area_nome UNIQUE (nome)
);

CREATE TABLE cidade (
    id_cidade  INT IDENTITY(1,1) NOT NULL,
    nome       NVARCHAR(60) NOT NULL,
    uf         CHAR(2)      NOT NULL,
    CONSTRAINT pk_cidade         PRIMARY KEY (id_cidade),
    CONSTRAINT uq_cidade_nome_uf UNIQUE (nome, uf)
);

CREATE TABLE forma_pagamento (
    id_forma         INT IDENTITY(1,1) NOT NULL,
    descricao        NVARCHAR(20) NOT NULL,
    taxa_operadora   DECIMAL(4,2) NOT NULL
        CONSTRAINT df_forma_taxa DEFAULT 0,
    CONSTRAINT pk_forma_pagamento PRIMARY KEY (id_forma),
    CONSTRAINT uq_forma_descricao UNIQUE (descricao),
    CONSTRAINT ck_forma_taxa      CHECK (taxa_operadora BETWEEN 0 AND 10)
);

CREATE TABLE unidade_medida (
    id_unidade  INT IDENTITY(1,1) NOT NULL,
    sigla       NVARCHAR(3)  NOT NULL,
    descricao   NVARCHAR(20) NOT NULL,
    CONSTRAINT pk_unidade_medida PRIMARY KEY (id_unidade),
    CONSTRAINT uq_unidade_sigla  UNIQUE (sigla)
);

CREATE TABLE categoria (
    id_categoria  INT IDENTITY(1,1) NOT NULL,
    nome          NVARCHAR(50)  NOT NULL,
    descricao     NVARCHAR(150) NULL,
    CONSTRAINT pk_categoria      PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_nome UNIQUE (nome)
);

/* ---------- Cardápio ---------- */

CREATE TABLE produto (
    id_produto         INT IDENTITY(1,1) NOT NULL,
    id_categoria       INT           NOT NULL,
    nome               NVARCHAR(80)  NOT NULL,
    preco_venda        DECIMAL(10,2) NOT NULL,
    tempo_preparo_min  INT           NULL,
    ativo              BIT           NOT NULL
        CONSTRAINT df_produto_ativo DEFAULT 1,
    CONSTRAINT pk_produto           PRIMARY KEY (id_produto),
    CONSTRAINT uq_produto_nome      UNIQUE (nome),
    CONSTRAINT fk_produto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id_categoria),
    CONSTRAINT ck_produto_preco     CHECK (preco_venda > 0),
    CONSTRAINT ck_produto_tempo     CHECK (tempo_preparo_min >= 0)
);

CREATE TABLE historico_preco (
    id_historico    INT IDENTITY(1,1) NOT NULL,
    id_produto      INT           NOT NULL,
    preco_anterior  DECIMAL(10,2) NOT NULL,
    preco_novo      DECIMAL(10,2) NOT NULL,
    data_alteracao  DATETIME2(0)  NOT NULL
        CONSTRAINT df_historico_data DEFAULT SYSDATETIME(),
    CONSTRAINT pk_historico_preco PRIMARY KEY (id_historico),
    CONSTRAINT fk_historico_produto FOREIGN KEY (id_produto)
        REFERENCES produto (id_produto),
    CONSTRAINT ck_historico_precos
        CHECK (preco_anterior > 0 AND preco_novo > 0
               AND preco_novo <> preco_anterior)
);

/* ---------- Pessoas e espaço físico ---------- */

CREATE TABLE funcionario (
    id_funcionario  INT IDENTITY(1,1) NOT NULL,
    id_cargo        INT           NOT NULL,
    nome            NVARCHAR(100) NOT NULL,
    cpf             CHAR(11)      NOT NULL,
    data_admissao   DATE          NOT NULL,
    salario         DECIMAL(10,2) NOT NULL,
    ativo           BIT           NOT NULL
        CONSTRAINT df_funcionario_ativo DEFAULT 1,
    CONSTRAINT pk_funcionario       PRIMARY KEY (id_funcionario),
    CONSTRAINT uq_funcionario_cpf   UNIQUE (cpf),
    CONSTRAINT fk_funcionario_cargo FOREIGN KEY (id_cargo)
        REFERENCES cargo (id_cargo),
    CONSTRAINT ck_funcionario_sal   CHECK (salario > 0)
);

CREATE TABLE mesa (
    id_mesa     INT IDENTITY(1,1) NOT NULL,
    id_area     INT NOT NULL,
    numero      INT NOT NULL,
    capacidade  INT NOT NULL,
    CONSTRAINT pk_mesa        PRIMARY KEY (id_mesa),
    CONSTRAINT uq_mesa_numero UNIQUE (numero),
    CONSTRAINT fk_mesa_area   FOREIGN KEY (id_area)
        REFERENCES area (id_area),
    CONSTRAINT ck_mesa_cap    CHECK (capacidade > 0)
);

CREATE TABLE cliente (
    id_cliente     INT IDENTITY(1,1) NOT NULL,
    id_cidade      INT           NOT NULL,
    nome           NVARCHAR(100) NOT NULL,
    telefone       VARCHAR(11)   NOT NULL,
    email          VARCHAR(100)  NULL,
    data_cadastro  DATE          NOT NULL
        CONSTRAINT df_cliente_cadastro DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT pk_cliente          PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_telefone UNIQUE (telefone),
    CONSTRAINT fk_cliente_cidade   FOREIGN KEY (id_cidade)
        REFERENCES cidade (id_cidade)
);

CREATE TABLE endereco (
    id_endereco  INT IDENTITY(1,1) NOT NULL,
    id_cliente   INT           NOT NULL,
    id_cidade    INT           NOT NULL,
    logradouro   NVARCHAR(100) NOT NULL,
    numero       NVARCHAR(10)  NOT NULL,
    bairro       NVARCHAR(50)  NOT NULL,
    cep          CHAR(8)       NOT NULL,
    complemento  NVARCHAR(50)  NULL,
    CONSTRAINT pk_endereco         PRIMARY KEY (id_endereco),
    CONSTRAINT fk_endereco_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente),
    CONSTRAINT fk_endereco_cidade  FOREIGN KEY (id_cidade)
        REFERENCES cidade (id_cidade)
);

CREATE TABLE reserva (
    id_reserva   INT IDENTITY(1,1) NOT NULL,
    id_cliente   INT           NOT NULL,
    id_mesa      INT           NOT NULL,
    data_hora    DATETIME2(0)  NOT NULL,
    qtd_pessoas  INT           NOT NULL,
    status       NVARCHAR(15)  NOT NULL
        CONSTRAINT df_reserva_status DEFAULT N'Confirmada',
    observacao   NVARCHAR(100) NULL,
    CONSTRAINT pk_reserva          PRIMARY KEY (id_reserva),
    CONSTRAINT fk_reserva_cliente  FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente),
    CONSTRAINT fk_reserva_mesa     FOREIGN KEY (id_mesa)
        REFERENCES mesa (id_mesa),
    CONSTRAINT uq_reserva_mesa_hora UNIQUE (id_mesa, data_hora),
    CONSTRAINT ck_reserva_pessoas  CHECK (qtd_pessoas > 0),
    CONSTRAINT ck_reserva_status   CHECK (status IN (N'Confirmada',
        N'Realizada', N'Cancelada', N'Não compareceu'))
);

/* ---------- Atendimento ---------- */

CREATE TABLE comanda (
    id_comanda       INT IDENTITY(1,1) NOT NULL,
    id_mesa          INT           NULL,
    id_funcionario   INT           NOT NULL,
    id_cliente       INT           NULL,
    id_reserva       INT           NULL,
    tipo             NVARCHAR(10)  NOT NULL,
    qtd_pessoas      INT           NULL,
    taxa_servico     DECIMAL(4,2)  NOT NULL
        CONSTRAINT df_comanda_taxa DEFAULT 10.00,
    data_abertura    DATETIME2(0)  NOT NULL
        CONSTRAINT df_comanda_abertura DEFAULT SYSDATETIME(),
    data_fechamento  DATETIME2(0)  NULL,
    status           NVARCHAR(10)  NOT NULL
        CONSTRAINT df_comanda_status DEFAULT N'Aberta',
    CONSTRAINT pk_comanda             PRIMARY KEY (id_comanda),
    CONSTRAINT fk_comanda_mesa        FOREIGN KEY (id_mesa)
        REFERENCES mesa (id_mesa),
    CONSTRAINT fk_comanda_funcionario FOREIGN KEY (id_funcionario)
        REFERENCES funcionario (id_funcionario),
    CONSTRAINT fk_comanda_cliente     FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente),
    CONSTRAINT fk_comanda_reserva     FOREIGN KEY (id_reserva)
        REFERENCES reserva (id_reserva),
    CONSTRAINT ck_comanda_tipo
        CHECK (tipo IN (N'Salão', N'Delivery', N'Retirada')),
    CONSTRAINT ck_comanda_status
        CHECK (status IN (N'Aberta', N'Fechada', N'Cancelada')),
    CONSTRAINT ck_comanda_mesa_tipo
        CHECK ((tipo = N'Salão' AND id_mesa IS NOT NULL)
            OR (tipo <> N'Salão' AND id_mesa IS NULL)),
    CONSTRAINT ck_comanda_taxa  CHECK (taxa_servico BETWEEN 0 AND 20),
    CONSTRAINT ck_comanda_datas
        CHECK (data_fechamento IS NULL
            OR data_fechamento >= data_abertura)
);

CREATE TABLE item_comanda (
    id_item         INT IDENTITY(1,1) NOT NULL,
    id_comanda      INT           NOT NULL,
    id_produto      INT           NOT NULL,
    quantidade      INT           NOT NULL,
    preco_unitario  DECIMAL(10,2) NOT NULL,
    observacao      NVARCHAR(100) NULL,
    CONSTRAINT pk_item_comanda      PRIMARY KEY (id_item),
    CONSTRAINT fk_item_comanda      FOREIGN KEY (id_comanda)
        REFERENCES comanda (id_comanda) ON DELETE CASCADE,
    CONSTRAINT fk_item_produto      FOREIGN KEY (id_produto)
        REFERENCES produto (id_produto),
    CONSTRAINT uq_item_comanda_prod UNIQUE (id_comanda, id_produto),
    CONSTRAINT ck_item_qtd          CHECK (quantidade > 0),
    CONSTRAINT ck_item_preco        CHECK (preco_unitario > 0)
);

CREATE TABLE entrega (
    id_entrega      INT IDENTITY(1,1) NOT NULL,
    id_comanda      INT           NOT NULL,
    id_endereco     INT           NOT NULL,
    id_funcionario  INT           NOT NULL,
    taxa_entrega    DECIMAL(10,2) NOT NULL,
    data_saida      DATETIME2(0)  NULL,
    data_entrega    DATETIME2(0)  NULL,
    CONSTRAINT pk_entrega             PRIMARY KEY (id_entrega),
    CONSTRAINT uq_entrega_comanda     UNIQUE (id_comanda),
    CONSTRAINT fk_entrega_comanda     FOREIGN KEY (id_comanda)
        REFERENCES comanda (id_comanda),
    CONSTRAINT fk_entrega_endereco    FOREIGN KEY (id_endereco)
        REFERENCES endereco (id_endereco),
    CONSTRAINT fk_entrega_funcionario FOREIGN KEY (id_funcionario)
        REFERENCES funcionario (id_funcionario),
    CONSTRAINT ck_entrega_taxa        CHECK (taxa_entrega >= 0),
    CONSTRAINT ck_entrega_datas
        CHECK (data_entrega IS NULL OR data_entrega >= data_saida)
);

CREATE TABLE pagamento (
    id_pagamento    INT IDENTITY(1,1) NOT NULL,
    id_comanda      INT           NOT NULL,
    id_forma        INT           NOT NULL,
    valor           DECIMAL(10,2) NOT NULL,
    data_pagamento  DATETIME2(0)  NOT NULL
        CONSTRAINT df_pagamento_data DEFAULT SYSDATETIME(),
    CONSTRAINT pk_pagamento         PRIMARY KEY (id_pagamento),
    CONSTRAINT fk_pagamento_comanda FOREIGN KEY (id_comanda)
        REFERENCES comanda (id_comanda),
    CONSTRAINT fk_pagamento_forma   FOREIGN KEY (id_forma)
        REFERENCES forma_pagamento (id_forma),
    CONSTRAINT ck_pagamento_valor   CHECK (valor > 0)
);

CREATE TABLE avaliacao (
    id_avaliacao      INT IDENTITY(1,1) NOT NULL,
    id_comanda        INT           NOT NULL,
    nota_comida       TINYINT       NOT NULL,
    nota_atendimento  TINYINT       NOT NULL,
    comentario        NVARCHAR(200) NULL,
    data_avaliacao    DATETIME2(0)  NOT NULL,
    CONSTRAINT pk_avaliacao         PRIMARY KEY (id_avaliacao),
    CONSTRAINT uq_avaliacao_comanda UNIQUE (id_comanda),
    CONSTRAINT fk_avaliacao_comanda FOREIGN KEY (id_comanda)
        REFERENCES comanda (id_comanda),
    CONSTRAINT ck_avaliacao_notas
        CHECK (nota_comida BETWEEN 1 AND 5
           AND nota_atendimento BETWEEN 1 AND 5)
);

/* ---------- Estoque e compras ---------- */

CREATE TABLE fornecedor (
    id_fornecedor  INT IDENTITY(1,1) NOT NULL,
    id_cidade      INT           NOT NULL,
    razao_social   NVARCHAR(100) NOT NULL,
    cnpj           CHAR(14)      NOT NULL,
    telefone       VARCHAR(11)   NOT NULL,
    email          VARCHAR(100)  NULL,
    CONSTRAINT pk_fornecedor        PRIMARY KEY (id_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj   UNIQUE (cnpj),
    CONSTRAINT fk_fornecedor_cidade FOREIGN KEY (id_cidade)
        REFERENCES cidade (id_cidade)
);

CREATE TABLE insumo (
    id_insumo       INT IDENTITY(1,1) NOT NULL,
    id_fornecedor   INT           NOT NULL,
    id_unidade      INT           NOT NULL,
    nome            NVARCHAR(60)  NOT NULL,
    estoque_atual   DECIMAL(10,3) NOT NULL
        CONSTRAINT df_insumo_estoque DEFAULT 0,
    estoque_minimo  DECIMAL(10,3) NOT NULL
        CONSTRAINT df_insumo_minimo DEFAULT 0,
    custo_unitario  DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_insumo            PRIMARY KEY (id_insumo),
    CONSTRAINT uq_insumo_nome       UNIQUE (nome),
    CONSTRAINT fk_insumo_fornecedor FOREIGN KEY (id_fornecedor)
        REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT fk_insumo_unidade    FOREIGN KEY (id_unidade)
        REFERENCES unidade_medida (id_unidade),
    CONSTRAINT ck_insumo_estoque    CHECK (estoque_atual >= 0),
    CONSTRAINT ck_insumo_custo      CHECK (custo_unitario > 0)
);

CREATE TABLE ficha_tecnica (
    id_produto  INT           NOT NULL,
    id_insumo   INT           NOT NULL,
    quantidade  DECIMAL(10,3) NOT NULL,
    CONSTRAINT pk_ficha_tecnica PRIMARY KEY (id_produto, id_insumo),
    CONSTRAINT fk_ficha_produto FOREIGN KEY (id_produto)
        REFERENCES produto (id_produto),
    CONSTRAINT fk_ficha_insumo  FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_ficha_qtd     CHECK (quantidade > 0)
);

CREATE TABLE compra (
    id_compra      INT IDENTITY(1,1) NOT NULL,
    id_fornecedor  INT           NOT NULL,
    numero_nf      VARCHAR(20)   NOT NULL,
    data_compra    DATE          NOT NULL,
    observacao     NVARCHAR(100) NULL,
    CONSTRAINT pk_compra            PRIMARY KEY (id_compra),
    CONSTRAINT fk_compra_fornecedor FOREIGN KEY (id_fornecedor)
        REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT uq_compra_nf         UNIQUE (id_fornecedor, numero_nf)
);

CREATE TABLE item_compra (
    id_compra       INT           NOT NULL,
    id_insumo       INT           NOT NULL,
    quantidade      DECIMAL(10,3) NOT NULL,
    custo_unitario  DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_item_compra        PRIMARY KEY (id_compra, id_insumo),
    CONSTRAINT fk_item_compra_compra FOREIGN KEY (id_compra)
        REFERENCES compra (id_compra) ON DELETE CASCADE,
    CONSTRAINT fk_item_compra_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_item_compra_qtd    CHECK (quantidade > 0),
    CONSTRAINT ck_item_compra_custo  CHECK (custo_unitario > 0)
);

CREATE TABLE movimentacao_estoque (
    id_movimentacao    INT IDENTITY(1,1) NOT NULL,
    id_insumo          INT           NOT NULL,
    tipo               NVARCHAR(7)   NOT NULL,
    quantidade         DECIMAL(10,3) NOT NULL,
    data_movimentacao  DATETIME2(0)  NOT NULL
        CONSTRAINT df_mov_data DEFAULT SYSDATETIME(),
    origem             NVARCHAR(60)  NOT NULL,
    CONSTRAINT pk_movimentacao_estoque PRIMARY KEY (id_movimentacao),
    CONSTRAINT fk_mov_insumo  FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_mov_tipo_qtd
        CHECK ((tipo = N'Entrada' AND quantidade > 0)
            OR (tipo = N'Saída'   AND quantidade < 0)
            OR (tipo = N'Ajuste'  AND quantidade <> 0))
);

/* ---------- Índices ---------- */

-- Índice único filtrado: uma reserva origina no máximo uma comanda,
-- permitindo várias comandas sem reserva (id_reserva NULL)
CREATE UNIQUE INDEX uq_comanda_reserva ON comanda (id_reserva)
    WHERE id_reserva IS NOT NULL;
CREATE INDEX ix_comanda_abertura ON comanda (data_abertura);
CREATE INDEX ix_comanda_cliente  ON comanda (id_cliente);
CREATE INDEX ix_item_produto     ON item_comanda (id_produto);
CREATE INDEX ix_pagamento_comanda ON pagamento (id_comanda);
CREATE INDEX ix_mov_insumo_data  ON movimentacao_estoque (id_insumo,
                                                           data_movimentacao);
CREATE INDEX ix_reserva_data     ON reserva (data_hora);
GO
