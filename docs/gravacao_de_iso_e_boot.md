# 🚀 Gravação de Imagens ISO e Criação de Pendrives Bootáveis

Este documento explica em detalhes como funciona a gravação de imagens ISO para inicialização de sistemas operacionais (como Ubuntu, Debian, Fedora, Arch Linux, Linux Mint e outros) em unidades USB utilizando o script `iniciar.sh`.

---

## 1. O que é uma Imagem ISO Híbrida (*ISOHybrid*)?

No passado, imagens `.iso` eram projetadas exclusivamente para mídias ópticas (CD-ROMs e DVDs), utilizando a norma **ISO 9660**. Unidades USB, por sua vez, utilizam estruturas de disco rígido baseadas em **MBR (Master Boot Record)** ou **GPT (GUID Partition Table)**.

Para resolver esse conflito sem exigir programas proprietários complexos, as distribuições modernas de Linux utilizam o formato **ISOHybrid**:
* A imagem contém uma tabela de partição MBR/GPT válida gravada logo nos primeiros 512 bytes.
* O restante dos blocos contém o sistema de arquivos ISO 9660 com a imagem do kernel e o initramfs.
* **Resultado**: A mesma imagem pode ser gravada byte a byte diretamente em um pendrive ou queimada em um DVD, e inicializará com perfeição em ambos os casos.

---

## 2. Como a Opção [9] Funciona Internamente

Quando você escolhe a opção **`[9] Gravar Imagem ISO no Pendrive`**, o script executa um fluxo rigoroso de segurança e gravação:

```text
[Seleção de Imagem] -> [Validação de Leitura] -> [Checagem de Espaço vs Pendrive]
        |
        v
[Proteção de Disco do Sistema] -> [Confirmação Digitada 'GRAVAR']
        |
        v
[Desmontagem de Partições (umount)] -> [Gravação Bruta com dd]
        |
        v
[Sincronização de Buffers (sync)] -> [Releitura da Tabela (partprobe)]
```

### 2.1 Por que a gravação é feita em `/dev/sdX` e não na partição?
O bootloader do Linux (GRUB, Syslinux ou Systemd-boot) precisa ser localizado pela BIOS/UEFI no **setor zero do disco**. 
Se a gravação fosse feita dentro de `/dev/sdX1`, o setor zero do pendrive continuaria apontando para o sistema de arquivos anterior e a placa-mãe reportaria erro de "Mídia não inicializável".

### 2.2 O comando de gravação
```bash
dd if="/caminho/distro.iso" of="/dev/sdX" bs=4M status=progress oflag=sync
```
* **`bs=4M`**: Transfere blocos de 4 Megabytes por vez, compatíveis com a arquitetura das células de memória flash.
* **`status=progress`**: Informa taxa de transferência (MB/s), bytes gravados e tempo decorrido em tempo real.
* **`oflag=sync`**: Exige que cada bloco seja fisicamente gravado na mídia antes de enviar o próximo, garantindo uma medição fidedigna do progresso.

---

## 3. O Que Acontece com o Pendrive Após a Gravação?

Muitos usuários se assustam com o estado do pendrive após a gravação de uma ISO. Compreender os seguintes pontos evita diagnósticos errôneos:

1. **O Pendrive Fica em Modo Somente Leitura**:
   Como a imagem ISO 9660 é um formato desenvolvido para mídia óptica gravada, o kernel do Linux a monta em modo estritamente *read-only*. Você não poderá adicionar arquivos avulsos a ela diretamente pelo gerenciador de arquivos.
2. **A Capacidade Aparente Diminui**:
   Se você gravou uma imagem de 3.5 GB em um pendrive de 64 GB, o sistema operacional reportará que o pendrive possui apenas 3.5 GB. O espaço restante (60.5 GB) continua intacto fisicamente, mas fica não-alocado.
3. **Múltiplas Partições Estranhas no Gerenciador de Discos**:
   ISOs híbridas frequentemente criam partições ocultas pequenas (como uma partição EFI FAT12/FAT16 de poucos megabytes) para permitir o boot em computadores UEFI. Isso é normal e necessário.

---

## 4. Como Restaurar o Pendrive para Uso Normal

Quando terminar de instalar a distribuição Linux e desejar que o pendrive volte a ter sua capacidade total de 100% livre para armazenar músicas, vídeos e documentos comuns:

1. Abra o assistente: `sudo ./iniciar.sh`.
2. Selecione a unidade com a opção **`1`**.
3. Escolha a opção **`8` (Zerar Tabela / Reviver Pendrive Travado)**.
4. Digite **`ZERAR`** para confirmar.

O assistente gravará zeros no cabeçalho corrompido da ISO, gerará uma nova tabela MBR e recriará uma partição única limpa formatada em **FAT32** ocupando 100% da capacidade real da mídia.

---

## 5. Dica Bônus: Como Testar o Pendrive Bootável sem Reiniciar

Se o seu sistema possui o virtualizador **QEMU** instalado, você pode testar se o pendrive está dando boot sem precisar reiniciar o computador físico:

```bash
# Ubuntu/Debian: sudo apt install qemu-system-x86
sudo qemu-system-x86_64 -m 2048 -enable-kvm -drive file=/dev/sdX,format=raw
```
*(Substitua `/dev/sdX` pelo dispositivo do seu pendrive, ex: `/dev/sdb`)*
