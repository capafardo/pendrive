# 🔍 Diagnóstico e Reparo: Entendendo o Funcionamento Interno

Este documento detalha o que acontece "por baixo dos panos" quando você executa comandos de diagnóstico e reparo em uma unidade USB no Linux.

---

## 1. Dano Lógico vs. Dano Físico

Ao lidar com problemas em pendrives, o primeiro passo é diagnosticar a natureza do defeito:

### 1.1 Falha Lógica (Software / Sistema de Arquivos)
* **Causa**: O pendrive foi removido durante uma operação de gravação, ou o computador foi desligado repentinamente.
* **Sintoma**: O sistema operacional reconhece o dispositivo (`/dev/sdb`), mas diz "Sistema de arquivos não reconhecido", "Partição RAW", "Somente leitura" ou recusa a montagem.
* **Solução**: Reparo via `fsck`, `dosfsck`, `ntfsfix` ou regravação de tabela de partições e formatação. Os dados frequentemente podem ser recuperados ou corrigidos.

### 1.2 Falha Física (Hardware / Memória NAND Flash)
* **Causa**: Desgaste natural das células de silício (ciclos de escrita e leitura esgotados), queima da controladora USB ou setores defeituosos no chip flash.
* **Sintoma**: Erros de I/O contínuos no `dmesg`, travamento do sistema ao tentar ler blocos, pendrive entra em modo permanente "somente leitura" por trava de hardware da controladora para proteger os dados.
* **Solução**: Teste com `badblocks`. Se houver blocos defeituosos na memória flash de um pendrive, a mídia tornou-se instável e **deve ser substituída**.

---

## 2. Como Funcionam as Ferramentas de Verificação

### 2.1 Por que é obrigatório desmontar (`umount`) antes de checar?
Quando um sistema de arquivos está montado, o kernel do Linux mantém metadados e blocos na memória RAM para otimizar desempenho.
Se uma ferramenta como o `fsck` tentar inspecionar e alterar as estruturas diretamente no disco enquanto o kernel está gravando na partição, ocorrerá uma condição de corrida que pode destruir permanentemente a integridade dos dados. Por isso, o script sempre realiza o `umount` antes de qualquer verificação.

---

### 2.2 Diagnóstico em Modo Leitura (`-n`)
No script, a opção **[4]** executa os comandos com parâmetros de checagem sem modificação:
* `dosfsck -v -n /dev/sdX1`: O parâmetro `-n` (no-op) responde automaticamente "não" a qualquer tentativa de reparo, apenas relatando clusters órfãos, inconsistências no Boot Sector e tamanhos incorretos de diretórios.
* `e2fsck -v -n /dev/sdX1`: Percorre as 5 fases do ext4 (checagem de nós-índice, blocos de diretório, conectividade de nós, contagem de referências e mapas de alocação) sem alterar um único bit do disco.

---

### 2.3 Reparo Automático vs. Interativo
No reparo de sistemas FAT32/VFAT:
* **Modo Automático (`-a`)**: Tenta reparar inconsistências lógicas óbvias (como religar clusters perdidos e remover referências nulas) sem perguntar cada detalhe ao usuário.
* **Modo Interativo (`-r`)**: Exibe cada discrepância encontrada e pergunta se o usuário deseja recuperar o cluster (salvando-o como arquivo `.REC` na raiz) ou liberá-lo como espaço livre.

---

### 2.4 Como Funciona o `badblocks`
O utilitário `badblocks` varre o dispositivo setor por setor:

1. **Modo Leitura (Não-destrutivo)**:
   ```bash
   badblocks -s -v -b 4096 /dev/sdX
   ```
   Lê cada bloco de 4 KB do pendrive. Se a controladora USB relatar erro de timeout ou erro de I/O em um endereço, esse bloco é marcado como defeituoso.

2. **Modo Escrita/Leitura (Destrutivo)**:
   ```bash
   badblocks -w -s -v -b 4096 /dev/sdX
   ```
   Grava 4 padrões binários diferentes (`0xaa`, `0x55`, `0xff`, `0x00`) em cada bloco de todo o pendrive e lê de volta para checar se o dado permaneceu íntegro. **Esse teste apaga 100% dos arquivos.**

---

## 3. Entendendo os Logs do Kernel (`dmesg`)

Quando um pendrive apresenta instabilidade, uma excelente fonte de informação adicional no terminal é o buffer do kernel:

```bash
sudo dmesg -w
```

* **Mensagem normal**: Exibe a enumeração USB com alta velocidade (`SuperSpeed USB` ou `High-Speed USB`), capacidade correta e partição atribuída.
* **Mensagem de erro de hardware**:
  * `Buffer I/O error on dev sdb`: O chip flash falhou ao ler ou gravar no setor.
  * `USB disconnect, device number ... reset high-speed USB device`: A controladora USB está reiniciando devido a pico de corrente ou falha elétrica no conector.
