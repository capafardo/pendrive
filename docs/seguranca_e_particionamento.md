# 🛡️ Segurança, Particionamento e Ciclo de Vida USB

Este documento descreve as camadas de proteção implementadas no script para evitar desastres acidentais no sistema operacional e detalha as operações de baixo nível de particionamento e ejeção.

---

## 1. Camadas de Proteção Contra Erros Humanos

Uma das maiores preocupações ao usar ferramentas de linha de comando com `root` (como `dd`, `mkfs` ou `fdisk`) é a possibilidade de selecionar o disco do próprio sistema operacional (como `sda` ou `nvme0n1`) e causar a destruição irreversível do computador.

Para evitar isso, o script implementa proteções automáticas:

### 1.1 Filtragem Visual de Dispositivos USB
O comando de listagem analisa as propriedades de barramento (`TRAN=usb`) e o atributo de mídia removível (`RM=1`). Dispositivos NVMe ou discos SATA internos são destacados separadamente ou omitidos para evitar confusão visual.

### 1.2 Bloqueio de Partições do Sistema
Antes de aceitar qualquer dispositivo informado pelo usuário, o script executa a função interna:
```bash
is_disco_sistema() {
    local dev="$1"
    if lsblk -no MOUNTPOINTS "$dev" 2>/dev/null | grep -qE '^/($|boot|home|usr|etc)'; then
        return 0 # É disco crítico do sistema
    fi
    return 1
}
```
Se o dispositivo contiver pontos vitais como `/` (raiz), `/boot` ou `/home`, o script **rejeita imediatamente** a seleção e exibe um alerta sonoro/visual, impedindo que operações destrutivas continuem.

---

## 2. Particionamento: MBR (msdos) vs. GPT

O script adota por padrão a tabela de partição **MBR (Master Boot Record / msdos)** para pendrives pelas seguintes razões:

* **Compatibilidade Universal**: Quase todas as Smart TVs, consoles de videogame (PS4, Xbox, Nintendo Switch), rádios automotivos e versões antigas do Windows suportam MBR sem problemas.
* **Tamanho de Mídia**: Pendrives comuns variam de 4 GB a 512 GB. Como o MBR suporta discos de até 2 TB, ele atende com perfeição a esse cenário.
* **Alinhamento de 1 MiB**: O script utiliza a opção `parted -s -a optimal ... 1MiB 100%`, alinhando a partição com o tamanho dos blocos de apagamento da memória NAND Flash, o que previne desgaste prematuro e melhora a velocidade de gravação.

---

## 3. A Técnica de Zerar com `dd` (Reviver Pendrive Travado)

Quando um pendrive foi usado com instaladores de sistemas operacionais (como Rufus, Ventoy, BalenaEtcher) ou sofreu corrupção grave, ele pode ficar com resquícios de partições ISO9660, tabelas GPT corrompidas ou setores com assinaturas conflitantes que impedem o Windows ou o Linux de reconhecerem a unidade.

O script executa a recuperação com o seguinte procedimento:
```bash
dd if=/dev/zero of=/dev/sdX bs=1M count=10 status=progress conv=fsync
```
### O que essa instrução faz?
1. Grava 10 Megabytes de zeros binários no início da unidade.
2. Destrói completamente o setor de boot (MBR), a tabela de partição primária e os primeiros nós-índice.
3. Remove qualquer assinatura de sistema de arquivos anterior (`wipefs`).
4. Em seguida, o `parted` e o `partprobe` criam uma tabela limpa e uma partição FAT32 nova, deixando o pendrive como novo de fábrica.

---

## 4. O Buffer de Disco e a Ejeção Segura

### 4.1 Por que o comando `sync` é crucial?
Para acelerar a experiência do usuário, sistemas operacionais modernos não gravam imediatamente os dados no pendrive assim que a barra de progresso gráfica termina. O Linux armazena os dados em um buffer na memória RAM (**Dirty Cache**).
O comando `sync` força o kernel a descarregar todos os blocos pendentes da memória para a memória flash física do pendrive.

### 4.2 Por que usar `udisksctl power-off` em vez de apenas desplugá-lo?
Mesmo após desmontar as partições, a porta USB continua fornecendo 5 Volts ao pendrive. O comando:
```bash
udisksctl power-off -b /dev/sdX
```
solicita ao subsistema de gerenciamento de energia do kernel que envie um comando de desligamento e corte o fornecimento elétrico do dispositivo, garantindo que o controlador flash finalize seus ciclos internos de *wear-leveling* e preservando a vida útil do componente.
