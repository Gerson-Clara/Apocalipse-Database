-- TABELAS

CREATE TABLE IF NOT EXISTS Instalacao (
  id_instalacao INT AUTO_INCREMENT PRIMARY KEY,
  funcao VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Casa (
  id_instalacao INT PRIMARY KEY,
  num INT NOT NULL UNIQUE,
  cap_max INT,
  num_sobreviventes INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_casa_instalacao FOREIGN KEY (id_instalacao)
    REFERENCES Instalacao(id_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Fazenda (
  id_instalacao INT PRIMARY KEY,
  num_animais INT NOT NULL DEFAULT 0,
  cultivo VARCHAR(255),
  num_trabalhadores INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_fazenda_instalacao FOREIGN KEY (id_instalacao)
    REFERENCES Instalacao(id_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Clinica (
  id_instalacao INT PRIMARY KEY,
  num_trabalhadores INT NOT NULL DEFAULT 0,
  num_paciente INT NOT NULL DEFAULT 0,
  qtd_remedios INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_clinica_instalacao FOREIGN KEY (id_instalacao)
    REFERENCES Instalacao(id_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Armazem (
  id_instalacao INT PRIMARY KEY,
  kg_comida DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  ltr_agua DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  qtd_armas INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_armazem_instalacao FOREIGN KEY (id_instalacao)
    REFERENCES Instalacao(id_instalacao) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Arma (
  cod_arma INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(100),
  qtd_municao INT NOT NULL DEFAULT 0,
  disponibilidade ENUM('disponivel','indisponivel') NOT NULL DEFAULT 'disponivel',
  id_armazem INT NOT NULL,
  INDEX idx_arma_armazem (id_armazem),
  CONSTRAINT fk_arma_armazem FOREIGN KEY (id_armazem)
    REFERENCES Armazem(id_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Comida (
  cod_comida INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(100),
  peso DECIMAL(10,3) NOT NULL,
  data_validade DATE,
  id_armazem INT NOT NULL,
  INDEX idx_comida_armazem (id_armazem),
  CONSTRAINT fk_comida_armazem FOREIGN KEY (id_armazem)
    REFERENCES Armazem(id_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Remedio (
  cod_remedio INT AUTO_INCREMENT PRIMARY KEY,
  utilidade VARCHAR(255),
  data_validade DATE,
  id_clinica INT NOT NULL,
  INDEX idx_remedio_clinica (id_clinica),
  CONSTRAINT fk_remedio_clinica FOREIGN KEY (id_clinica)
    REFERENCES Clinica(id_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Sobrevivente (
  id_sobrevivente INT AUTO_INCREMENT PRIMARY KEY,
  idade INT NOT NULL,
  saude ENUM('saudável','incapacitado') NOT NULL DEFAULT 'saudável',
  id_casa INT NOT NULL,
  INDEX idx_sobrevivente_casa (id_casa),
  CONSTRAINT fk_sobrevivente_casa FOREIGN KEY (id_casa)
    REFERENCES Casa(id_instalacao) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Trabalhador (
  id_sobrevivente INT PRIMARY KEY,
  id_instalacao_trabalho INT NULL,
  INDEX idx_trabalhador_local (id_instalacao_trabalho),
  CONSTRAINT fk_trabalhador_sobrevivente FOREIGN KEY (id_sobrevivente)
    REFERENCES Sobrevivente(id_sobrevivente) ON DELETE CASCADE,
  CONSTRAINT fk_trabalhador_instalacao FOREIGN KEY (id_instalacao_trabalho)
    REFERENCES Instalacao(id_instalacao) ON DELETE SET NULL
) ENGINE=InnoDB;


-- TRIGGERS
DELIMITER $$

CREATE TRIGGER AI_Sobrevivente_Casa
AFTER INSERT ON Sobrevivente
FOR EACH ROW
BEGIN
  UPDATE Casa
    SET num_sobreviventes = (
      SELECT COUNT(*) FROM Sobrevivente WHERE id_casa = NEW.id_casa
    )
  WHERE id_instalacao = NEW.id_casa;
END$$

CREATE TRIGGER AD_Sobrevivente_Casa
AFTER DELETE ON Sobrevivente
FOR EACH ROW
BEGIN
  UPDATE Casa
    SET num_sobreviventes = (
      SELECT COUNT(*) FROM Sobrevivente WHERE id_casa = OLD.id_casa
    )
  WHERE id_instalacao = OLD.id_casa;
END$$

CREATE TRIGGER AU_Sobrevivente_Casa
AFTER UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  IF OLD.id_casa <> NEW.id_casa THEN
    UPDATE Casa
      SET num_sobreviventes = (
        SELECT COUNT(*) FROM Sobrevivente WHERE id_casa = OLD.id_casa
      )
    WHERE id_instalacao = OLD.id_casa;

    UPDATE Casa
      SET num_sobreviventes = (
        SELECT COUNT(*) FROM Sobrevivente WHERE id_casa = NEW.id_casa
      )
    WHERE id_instalacao = NEW.id_casa;
  END IF;
END$$

CREATE TRIGGER AI_Sobrevivente_Trabalhador
AFTER INSERT ON Sobrevivente
FOR EACH ROW
BEGIN
  IF NEW.idade >= 15 THEN
    IF (SELECT COUNT(*) FROM Trabalhador WHERE id_sobrevivente = NEW.id_sobrevivente) = 0 THEN
      INSERT INTO Trabalhador (id_sobrevivente, id_instalacao_trabalho)
        VALUES (NEW.id_sobrevivente, NULL);
    END IF;
  END IF;
END$$

CREATE TRIGGER AU_Sobrevivente_Trabalhador
AFTER UPDATE ON Sobrevivente
FOR EACH ROW
BEGIN
  IF OLD.idade < 15 AND NEW.idade >= 15 THEN
    IF (SELECT COUNT(*) FROM Trabalhador WHERE id_sobrevivente = NEW.id_sobrevivente) = 0 THEN
      INSERT INTO Trabalhador (id_sobrevivente, id_instalacao_trabalho)
        VALUES (NEW.id_sobrevivente, NULL);
    END IF;
  END IF;
END$$

CREATE TRIGGER AI_Trabalhador_FazendaClinica
AFTER INSERT ON Trabalhador
FOR EACH ROW
BEGIN
  IF NEW.id_instalacao_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE id_instalacao = NEW.id_instalacao_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = NEW.id_instalacao_trabalho
        )
      WHERE id_instalacao = NEW.id_instalacao_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE id_instalacao = NEW.id_instalacao_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = NEW.id_instalacao_trabalho
        )
      WHERE id_instalacao = NEW.id_instalacao_trabalho;
    END IF;
  END IF;
END$$

CREATE TRIGGER AD_Trabalhador_FazendaClinica
AFTER DELETE ON Trabalhador
FOR EACH ROW
BEGIN
  IF OLD.id_instalacao_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE id_instalacao = OLD.id_instalacao_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = OLD.id_instalacao_trabalho
        )
      WHERE id_instalacao = OLD.id_instalacao_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE id_instalacao = OLD.id_instalacao_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = OLD.id_instalacao_trabalho
        )
      WHERE id_instalacao = OLD.id_instalacao_trabalho;
    END IF;
  END IF;
END$$

CREATE TRIGGER AU_Trabalhador_FazendaClinica
AFTER UPDATE ON Trabalhador
FOR EACH ROW
BEGIN
  IF OLD.id_instalacao_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE id_instalacao = OLD.id_instalacao_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = OLD.id_instalacao_trabalho
        )
      WHERE id_instalacao = OLD.id_instalacao_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE id_instalacao = OLD.id_instalacao_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = OLD.id_instalacao_trabalho
        )
      WHERE id_instalacao = OLD.id_instalacao_trabalho;
    END IF;
  END IF;

  IF NEW.id_instalacao_trabalho IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM Fazenda WHERE id_instalacao = NEW.id_instalacao_trabalho) THEN
      UPDATE Fazenda
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = NEW.id_instalacao_trabalho
        )
      WHERE id_instalacao = NEW.id_instalacao_trabalho;
    END IF;

    IF EXISTS (SELECT 1 FROM Clinica WHERE id_instalacao = NEW.id_instalacao_trabalho) THEN
      UPDATE Clinica
        SET num_trabalhadores = (
          SELECT COUNT(*) FROM Trabalhador WHERE id_instalacao_trabalho = NEW.id_instalacao_trabalho
        )
      WHERE id_instalacao = NEW.id_instalacao_trabalho;
    END IF;
  END IF;
END$$

CREATE TRIGGER AI_Remedio_Clinica
AFTER INSERT ON Remedio
FOR EACH ROW
BEGIN
  UPDATE Clinica
    SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
  WHERE id_instalacao = NEW.id_clinica;
END$$

CREATE TRIGGER AD_Remedio_Clinica
AFTER DELETE ON Remedio
FOR EACH ROW
BEGIN
  UPDATE Clinica
    SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = OLD.id_clinica)
  WHERE id_instalacao = OLD.id_clinica;
END$$

CREATE TRIGGER AU_Remedio_Clinica
AFTER UPDATE ON Remedio
FOR EACH ROW
BEGIN
  IF OLD.id_clinica <> NEW.id_clinica THEN
    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = OLD.id_clinica)
    WHERE id_instalacao = OLD.id_clinica;

    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
    WHERE id_instalacao = NEW.id_clinica;
  ELSE
    UPDATE Clinica
      SET qtd_remedios = (SELECT COUNT(*) FROM Remedio WHERE id_clinica = NEW.id_clinica)
    WHERE id_instalacao = NEW.id_clinica;
  END IF;
END$$

CREATE TRIGGER AI_Arma_Armazem
AFTER INSERT ON Arma
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
  WHERE id_instalacao = NEW.id_armazem;
END$$

CREATE TRIGGER AD_Arma_Armazem
AFTER DELETE ON Arma
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = OLD.id_armazem)
  WHERE id_instalacao = OLD.id_armazem;
END$$

CREATE TRIGGER AU_Arma_Armazem
AFTER UPDATE ON Arma
FOR EACH ROW
BEGIN
  IF OLD.id_armazem <> NEW.id_armazem THEN
    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = OLD.id_armazem)
    WHERE id_instalacao = OLD.id_armazem;

    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
    WHERE id_instalacao = NEW.id_armazem;
  ELSE
    UPDATE Armazem
      SET qtd_armas = (SELECT COUNT(*) FROM Arma WHERE id_armazem = NEW.id_armazem)
    WHERE id_instalacao = NEW.id_armazem;
  END IF;
END$$

CREATE TRIGGER AI_Comida_Armazem
AFTER INSERT ON Comida
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET kg_comida = (
      SELECT IFNULL(SUM(peso), 0) FROM Comida WHERE id_armazem = NEW.id_armazem
    )
  WHERE id_instalacao = NEW.id_armazem;
END$$

CREATE TRIGGER AD_Comida_Armazem
AFTER DELETE ON Comida
FOR EACH ROW
BEGIN
  UPDATE Armazem
    SET kg_comida = (
      SELECT IFNULL(SUM(peso), 0) FROM Comida WHERE id_armazem = OLD.id_armazem
    )
  WHERE id_instalacao = OLD.id_armazem;
END$$

CREATE TRIGGER AU_Comida_Armazem
AFTER UPDATE ON Comida
FOR EACH ROW
BEGIN
  IF OLD.id_armazem <> NEW.id_armazem THEN
    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = OLD.id_armazem)
    WHERE id_instalacao = OLD.id_armazem;

    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = NEW.id_armazem)
    WHERE id_instalacao = NEW.id_armazem;
  ELSE
    UPDATE Armazem
      SET kg_comida = (SELECT IFNULL(SUM(peso),0) FROM Comida WHERE id_armazem = NEW.id_armazem)
    WHERE id_instalacao = NEW.id_armazem;
  END IF;
END$$

DELIMITER ;