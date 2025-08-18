# Apocalipse BD  

**Autores:**  
[Carlos Henrique Goebel Teixeira Furtado](https://github.com/CarlosHFurtado) <br>
[Gerson Farias Clara](https://github.com/Gerson-Clara) <br>
[Gustavo Domenech](https://github.com/GustavoDomenech/)

**Um projeto de banco de dados aplicado a um mundo pós-apocalíptico fictício.**  





---

## 1. Estrutura do Banco  

A base foi criada com a entidade central **Instalação**, da qual derivam:  
- **Casa** → controla sobreviventes por capacidade.  
- **Fazenda** → responsável pela produção de alimentos.  
- **Clínica** → armazena e distribui remédios.  
- **Armazém** → concentra estoques de armas e comidas.  

Outras entidades complementares:  
- **Sobrevivente** → pessoa vinculada a uma casa.  
- **Trabalhador** → sobrevivente maior de 15 anos, alocado em instalações.  
- **Arma, Comida, Remédio** → recursos vinculados a armazéns e clínicas.  

**Triggers implementadas:**  
- Número de sobreviventes por casa.  
- Número de trabalhadores por instalação.  
- Quantidade de recursos em clínicas e armazéns.  

---

## 2. Inserção de Dados  

O banco foi populado com registros representativos:  
- 18 instalações (casas, fazendas, clínicas e armazéns).  
- 45 sobreviventes, distribuídos em casas com diferentes capacidades.  
- Trabalhadores vinculados a fazendas, clínicas e armazéns.  
- Armas em armazéns (ex.: pistolas, facas, rifles).  
- Comidas variadas estocadas em armazéns.  
- Remédios inseridos nas clínicas, com controle de quantidade.  

---

## 3. Consultas  

Foram criadas consultas SQL para responder a questões relevantes de gestão:  
- **Listar casas com capacidade e ocupação** → mostra se há espaço para novos sobreviventes.  
- **Mostrar sobreviventes e suas casas** → vincula indivíduos a seus lares.  
- **Listar trabalhadores e onde trabalham** → identifica a força de trabalho ativa em cada instalação.  
- **Listar armas e armazéns** → descreve o estoque bélico.  
- **Listar remédios e clínicas** → detalha medicamentos disponíveis e quantidades.  
- **Contagem de sobreviventes por casa** → dá uma visão geral da distribuição da população.  
- **Relatório integrado (extra)** → mostra, em um só resultado, itens em armazéns e clínicas (armas, comidas e remédios).  

---
