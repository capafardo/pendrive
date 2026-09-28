# 💾 Assistente de Diagnóstico e Reparo de Pendrives (`iniciar.sh`)

Um utilitário interativo em Shell Script projetado para **identificar**, **testar**, **reparar** e **formatar** pendrives, cartões de memória e unidades USB no GNU/Linux com facilidade e segurança.

---

## 📖 Sumário
1. [Por que este script foi criado?](#-por-que-este-script-foi-criado)
2. [Instalação e Requisitos](#-instalação-e-requisitos)
3. [Como Executar](#-como-executar)
4. [Entendendo as Opções do Menu (Guia Didático)](#-entendendo-as-opções-do-menu-guia-didático)
5. [Roteiros Práticos: Como Resolver os Problemas Mais Comuns](#-roteiros-práticos-como-resolver-os-problemas-mais-comuns)
6. [Mecanismos de Proteção e Segurança](#-mecanismos-de-proteção-e-segurança)
7. [Documentação Técnica Complementar](#-documentação-técnica-complementar)

---

## 🎯 Por que este script foi criado?

Pendrives são mídias muito convenientes, mas frequentemente apresentam problemas quando:
* São removidos da porta USB sem clicar em "Ejetar com segurança".
* Foram usados para gravar imagens de instalação (como Ubuntu, Windows, Ventoy) e ficam com partições ocultas ou tamanho reduzido.
* Ficam em modo "somente leitura" devido a erros no sistema de arquivos.
* Apresentam lentidão extrema ou travam o gerenciador de arquivos.

Este script reúne em um **único menu simples e guiado** os comandos essenciais do Linux que técnicos usam no terminal, evitando a necessidade de memorizar comandos complexos.

---

## 📦 Instalação e Requisitos

O script utiliza ferramentas padrão do ecossistema Linux. Para garantir suporte a todos os formatos (FAT32, NTFS, exFAT e EXT4):

### No Ubuntu, Debian, Linux Mint, Pop!_OS e derivados:
```bash
sudo apt update
sudo apt install dosfstools ntfs-3g exfatprogs e2fsprogs parted udisks2 util-linux
```

### No Fedora, RHEL ou Rocky Linux:
```bash
sudo dnf install dosfstools ntfs-3g exfatprogs e2fsprogs parted udisks2 util-linux
```

### No Arch Linux e Manjaro:
```bash
sudo pacman -Sy dosfstools ntfs-3g exfatprogs e2fsprogs parted udisks2 util-linux
```

---

## 🚀 Como Executar

Abra o terminal na pasta do projeto e inicie com privilégios de superusuário (`sudo`), pois operações de disco exigem acesso de baixo nível ao hardware:

```bash
git clone https://github.com/capafardo/pendrive.git
cd pendrive
chmod +x iniciar.sh
sudo ./iniciar.sh
```

> **Dica**: Em qualquer tela ou submenu, você pode digitar **`0`** para cancelar a ação e voltar ao menu anterior com segurança.

---

## 🖥️ Entendendo as Opções do Menu (Guia Didático)

```text
============================================================
           FERRAMENTA DE DIAGNÓSTICO E REPARO DE PENDRIVES   
============================================================
  [1] Selecionar/Alterar Pendrive
  [2] Ver Informações Detalhadas do Pendrive
  [3] Desmontar Partições com Segurança
  [4] Verificar Integridade do Sistema de Arquivos (Somente Leitura)
  [5] Reparar Sistema de Arquivos (Corrigir Erros)
  [6] Verificar Setores Defeituosos (Badblocks)
  [7] Formatar Pendrive (FAT32, NTFS, exFAT ou EXT4)
  [8] Zerar Tabela / Reviver Pendrive Travado (DD + Nova MBR)
  [9] Gravar Imagem ISO no Pendrive (Criar Pendrive Bootável)
  [10] Teste de Velocidade (Leitura e Escrita)
  [11] Ejetar Pendrive com Segurança
  ------------------------------------------------------------
  [0] Sair
```

### Detalhamento das Opções:

| Opção | Nome | O que faz na prática? | Apaga os arquivos? |
| :---: | :--- | :--- | :---: |
| **`[1]`** | **Selecionar Pendrive** | Lista apenas as mídias USB conectadas para você escolher qual deseja gerenciar (ex: `sdb`, `sdc`). | ❌ Não |
| **`[2]`** | **Informações Detalhadas** | Mostra marca, modelo, capacidade real em bytes, número serial, UUID e tabela de partições. | ❌ Não |
| **`[3]`** | **Desmontar com Segurança** | Desconecta as pastas do pendrive do sistema operacional (`umount`). **Obrigatório** antes de testar ou formatar. | ❌ Não |
| **`[4]`** | **Verificar (Somente Leitura)** | Inspeciona o pendrive sem alterar nada. Ideal para saber se há corrupção antes de arriscar um reparo. | ❌ Não |
| **`[5]`** | **Reparar Sistema de Arquivos** | Corrige ponteiros quebrados, reconecta arquivos órfãos e recupera blocos corrompidos no FAT32, NTFS ou EXT4. | ⚠️ Pode alterar arquivos corrompidos |
| **`[6]`** | **Verificar Badblocks** | Testa se há células de memória física queimadas ou danificadas no chip flash. Possui modo seguro e modo profundo. | ❌ (Modo Leitura)<br>⚠️ **SIM** (Modo Escrita) |
| **`[7]`** | **Formatar Pendrive** | Cria uma partição nova e limpa no formato escolhido (FAT32, NTFS, exFAT ou EXT4) com um nome personalizado. | ⚠️ **SIM** |
| **`[8]`** | **Zerar Tabela (Reviver Mídia)** | Grava zeros brutos nos primeiros setores via `dd`. Perfeito para pendrives "invisíveis", ilegíveis ou com partições travadas. | ⚠️ **SIM** |
| **`[9]`** | **Gravar Imagem ISO** | Escreve uma ISO híbrida de distribuição Linux diretamente no pendrive via `dd` para criar uma mídia bootável. | ⚠️ **SIM** |
| **`[10]`** | **Teste de Velocidade** | Escreve um arquivo de teste de 100 MB e mede a velocidade real em MB/s de gravação e leitura. | ❌ Não |
| **`[11]`** | **Ejetar Pendrive** | Descarrega a memória RAM para o disco (`sync`), desmonta partições e desliga a energia elétrica da porta USB. | ❌ Não |
| **`[0]`** | **Sair / Voltar** | Encerra o script ou volta para o menu imediatamente. | ❌ Não |

---

## 🛠️ Roteiros Práticos: Como Resolver os Problemas Mais Comuns

### 🔹 Cenário A: O pendrive não deixa salvar nada / Diz "Somente Leitura"
1. Abra o script: `sudo ./iniciar.sh`.
2. Escolha **`1`** e selecione o pendrive.
3. Escolha **`4`** para verificar se há erros na partição.
4. Escolha **`5`** para executar a reparação automática.
5. Se for FAT32, o script perguntará se deseja o modo Automático (`1`) ou Interativo (`2`). Escolha `1`.
6. Após a conclusão, retire e reconecte o pendrive.

### 🔹 Cenário B: O pendrive foi usado para gravar ISO e agora não formata pelo Windows/Linux
1. Escolha a opção **`1`** e selecione a unidade.
2. Escolha a opção **`8` (Zerar Tabela / Reviver Pendrive Travado)**.
3. Digite a palavra `ZERAR` para confirmar.
4. O script gravará zeros nos primeiros megabytes com `dd`, criará uma nova tabela MBR e deixará uma partição limpa em FAT32 pronta para uso.

### 🔹 Cenário C: Suspeita de pendrive falso ou com defeito físico
1. Selecione a unidade com a opção **`1`**.
2. Escolha a opção **`6` (Verificar Badblocks)** e selecione a opção `1` (Teste de Leitura Seguro).
3. Se o teste apontar blocos defeituosos, o chip flash do pendrive está se degradando fisicamente. Faça backup imediato dos dados e substitua o dispositivo.

### 🔹 Cenário D: Criar um pendrive bootável para instalar distribuições Linux
1. Baixe o arquivo `.iso` da sua distribuição favorita (ex: Ubuntu, Fedora, Debian, Linux Mint).
2. Abra o script: `sudo ./iniciar.sh`.
3. Escolha **`1`** e selecione o pendrive de destino.
4. Escolha a opção **`9` (Gravar Imagem ISO no Pendrive)**.
5. Arraste a ISO para o terminal ou digite o caminho do arquivo (com suporte a autocompletar via `Tab`).
6. O script verificará se a ISO cabe no pendrive e solicitará a confirmação digitada (`GRAVAR`).
7. Ao término da escrita, o pendrive estará pronto para dar boot e instalar o sistema!

---

## 🛡️ Mecanismos de Proteção e Segurança

Operações de formatação e reparo podem ser destrutivas se o usuário errar a letra do disco (ex: digitar `sda` em vez de `sdb`).

O script conta com proteções ativas:
1. **Filtro de Dispositivos de Sistema**: O script lê a tabela do kernel (`lsblk`). Se você acidentalmente digitar o disco onde está a sua raiz (`/`) ou o seu sistema operacional, **a operação é sumariamente abortada** com um aviso vermelho.
2. **Confirmação em Etapas**: Nenhuma ação destrutiva (como formatar ou zerar via `dd`) é disparada sem pedir confirmação explícita (`s/N` ou digitação de palavras-chave como `CONFIRMAR` ou `ZERAR`).
3. **Sincronização de Disco (`sync`)**: Todos os comandos que alteram dados executam `sync` para forçar o descarregamento da memória RAM para o pendrive antes que você o remova.

---

## 📚 Documentação Técnica Complementar

Para compreender os conceitos avançados de hardware, kernel e sistemas de arquivos envolvidos, consulte os guias na pasta [`docs/`](docs/):

* [**Sistemas de Arquivos (`docs/sistemas_de_arquivos.md`)**](docs/sistemas_de_arquivos.md): Comparação detalhada entre FAT32, exFAT, NTFS e EXT4, limites de arquivos e compatibilidade entre sistemas operacionais.
* [**Diagnóstico e Reparo Interno (`docs/diagnostico_e_reparo.md`)**](docs/diagnostico_e_reparo.md): Como funcionam `fsck`, `dosfsck`, `ntfsfix` e `badblocks`, além da diferença entre erro lógico e físico.
* [**Segurança e Particionamento (`docs/seguranca_e_particionamento.md`)**](docs/seguranca_e_particionamento.md): Funcionamento do bloqueio de segurança contra formatação da raiz, MBR vs GPT, alinhamento de blocos e ciclo elétrico da porta USB.
