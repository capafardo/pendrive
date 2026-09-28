# 🛠️ Sistemas de Arquivos em Mídias Removíveis

Este documento detalha o funcionamento, as características, as vantagens e as limitações dos sistemas de arquivos e formatos suportados pelo utilitário `iniciar.sh`.

---

## 1. Tabela Comparativa

| Sistema de Arquivos | Tamanho Máximo de Arquivo | Compatibilidade com SOs | Journaling (Transações) | Uso Típico |
| :--- | :--- | :--- | :--- | :--- |
| **FAT32** | 4 GB | Universal (Windows, Linux, macOS, TVs, Som automotivo) | Não | Pendrives em geral, rádios automotivos, impressoras 3D |
| **exFAT** | 16 EB (praticamente ilimitado) | Windows, macOS, Linux (kernel >= 5.7 ou `exfatprogs`) | Não | Pendrives grandes, cartões SDXC de câmeras, filmes 4K |
| **NTFS** | 16 TB (limite prático) | Windows (nativo), Linux (leitura/escrita via `ntfs-3g`), macOS (apenas leitura nativa) | Sim | Pendrives para ambientes predominantemente Windows |
| **EXT4** | 16 TB | Linux nativo (outros sistemas exigem softwares terceiros) | Sim | Dispositivos dedicados a servidores ou estações Linux |
| **ISO 9660 / UDF** | Varia (tamanho da imagem) | Universal para Boot (BIOS / UEFI) | Não (Somente Leitura) | Mídias de instalação de sistemas operacionais (Live USB) |

---

## 2. Detalhamento Técnico dos Formatos

### 2.1 FAT32 (File Allocation Table 32)
* **Estrutura**: Baseado em uma tabela de alocação de arquivos simples. Utiliza clusters de 32 bits (com 28 bits utilizáveis).
* **Vantagens**: Compatibilidade máxima com praticamente qualquer dispositivo com porta USB (computadores antigos, televisões, som de carro, consoles).
* **Desvantagens**: 
  - Limite estrito de **4 GB por arquivo individual**. Tentar copiar uma imagem ISO de 5 GB para FAT32 resultará em erro de "espaço insuficiente", mesmo com espaço livre.
  - Não possui **journaling**, o que significa que puxar o pendrive sem ejetar pode facilmente corromper a tabela de alocação.
* **Ferramenta de reparo no Linux**: `dosfsck` (ou `fsck.vfat`), pacote `dosfstools`.

---

### 2.2 exFAT (Extended File Allocation Table)
* **Estrutura**: Criado pela Microsoft como uma evolução do FAT32, mantendo a simplicidade e a baixa sobrecarga em memória, mas removendo a barreira dos 4 GB.
* **Vantagens**:
  - Aceita arquivos gigantes (> 4 GB).
  - Excelente compatibilidade entre Windows e macOS sem configurações extras.
* **Desvantagens**:
  - Dispositivos embarcados mais antigos (rádios de carro, TVs antigas) frequentemente não suportam exFAT.
  - Não possui mecanismo robusto de journaling.
* **Ferramenta de reparo no Linux**: `fsck.exfat`, pacote `exfatprogs`.

---

### 2.3 NTFS (New Technology File System)
* **Estrutura**: Sistema de arquivos moderno do Windows que utiliza árvores B+ e a Master File Table (`$MFT`).
* **Vantagens**:
  - Suporte a Journaling (diário de transações): reduz drasticamente o risco de perda total em desligamentos repentinos.
  - Suporte a arquivos gigantes, permissões de segurança e compressão transparente.
* **Desvantagens**:
  - O macOS nativamente só realiza leitura (não escreve por padrão).
  - Aparelhos de som e televisões frequentemente não reconhecem NTFS.
* **Ferramenta de reparo no Linux**: `ntfsfix` (pacote `ntfs-3g`). 
  > **Nota**: O `ntfsfix` no Linux corrige inconsistências básicas, limpa o log de transações e agenda uma checagem completa (`chkdsk`) para a próxima vez que o pendrive for plugado em uma máquina Windows.

---

### 2.4 EXT4 (Fourth Extended Filesystem)
* **Estrutura**: Padrão do ecossistema GNU/Linux. Possui journaling completo, alocação tardia de blocos e suporte a permissões POSIX (dono, grupo e permissões `rwxrwxrwx`).
* **Vantagens**:
  - Altíssimo desempenho e extrema integridade contra corrupção em Linux.
* **Desvantagens**:
  - Não é legível nativamente no Windows ou macOS sem a instalação de drivers específicos de terceiros.
* **Ferramenta de reparo no Linux**: `e2fsck` (pacote `e2fsprogs`).

### 2.5 ISO 9660 e Mídias Híbridas (ISOHybrid)
* **Estrutura**: Padrão internacional para mídia óptica (CD-ROM/DVD). Quando adaptado para o formato *ISOHybrid*, inclui cabeçalhos MBR/GPT válidos permitindo inicialização tanto em computadores com BIOS Legado quanto UEFI modernos.
* **Características**:
  - É um sistema de arquivos estritamente **somente leitura** (*read-only*).
  - Ao ser gravado via `dd`, assume o controle integral dos primeiros setores do pendrive.
  - O sistema operacional reportará a capacidade do pendrive como sendo exatamente o tamanho da ISO (ex: um pendrive de 64 GB parecerá ter apenas 3.8 GB).
* **Restauração**:
  - Para converter o pendrive de volta a um dispositivo de armazenamento comum após instalar a distribuição, utilize a **Opção [8] (Zerar Tabela / Reviver Pendrive Travado)** do script.

---

## 3. Recomendações de Escolha na Formatação

1. **Se você precisa usar o pendrive em televisores, centrais multimídia de carros ou impressoras**: Escolha **FAT32**.
2. **Se você transfere arquivos grandes (vídeos, ISOs) entre computadores Windows e Mac**: Escolha **exFAT**.
3. **Se o pendrive será usado exclusivamente em PCs com Windows e Linux**: Escolha **NTFS**.
4. **Se o pendrive será usado para backups ou transferências exclusivas em Linux**: Escolha **EXT4**.
5. **Se o objetivo for criar um pendrive bootável de instalação**: Escolha a **Opção [9] (Gravar Imagem ISO)**.
