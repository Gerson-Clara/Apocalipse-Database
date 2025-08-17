DROP DATABASE IF EXISTS Apocalipse;
CREATE DATABASE Apocalipse;
USE Apocalipse;

-- TABELAS
CREATE TABLE IF NOT EXISTS Instalacao (
  cod_instalacao INT AUTO_INCREMENT PRIMARY KEY,
  funcao VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Casa (
  cod_instalacao INT PRIMARY KEY,
  num INT NOT NULL UNIQUE,
  cap_max INT,
  num_sobreviventes INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_casa_instalacao FOREIGN KEY (cod_instalacao)
    REFERENCES Instalacao(cod_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Fazenda (
  cod_instalacao INT PRIMARY KEY,
  num_animais INT NOT NULL DEFAULT 0,
  cultivo VARCHAR(255),
  num_trabalhadores INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_fazenda_instalacao FOREIGN KEY (cod_instalacao)
    REFERENCES Instalacao(cod_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Clinica (
  cod_instalacao INT PRIMARY KEY,
  num_trabalhadores INT NOT NULL DEFAULT 0,
  num_pacientes INT NOT NULL DEFAULT 0,
  qtd_remedios INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_clinica_instalacao FOREIGN KEY (cod_instalacao)
    REFERENCES Instalacao(cod_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Armazem (
  cod_instalacao INT PRIMARY KEY,
  kg_comida DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  ltr_agua DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  qtd_armas INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_armazem_instalacao FOREIGN KEY (cod_instalacao)
    REFERENCES Instalacao(cod_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Arma (
  cod_arma INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(100),
  qtd_municao INT NOT NULL DEFAULT 0,
  disponibilidade ENUM('disponivel','indisponivel') NOT NULL DEFAULT 'disponivel',
  id_armazem INT NOT NULL,
  INDEX idx_arma_armazem (id_armazem),
  CONSTRAINT fk_arma_armazem FOREIGN KEY (id_armazem)
    REFERENCES Armazem(cod_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Comida (
  cod_comida INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(100),
  peso DECIMAL(10,3) NOT NULL,
  data_validade DATE,
  id_armazem INT NOT NULL,
  INDEX idx_comida_armazem (id_armazem),
  CONSTRAINT fk_comida_armazem FOREIGN KEY (id_armazem)
    REFERENCES Armazem(cod_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Remedio (
  cod_remedio INT AUTO_INCREMENT PRIMARY KEY,
  utilidade VARCHAR(255),
  data_validade DATE,
  id_clinica INT NOT NULL,
  INDEX idx_remedio_clinica (id_clinica),
  CONSTRAINT fk_remedio_clinica FOREIGN KEY (id_clinica)
    REFERENCES Clinica(cod_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Sobrevivente (
  id_sobrevivente INT AUTO_INCREMENT PRIMARY KEY,
  idade INT NOT NULL,
  saude ENUM('saudavel','doente','incapacitado') NOT NULL DEFAULT 'saudavel',
  num_casa INT NOT NULL,
  INDEX idx_sobrevivente_casa (num_casa),
  CONSTRAINT fk_sobrevivente_casa FOREIGN KEY (num_casa)
    REFERENCES Casa(num) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Trabalhador (
  id_sobrevivente INT PRIMARY KEY,
  local_trabalho INT NULL,
  INDEX idx_trabalhador_local (local_trabalho),
  CONSTRAINT fk_trabalhador_sobrevivente FOREIGN KEY (id_sobrevivente)
    REFERENCES Sobrevivente(id_sobrevivente) ON DELETE CASCADE,
  CONSTRAINT fk_trabalhador_instalacao FOREIGN KEY (local_trabalho)
    REFERENCES Instalacao(cod_instalacao) ON DELETE SET NULL
) ENGINE=InnoDB;


-- TRIGGERS
DELIMITER $$

/* Atualiza contador depois de inserir sobrevivente */
CREATE TRIGGER AI_Sobrevivente_Casa
AFTER INSERT ON Sobrevivente
FOR EACH ROW
BEGIN
  DECLARE v_cod_clinica INT;

  UPDATE Casa
    SET num_sobreviventes = (
      SELECT COUNT(*) FROM Sobrevivente WHERE num_casa = NEW.num_casa
    )
  WHERE num = NEW.num_casa;

  IF NEW.saude = 'doente' THEN
    SELECT cod_instalacao INTO v_cod_clinica FROM Clinica ORDER BY RAND() LIMIT 1;
    IF v_cod_clinica IS NOT NULL THEN
      UPDATE Clinica
        SET num_pacientes = num_pacientes + 1
      WHERE cod_instalacao = v_cod_clinica;
    END IF;
  END IF;
END$$

/* Atualiza contador depois de deletar sobrevivente */
CREATE TRIGGER AD_Sobrevivente_Casa
AFTER DELETE ON Sobrevivente
FOR EACH ROW
BEGIN
  UPDATE Casa
    SET num_sobreviventes = (
      SELECT COUNT(*) FROM Sobrevivente WHERE num_casa = OLD.num_casa
    )
  WHERE num = OLD.num_casa;
END$$

/* Atualiza contadores quando sobrevivente muda de casa (recalcula ambas) */
CREATE TRIGGER AU_Sobrevivente_Casa
AFTER UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  IF OLD.num_casa <> NEW.num_casa THEN
    UPDATE Casa
      SET num_sobreviventes = (
        SELECT COUNT(*) FROM Sobrevivente WHERE num_casa = OLD.num_casa
      )
    WHERE num = OLD.num_casa;

    UPDATE Casa
      SET num_sobreviventes = (
        SELECT COUNT(*) FROM Sobrevivente WHERE num_casa = NEW.num_casa
      )
    WHERE num = NEW.num_casa;
  END IF;
END$$

/* impede inserir se casa não existe ou se atingiu cap_max */
CREATE TRIGGER BI_Sobrevivente_VerificaCapacidade
BEFORE INSERT ON Sobrevivente
FOR EACH ROW
BEGIN
  DECLARE v_num_sobreviventes INT DEFAULT 0;
  DECLARE v_cap_max INT DEFAULT NULL;
  DECLARE v_exists INT DEFAULT 0;

  SELECT COUNT(*) INTO v_exists FROM Casa WHERE num = NEW.num_casa;
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insercao negada: casa nao encontrada';
  END IF;

  SELECT num_sobreviventes, cap_max
    INTO v_num_sobreviventes, v_cap_max
    FROM Casa
    WHERE num = NEW.num_casa
    FOR UPDATE;

  IF v_cap_max IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insercao negada: cap_max nulo na casa';
  END IF;

  IF v_num_sobreviventes >= v_cap_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insercao negada: casa ja atingiu capacidade maxima';
  END IF;
END$$

/* Impede mover sobrevivente para casa cheia */
CREATE TRIGGER BU_Sobrevivente_VerificaCapacidade
BEFORE UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  DECLARE v_num_sobreviventes INT DEFAULT 0;
  DECLARE v_cap_max INT DEFAULT NULL;
  DECLARE v_exists INT DEFAULT 0;

  IF OLD.num_casa <> NEW.num_casa THEN
    SELECT COUNT(*) INTO v_exists FROM Casa WHERE num = NEW.num_casa;
    IF v_exists = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimentacao negada: casa destino nao encontrada';
    END IF;

    SELECT num_sobreviventes, cap_max
      INTO v_num_sobreviventes, v_cap_max
      FROM Casa
      WHERE num = NEW.num_casa
      FOR UPDATE;

    IF v_cap_max IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimentacao negada: cap_max nulo na casa destino';
    END IF;

    IF v_num_sobreviventes >= v_cap_max THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimentacao negada: casa destino cheia';
    END IF;
  END IF;
END$$

/* Atualiza contagem de pacientes em clinica quando muda saude */
CREATE TRIGGER AU_Sobrevivente_Clinica
AFTER UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  DECLARE v_cod_inc INT;
  DECLARE v_cod_dec INT;

  -- saudavel -> doente : incrementa numa clinica aleatoria
  IF OLD.saude = 'saudavel' AND NEW.saude = 'doente' THEN
    SELECT cod_instalacao INTO v_cod_inc FROM Clinica ORDER BY RAND() LIMIT 1;
    IF v_cod_inc IS NOT NULL THEN
      UPDATE Clinica
        SET num_pacientes = num_pacientes + 1
      WHERE cod_instalacao = v_cod_inc;
    END IF;
  END IF;

  -- doente -> saudavel : decrementa (entre clinicas com >0 pacientes) sem ficar negativo
  IF OLD.saude = 'doente' AND NEW.saude = 'saudavel' THEN
    SELECT cod_instalacao INTO v_cod_dec FROM Clinica
      WHERE num_pacientes > 0
      ORDER BY RAND()
      LIMIT 1;
    IF v_cod_dec IS NOT NULL THEN
      UPDATE Clinica
        SET num_pacientes = GREATEST(num_pacientes - 1, 0)
      WHERE cod_instalacao = v_cod_dec;
    END IF;
  END IF;
END$$

/* Se sobrevivente for >=15, cria registro em Trabalhador (se não existir) */
CREATE TRIGGER AI_Sobrevivente_Trabalhador
AFTER INSERT ON Sobrevivente
FOR EACH ROW
BEGIN
  IF NEW.idade >= 15 THEN
    IF (SELECT COUNT(*) FROM Trabalhador WHERE id_sobrevivente = NEW.id_sobrevivente) = 0 THEN
      INSERT INTO Trabalhador (id_sobrevivente, local_trabalho)
        VALUES (NEW.id_sobrevivente, NULL);
    END IF;
  END IF;
END$$

/* Se sobrevivente virar >=15, cria registro em Trabalhador (se não existir) */
CREATE TRIGGER AU_Sobrevivente_Trabalhador
AFTER UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  IF OLD.idade < 15 AND NEW.idade >= 15 THEN
    IF (SELECT COUNT(*) FROM Trabalhador WHERE id_sobrevivente = NEW.id_sobrevivente) = 0 THEN
      INSERT INTO Trabalhador (id_sobrevivente, local_trabalho)
        VALUES (NEW.id_sobrevivente, NULL);
    END IF;
  END IF;
END$$

/* Atualiza num_trabalhadores em Fazenda/Clinica quando Trabalhador inserido */
CREATE TRIGGER AI_Trabalhador_FazendaClinica
AFTER INSERT ON Trabalhador
FOR EACH ROW
BEGIN
  IF NEW.local_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE cod_instalacao = NEW.local_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = NEW.local_trabalho
        )
      WHERE cod_instalacao = NEW.local_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE cod_instalacao = NEW.local_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = NEW.local_trabalho
        )
      WHERE cod_instalacao = NEW.local_trabalho;
    END IF;
  END IF;
END$$

/* Atualiza num_trabalhadores em Fazenda/Clinica quando Trabalhador deletado */
CREATE TRIGGER AD_Trabalhador_FazendaClinica
AFTER DELETE ON Trabalhador
FOR EACH ROW
BEGIN
  IF OLD.local_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE cod_instalacao = OLD.local_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = OLD.local_trabalho
        )
      WHERE cod_instalacao = OLD.local_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE cod_instalacao = OLD.local_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = OLD.local_trabalho
        )
      WHERE cod_instalacao = OLD.local_trabalho;
    END IF;
  END IF;
END$$

/* Atualiza num_trabalhadores em Fazenda/Clinica quando Trabalhador for atualizado */
CREATE TRIGGER AU_Trabalhador_FazendaClinica
AFTER UPDATE ON Trabalhador
FOR EACH ROW
BEGIN
  IF OLD.local_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE cod_instalacao = OLD.local_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = OLD.local_trabalho
        )
      WHERE cod_instalacao = OLD.local_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE cod_instalacao = OLD.local_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = OLD.local_trabalho
        )
      WHERE cod_instalacao = OLD.local_trabalho;
    END IF;
  END IF;

  IF NEW.local_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE cod_instalacao = NEW.local_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = NEW.local_trabalho
        )
      WHERE cod_instalacao = NEW.local_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE cod_instalacao = NEW.local_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE local_trabalho = NEW.local_trabalho
        )
      WHERE cod_instalacao = NEW.local_trabalho;
    END IF;
  END IF;
END$$

/* Atualiza qtd_remedios na clinica */
CREATE TRIGGER AI_Remedio_Clinica
AFTER INSERT ON Remedio
FOR EACH ROW
BEGIN
  UPDATE Clinica
    SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
  WHERE cod_instalacao = NEW.id_clinica;
END$$

CREATE TRIGGER AD_Remedio_Clinica
AFTER DELETE ON Remedio
FOR EACH ROW
BEGIN
  UPDATE Clinica
    SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = OLD.id_clinica)
  WHERE cod_instalacao = OLD.id_clinica;
END$$

CREATE TRIGGER AU_Remedio_Clinica
AFTER UPDATE ON Remedio
FOR EACH ROW
BEGIN
  IF OLD.id_clinica <> NEW.id_clinica THEN
    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = OLD.id_clinica)
    WHERE cod_instalacao = OLD.id_clinica;

    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
    WHERE cod_instalacao = NEW.id_clinica;
  ELSE
    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
    WHERE cod_instalacao = NEW.id_clinica;
  END IF;
END$$

/* Atualiza qtd_armas no armazem */
CREATE TRIGGER AI_Arma_Armazem
AFTER INSERT ON Arma
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
  WHERE cod_instalacao = NEW.id_armazem;
END$$

CREATE TRIGGER AD_Arma_Armazem
AFTER DELETE ON Arma
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = OLD.id_armazem)
  WHERE cod_instalacao = OLD.id_armazem;
END$$

CREATE TRIGGER AU_Arma_Armazem
AFTER UPDATE ON Arma
FOR EACH ROW
BEGIN
  IF OLD.id_armazem <> NEW.id_armazem THEN
    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = OLD.id_armazem)
    WHERE cod_instalacao = OLD.id_armazem;

    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
    WHERE cod_instalacao = NEW.id_armazem;
  ELSE
    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
    WHERE cod_instalacao = NEW.id_armazem;
  END IF;
END$$

/* Atualiza kg_comida no armazem */
CREATE TRIGGER AI_Comida_Armazem
AFTER INSERT ON Comida
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET kg_comida = (
      SELECT IFNULL(SUM(peso), 0) FROM Comida WHERE id_armazem = NEW.id_armazem
    )
  WHERE cod_instalacao = NEW.id_armazem;
END$$

CREATE TRIGGER AD_Comida_Armazem
AFTER DELETE ON Comida
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET kg_comida = (
      SELECT IFNULL(SUM(peso), 0) FROM Comida WHERE id_armazem = OLD.id_armazem
    )
  WHERE cod_instalacao = OLD.id_armazem;
END$$

CREATE TRIGGER AU_Comida_Armazem
AFTER UPDATE ON Comida
FOR EACH ROW
BEGIN
  IF OLD.id_armazem <> NEW.id_armazem THEN
    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = OLD.id_armazem)
    WHERE cod_instalacao = OLD.id_armazem;

    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = NEW.id_armazem)
    WHERE cod_instalacao = NEW.id_armazem;
  ELSE
    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = NEW.id_armazem)
    WHERE cod_instalacao = NEW.id_armazem;
  END IF;
END$$

DELIMITER ;

-- INSTALACOES
INSERT INTO Instalacao (cod_instalacao, funcao) VALUES
(1,'Fazenda'),
(2,'Fazenda'),
(3,'Fazenda'),
(4,'Clinica'),
(5,'Clinica'),
(6,'Armazem'),
(7,'Armazem'),
(8,'Casa'),
(9,'Casa'),
(10,'Casa'),
(11,'Casa'),
(12,'Casa'),
(13,'Casa'),
(14,'Casa'),
(15,'Casa'),
(16,'Casa'),
(17,'Casa'),
(18,'Casa');

INSERT INTO Fazenda (cod_instalacao, num_animais, cultivo, num_trabalhadores) VALUES
(1,50,'milho',0),
(2,120,'soja',0),
(3,30,'hortaliças',0);

INSERT INTO Clinica (cod_instalacao, num_trabalhadores, num_pacientes, qtd_remedios) VALUES
(4,0,0,0),
(5,0,0,0);

INSERT INTO Armazem (cod_instalacao, kg_comida, ltr_agua, qtd_armas) VALUES
(6,0.000,0.000,0),
(7,0.000,0.000,0);

INSERT INTO Casa (cod_instalacao, num, cap_max, num_sobreviventes) VALUES
(8,101,4,0),
(9,102,8,0),
(10,103,5,0),
(11,104,7,0),
(12,105,4,0),
(13,106,5,0),
(14,107,10,0),
(15,108,3,0),
(16,109,6,0),
(17,110,10,0),
(18,111,7,0);

-- SOBREVIVENTES:
INSERT INTO Sobrevivente (id_sobrevivente, idade, saude, num_casa) VALUES
(1, 12,'saudavel',101),
(2, 45,'saudavel',102),
(3, 70,'incapacitado',103),
(4, 30,'saudavel',101),
(5, 25,'saudavel',101),
(6, 40,'doente',102),
(7, 50,'saudavel',102),
(8, 60,'saudavel',102),
(9, 20,'saudavel',103),
(10, 35,'doente',103),
(11, 22,'saudavel',103),
(12, 67,'incapacitado',103),
(13, 15,'saudavel',104),
(14, 18,'saudavel',104),
(15, 28,'doente',104),
(16, 32,'saudavel',104),
(17, 55,'saudavel',104),
(18, 40,'saudavel',104),
(19, 10,'saudavel',105),
(20, 20,'incapacitado',105),
(21, 30,'saudavel',105),
(22, 25,'saudavel',105),
(23, 14,'saudavel',106),
(24, 19,'doente',106),
(25, 21,'saudavel',106),
(26, 23,'saudavel',106),
(27, 29,'saudavel',106),
(28, 33,'saudavel',102),
(29, 78,'incapacitado',102),
(30, 16,'saudavel',107),
(31, 20,'doente',107),
(32, 24,'saudavel',107),
(33, 26,'saudavel',107),
(34, 31,'saudavel',107),
(35, 36,'saudavel',107),
(36, 11,'saudavel',107),
(37, 13,'doente',108),
(38, 17,'saudavel',108),
(39, 22,'saudavel',108),
(40, 27,'saudavel',111),
(41, 34,'saudavel',111),
(42, 38,'doente',111),
(43, 41,'saudavel',111),
(44, 46,'saudavel',111),
(45, 65,'incapacitado',111);

-- TRABALHADORES
UPDATE Trabalhador SET local_trabalho = 1 WHERE id_sobrevivente = 2;
UPDATE Trabalhador SET local_trabalho = 1 WHERE id_sobrevivente = 4;
UPDATE Trabalhador SET local_trabalho = 1 WHERE id_sobrevivente = 5;
UPDATE Trabalhador SET local_trabalho = 2 WHERE id_sobrevivente = 6;
UPDATE Trabalhador SET local_trabalho = 2 WHERE id_sobrevivente = 7;
UPDATE Trabalhador SET local_trabalho = 2 WHERE id_sobrevivente = 9;
UPDATE Trabalhador SET local_trabalho = 3 WHERE id_sobrevivente = 10;
UPDATE Trabalhador SET local_trabalho = 3 WHERE id_sobrevivente = 11;
UPDATE Trabalhador SET local_trabalho = 3 WHERE id_sobrevivente = 14;
UPDATE Trabalhador SET local_trabalho = 4 WHERE id_sobrevivente = 15;
UPDATE Trabalhador SET local_trabalho = 4 WHERE id_sobrevivente = 16;
UPDATE Trabalhador SET local_trabalho = 4 WHERE id_sobrevivente = 17;
UPDATE Trabalhador SET local_trabalho = 5 WHERE id_sobrevivente = 18;
UPDATE Trabalhador SET local_trabalho = 5 WHERE id_sobrevivente = 21;
UPDATE Trabalhador SET local_trabalho = 5 WHERE id_sobrevivente = 22;
UPDATE Trabalhador SET local_trabalho = 6 WHERE id_sobrevivente = 24;
UPDATE Trabalhador SET local_trabalho = 6 WHERE id_sobrevivente = 25;
UPDATE Trabalhador SET local_trabalho = 6 WHERE id_sobrevivente = 26;
UPDATE Trabalhador SET local_trabalho = 7 WHERE id_sobrevivente = 27;
UPDATE Trabalhador SET local_trabalho = 7 WHERE id_sobrevivente = 28;
UPDATE Trabalhador SET local_trabalho = 7 WHERE id_sobrevivente = 32;
UPDATE Trabalhador SET local_trabalho = 1 WHERE id_sobrevivente = 33;
UPDATE Trabalhador SET local_trabalho = 2 WHERE id_sobrevivente = 34;
UPDATE Trabalhador SET local_trabalho = 3 WHERE id_sobrevivente = 35;
UPDATE Trabalhador SET local_trabalho = 4 WHERE id_sobrevivente = 38;
UPDATE Trabalhador SET local_trabalho = 5 WHERE id_sobrevivente = 39;
UPDATE Trabalhador SET local_trabalho = 6 WHERE id_sobrevivente = 40;
UPDATE Trabalhador SET local_trabalho = 7 WHERE id_sobrevivente = 41;
UPDATE Trabalhador SET local_trabalho = 1 WHERE id_sobrevivente = 43;
UPDATE Trabalhador SET local_trabalho = 2 WHERE id_sobrevivente = 44;

-- ARMAS
INSERT INTO Arma (tipo, qtd_municao, disponibilidade, id_armazem) VALUES
('pistola',15,'disponivel',6),
('rifle',30,'disponivel',6),
('espingarda',8,'disponivel',6),
('pistola',12,'disponivel',6),
('submetralhadora',200,'disponivel',6),
('revólver',6,'disponivel',6),
('fuzil',90,'disponivel',6),
('pistola',10,'disponivel',6),
('metralhadora',500,'indisponivel',6),
('pistola',14,'disponivel',7),
('rifle',25,'disponivel',7),
('espingarda',6,'disponivel',7),
('revólver',8,'disponivel',7),
('submetralhadora',150,'disponivel',7),
('fuzil',80,'disponivel',7),
('pistola',9,'disponivel',7),
('rifle',40,'indisponivel',7);

-- REMEDIOS
INSERT INTO Remedio (utilidade, data_validade, id_clinica) VALUES
('analgesico','2026-12-31',4),
('antibiotico','2025-11-30',4),
('antitermico','2024-06-30',4),
('antiinflamatorio','2026-05-20',4),
('antialergico','2023-01-01',4),
('vitaminico','2026-09-15',4),
('antibiotico','2026-10-10',4),
('analgesico','2024-08-01',4),
('antitussigeno','2025-03-20',4),
('antiparasitario','2027-01-01',4),
('antiespasmodico','2026-12-31',4),
('anticoagulante','2026-12-31',4),
('suero','2025-12-31',4),
('antiemetico','2026-04-01',4),
('antibiotico','2023-01-01',4),
('analgesico','2026-07-07',4),
('antiflamatorio_local','2025-02-20',4),
('ansiolitico','2026-03-03',4),
('cardiologico','2025-09-09',4),
('dermatologico','2026-11-11',4),
('oftalmico','2026-06-06',4),
('otologico','2025-05-05',4),
('gastro','2026-10-10',4),
('respiratorio','2024-12-12',4),
('hormonal','2026-02-02',4),
('analgesico','2026-08-08',4),
('antibiotico','2026-12-12',4),
('vacina','2025-07-07',4),
('desinfetante','2026-01-01',4),
('hemostatico','2026-03-03',4),
('antivirico','2026-09-09',4),
('imunoestimulante','2027-05-05',4),
('suero','2024-01-01',4),
('antifungico','2026-11-11',4),
('analgesico','2026-12-31',5),
('antibiotico','2025-11-30',5),
('antitermico','2024-06-30',5),
('antiinflamatorio','2026-05-20',5),
('antialergico','2023-01-01',5),
('vitaminico','2026-09-15',5),
('antibiotico','2026-10-10',5),
('analgesico','2024-08-01',5),
('antitussigeno','2025-03-20',5),
('antiparasitario','2027-01-01',5),
('antiespasmodico','2026-12-31',5),
('anticoagulante','2026-12-31',5),
('suero','2025-12-31',5),
('antiemetico','2026-04-01',5),
('antibiotico','2023-01-01',5),
('analgesico','2026-07-07',5),
('antiflamatorio_local','2025-02-20',5),
('ansiolitico','2026-03-03',5),
('cardiologico','2025-09-09',5),
('dermatologico','2026-11-11',5),
('oftalmico','2026-06-06',5),
('otologico','2025-05-05',5),
('gastro','2026-10-10',5),
('respiratorio','2024-12-12',5),
('hormonal','2026-02-02',5),
('analgesico','2026-08-08',5),
('antibiotico','2026-12-12',5),
('vacina','2025-07-07',5),
('desinfetante','2026-01-01',5),
('hemostatico','2026-03-03',5),
('antivirico','2026-09-09',5),
('imunoestimulante','2027-05-05',5),
('suero','2024-01-01',5),
('antifungico','2026-11-11',5);

SELECT * FROM casa;

-- (1) Listar todas as casas com sua capacidade e sobreviventes
SELECT num AS Numero_Casa, cap_max AS Capacidade, num_sobreviventes AS Ocupacao
FROM casa;

-- (2) Mostrar sobreviventes e sua casa
SELECT s.id_sobrevivente, s.idade, s.saude, c.num AS Casa
FROM Sobrevivente s
JOIN Casa c ON s.num_casa = c.num;

-- (3) Listar trabalhadores e onde trabalham
SELECT s.id_sobrevivente, s.idade, i.funcao AS Local_Trabalho
FROM Sobrevivente s
JOIN Trabalhador t ON s.id_sobrevivente = t.id_sobrevivente
JOIN Instalacao i ON t.local_trabalho = i.cod_instalacao;

-- (4) Listar armas e o armazém onde estão
SELECT a.tipo, a.qtd_municao, ar.cod_instalacao AS Armazem
FROM Arma a
JOIN Armazem ar ON a.id_armazem = ar.cod_instalacao;

-- (5) Listar remédios e a clínica onde estão
SELECT r.utilidade, r.data_validade, c.qtd_remedios, c.cod_instalacao
FROM Remedio r
JOIN Clinica c ON r.id_clinica = c.cod_instalacao;

-- (6) Quantos sobreviventes há por casa
SELECT c.num, COUNT(s.id_sobrevivente) AS Total_Sobreviventes
FROM Casa c
LEFT JOIN Sobrevivente s ON c.num = s.num_casa
GROUP BY c.num;

-- EXTRA (7) Listar o que tem em um armazém e clínica (armas + comida + remédios)
SELECT i.funcao, a.tipo AS Arma, a.qtd_municao, ar.kg_comida, r.utilidade AS Remedio, r.data_validade
FROM Instalacao i
LEFT JOIN Armazem ar ON i.cod_instalacao = ar.cod_instalacao
LEFT JOIN Arma a ON a.id_armazem = ar.cod_instalacao
LEFT JOIN Clinica cl ON i.cod_instalacao = cl.cod_instalacao
LEFT JOIN Remedio r ON r.id_clinica = cl.cod_instalacao
WHERE i.cod_instalacao IN (4,5,6,7);
