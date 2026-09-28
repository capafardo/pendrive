#!/usr/bin/env bash
# ==============================================================================
# Script: iniciar.sh
# Descrição: Diagnóstico, verificação e reparo de pendrives/mídias removíveis
# Autor: Antigravity
# ==============================================================================

# Cores para o terminal
VERMELHO='\033[1;31m'
VERDE='\033[1;32m'
AMARELO='\033[1;33m'
AZUL='\033[1;34m'
CIANO='\033[1;36m'
SEM_COR='\033[0m'
NEGRITO='\033[1m'

# Variável global para armazenar o dispositivo selecionado
DISPOSITIVO_ATUAL=""
PARTICAO_ATUAL=""

# Checagem de privilégios de superusuário (root)
verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${VERMELHO}[ERRO] Este script precisa ser executado como root ou com sudo.${SEM_COR}"
        echo -e "Exemplo: ${AMARELO}sudo $0${SEM_COR}"
        exit 1
    fi
}

# Pausa para o usuário ler o resultado
pausar() {
    echo ""
    read -rp "Pressione [ENTER] para continuar..."
}

# Cabeçalho padrão
cabecalho() {
    clear
    echo -e "${CIANO}============================================================${SEM_COR}"
    echo -e "${NEGRITO}           FERRAMENTA DE DIAGNÓSTICO E REPARO DE PENDRIVES   ${SEM_COR}"
    echo -e "${CIANO}============================================================${SEM_COR}"
    if [[ -n "$DISPOSITIVO_ATUAL" ]]; then
        echo -e " Dispositivo selecionado: ${VERDE}${DISPOSITIVO_ATUAL}${SEM_COR}"
        if [[ -n "$PARTICAO_ATUAL" ]]; then
            echo -e " Partição selecionada:    ${VERDE}${PARTICAO_ATUAL}${SEM_COR}"
        fi
        echo -e "${CIANO}------------------------------------------------------------${SEM_COR}"
    fi
}

# Listar unidades removíveis/USB com segurança
listar_dispositivos_usb() {
    echo -e "${AMARELO}Dispositivos USB / Removíveis detectados:${SEM_COR}\n"
    
    # Lista dispositivos com TRAN=usb ou RM=1 (removíveis)
    lsblk -d -e 7,11 -o NAME,SIZE,TRAN,RM,MODEL,VENDOR,TYPE | grep -E "usb|1" || true
    echo ""
    echo -e "${CIANO}Partições e pontos de montagem:${SEM_COR}"
    lsblk -e 7,11 -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    echo ""
}

# Proteção contra seleção de discos do sistema
is_disco_sistema() {
    local dev="$1"
    # Checa se o dispositivo contém a raiz (/) ou partição boot/home
    if lsblk -no MOUNTPOINTS "$dev" 2>/dev/null | grep -qE '^/($|boot|home|usr|etc)'; then
        return 0 # É disco do sistema
    fi
    return 1 # Não é disco crítico do sistema
}

# Menu de seleção de dispositivo
selecionar_dispositivo() {
    while true; do
        cabecalho
        listar_dispositivos_usb

        echo -e "Digite o identificador do pendrive (ex: ${AMARELO}sdb${SEM_COR}, ${AMARELO}sdc${SEM_COR}) ou ${NEGRITO}0${SEM_COR} para voltar:"
        read -rp "Dispositivo: " entrada

        if [[ "$entrada" == "0" ]]; then
            return 0
        fi

        # Remove prefixo /dev/ se o usuário digitou
        entrada="${entrada#/dev/}"

        if [[ -z "$entrada" || ! -b "/dev/$entrada" ]]; then
            echo -e "${VERMELHO}[ERRO] O dispositivo '/dev/$entrada' não existe ou é inválido!${SEM_COR}"
            pausar
            continue
        fi

        local alvo="/dev/$entrada"

        # Verificação de segurança: não permitir o disco raiz do sistema
        if is_disco_sistema "$alvo"; then
            echo -e "${VERMELHO}[ALERTA MÁXIMO] O dispositivo $alvo contém partições vitais do sistema (como / ou /boot)!${SEM_COR}"
            echo -e "${VERMELHO}Operação cancelada por motivos de segurança.${SEM_COR}"
            pausar
            continue
        fi

        # Se o usuário escolheu uma partição (ex: sdb1) ou o disco inteiro (ex: sdb)
        local tipo
        tipo=$(lsblk -no TYPE "$alvo" 2>/dev/null)

        if [[ "$tipo" == "disk" ]]; then
            DISPOSITIVO_ATUAL="$alvo"
            # Tenta pegar a primeira partição por padrão, se existir
            local primeira_part
            primeira_part=$(lsblk -nlo NAME "$alvo" | tail -n +2 | head -n 1)
            if [[ -n "$primeira_part" ]]; then
                PARTICAO_ATUAL="/dev/$primeira_part"
            else
                PARTICAO_ATUAL=""
            fi
        elif [[ "$tipo" == "part" ]]; then
            PARTICAO_ATUAL="$alvo"
            # Obtém o disco pai
            local disco_pai
            disco_pai=$(lsblk -no PKNAME "$alvo")
            DISPOSITIVO_ATUAL="/dev/$disco_pai"
        else
            DISPOSITIVO_ATUAL="$alvo"
            PARTICAO_ATUAL=""
        fi

        echo -e "${VERDE}[OK] Dispositivo selecionado: $DISPOSITIVO_ATUAL (Partição padrão: ${PARTICAO_ATUAL:-Nenhuma})${SEM_COR}"
        pausar
        break
    done
}

# Exigir que um dispositivo esteja selecionado
garantir_selecao() {
    if [[ -z "$DISPOSITIVO_ATUAL" || ! -b "$DISPOSITIVO_ATUAL" ]]; then
        echo -e "${AMARELO}[AVISO] Nenhum pendrive selecionado no momento.${SEM_COR}"
        echo -e "Você será redirecionado para a seleção de dispositivo."
        pausar
        selecionar_dispositivo
        [[ -n "$DISPOSITIVO_ATUAL" && -b "$DISPOSITIVO_ATUAL" ]]
        return $?
    fi
    return 0
}

# Desmontar todas as partições do dispositivo
desmontar_pendrive() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${AMARELO}Desmontando todas as partições de $DISPOSITIVO_ATUAL...${SEM_COR}"
    
    local sucesso=true
    for part in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
        local part_path="/dev/$part"
        if mountpoint -q "$part_path" 2>/dev/null || grep -qs "$part_path" /proc/mounts; then
            echo -e "Desmontando ${part_path}..."
            if umount "$part_path" 2>/dev/null; then
                echo -e "${VERDE}✔ Desmontado com sucesso: ${part_path}${SEM_COR}"
            else
                echo -e "${VERMELHO}✖ Falha ao desmontar: ${part_path}. Tentando 'umount -f'...${SEM_COR}"
                umount -f "$part_path" 2>/dev/null || sucesso=false
            fi
        else
            echo -e "Partição ${part_path} já está desmontada."
        fi
    done

    # Sincroniza buffers
    sync

    if $sucesso; then
        echo -e "\n${VERDE}[SUCESSO] Todas as partições estão desmontadas e prontas para verificação.${SEM_COR}"
    else
        echo -e "\n${VERMELHO}[ATENÇÃO] Algumas partições ainda podem estar em uso.${SEM_COR}"
    fi
    pausar
}

# Escolher qual partição específica usar
escolher_particao() {
    local parts
    mapfile -t parts < <(lsblk -lno NAME,SIZE,FSTYPE,LABEL "$DISPOSITIVO_ATUAL" | tail -n +2)

    if [[ ${#parts[@]} -eq 0 ]]; then
        echo -e "${AMARELO}Nenhuma partição encontrada em $DISPOSITIVO_ATUAL. O disco pode não estar particionado.${SEM_COR}"
        PARTICAO_ATUAL=""
        return 1
    fi

    echo -e "\nPartições disponíveis em ${DISPOSITIVO_ATUAL}:"
    local i=1
    for p in "${parts[@]}"; do
        echo -e "  [$i] /dev/$p"
        ((i++))
    done
    echo -e "  [0] Voltar"

    echo ""
    read -rp "Escolha a partição (1-${#parts[@]}) ou 0 para voltar: " escolha_part
    if [[ "$escolha_part" == "0" || -z "$escolha_part" ]]; then
        return 1
    fi

    if [[ "$escolha_part" =~ ^[0-9]+$ ]] && (( escolha_part >= 1 && escolha_part <= ${#parts[@]} )); then
        local nome_p
        nome_p=$(echo "${parts[$((escolha_part - 1))]}" | awk '{print $1}')
        PARTICAO_ATUAL="/dev/$nome_p"
        echo -e "${VERDE}Partição selecionada: $PARTICAO_ATUAL${SEM_COR}"
        return 0
    else
        echo -e "${VERMELHO}Opção inválida!${SEM_COR}"
        return 1
    fi
}

# Verificar integridade sem modificar (Read-only check)
verificar_sistema_arquivos() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${CIANO}--- VERIFICAÇÃO DE SISTEMA DE ARQUIVOS (SOMENTE LEITURA) ---${SEM_COR}\n"
    
    escolher_particao || return 0
    
    # Desmonta antes de rodar fsck
    umount "$PARTICAO_ATUAL" 2>/dev/null || true

    local fstype
    fstype=$(lsblk -no FSTYPE "$PARTICAO_ATUAL")
    echo -e "Tipo de sistema de arquivos detectado: ${AMARELO}${fstype:-Desconhecido}${SEM_COR}"
    echo -e "Iniciando verificação não-destrutiva em ${PARTICAO_ATUAL}...\n"

    case "${fstype,,}" in
        vfat|fat|fat32|msdos)
            echo -e "${CIANO}Executando: dosfsck -v -n $PARTICAO_ATUAL${SEM_COR}"
            dosfsck -v -n "$PARTICAO_ATUAL"
            ;;
        ntfs)
            echo -e "${CIANO}Executando: ntfsfix -n $PARTICAO_ATUAL${SEM_COR}"
            ntfsfix -n "$PARTICAO_ATUAL"
            ;;
        ext2|ext3|ext4)
            echo -e "${CIANO}Executando: e2fsck -v -n $PARTICAO_ATUAL${SEM_COR}"
            e2fsck -v -n "$PARTICAO_ATUAL"
            ;;
        exfat)
            if command -v fsck.exfat &>/dev/null; then
                echo -e "${CIANO}Executando: fsck.exfat $PARTICAO_ATUAL${SEM_COR}"
                fsck.exfat "$PARTICAO_ATUAL"
            else
                echo -e "${AMARELO}'fsck.exfat' não instalado. Tentando fsck padrão...${SEM_COR}"
                fsck -n "$PARTICAO_ATUAL"
            fi
            ;;
        *)
            echo -e "${CIANO}Executando fsck genérico em modo de checagem: fsck -n $PARTICAO_ATUAL${SEM_COR}"
            fsck -n "$PARTICAO_ATUAL"
            ;;
    esac

    echo -e "\n${VERDE}[CONCLUÍDO] Diagnóstico finalizado.${SEM_COR}"
    pausar
}

# Reparar o sistema de arquivos da partição
reparar_sistema_arquivos() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${VERMELHO}--- CORREÇÃO E REPARO DE SISTEMA DE ARQUIVOS ---${SEM_COR}\n"
    escolher_particao || return 0

    # Desmonta com certeza
    umount "$PARTICAO_ATUAL" 2>/dev/null || true

    local fstype
    fstype=$(lsblk -no FSTYPE "$PARTICAO_ATUAL")
    echo -e "Partição: ${AMARELO}$PARTICAO_ATUAL${SEM_COR}"
    echo -e "Tipo detectado: ${AMARELO}${fstype:-Desconhecido}${SEM_COR}\n"

    echo -e "${AMARELO}Deseja realmente iniciar a reparação em $PARTICAO_ATUAL? [s/N]${SEM_COR}"
    read -rp "Opção: " confirma
    if [[ ! "$confirma" =~ ^[sS]$ ]]; then
        echo -e "Operação cancelada pelo usuário."
        pausar
        return 0
    fi

    echo -e "\n${CIANO}Iniciando procedimento de reparo...${SEM_COR}\n"

    case "${fstype,,}" in
        vfat|fat|fat32|msdos)
            echo -e "${CIANO}Opções do dosfsck: Reparar interativamente (-r) ou automaticamente (-a)?"
            echo -e "  [1] Automático (-a)"
            echo -e "  [2] Interativo (-r)"
            echo -e "  [0] Voltar"
            read -rp "Escolha: " opt_fat
            case "$opt_fat" in
                1) dosfsck -v -a -w "$PARTICAO_ATUAL" ;;
                2) dosfsck -v -r "$PARTICAO_ATUAL" ;;
                *) echo "Reparo cancelado."; pausar; return 0 ;;
            esac
            ;;
        ntfs)
            echo -e "${CIANO}Executando reparo NTFS com ntfsfix: ntfsfix -b -d $PARTICAO_ATUAL${SEM_COR}"
            ntfsfix -b -d "$PARTICAO_ATUAL"
            ;;
        ext2|ext3|ext4)
            echo -e "${CIANO}Executando reparo ext com e2fsck: e2fsck -p -f -v $PARTICAO_ATUAL${SEM_COR}"
            e2fsck -p -f -v "$PARTICAO_ATUAL" || {
                echo -e "${AMARELO}A correção automática indicou necessidade de intervenção interativa.${SEM_COR}"
                read -rp "Deseja executar 'e2fsck -y -f -v' para forçar correções? [s/N]: " conf_ext
                if [[ "$conf_ext" =~ ^[sS]$ ]]; then
                    e2fsck -y -f -v "$PARTICAO_ATUAL"
                fi
            }
            ;;
        exfat)
            if command -v fsck.exfat &>/dev/null; then
                echo -e "${CIANO}Executando: fsck.exfat -p $PARTICAO_ATUAL${SEM_COR}"
                fsck.exfat -p "$PARTICAO_ATUAL" || fsck.exfat -a "$PARTICAO_ATUAL"
            else
                echo -e "${CIANO}Executando: fsck -y $PARTICAO_ATUAL${SEM_COR}"
                fsck -y "$PARTICAO_ATUAL"
            fi
            ;;
        *)
            echo -e "${CIANO}Executando fsck com tentativa automática: fsck -y $PARTICAO_ATUAL${SEM_COR}"
            fsck -y "$PARTICAO_ATUAL"
            ;;
    esac

    # Sincroniza os discos
    sync
    echo -e "\n${VERDE}[CONCLUÍDO] Processo de reparo finalizado.${SEM_COR}"
    pausar
}

# Verificar setores defeituosos (badblocks)
verificar_badblocks() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${CIANO}--- TESTE DE SETORES DEFEITUOSOS (BADBLOCKS) ---${SEM_COR}\n"
    echo -e "Dispositivo completo: ${AMARELO}$DISPOSITIVO_ATUAL${SEM_COR}"
    
    echo -e "\nEscolha o tipo de teste:"
    echo -e "  [1] Teste de Leitura Rápido/Padrão (Seguro, NÃO apaga dados)"
    echo -e "  [2] Teste Destrutivo Completo de Leitura e Escrita (AVISO: ${VERMELHO}APAGA TODOS OS DADOS${SEM_COR})"
    echo -e "  [0] Voltar"
    echo ""
    read -rp "Opção: " tipo_bad

    case "$tipo_bad" in
        0) return 0 ;;
        1)
            # Desmonta tudo antes
            for p in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
                umount "/dev/$p" 2>/dev/null || true
            done
            echo -e "\n${CIANO}Iniciando teste de leitura em $DISPOSITIVO_ATUAL (isso pode demorar alguns minutos)...${SEM_COR}\n"
            badblocks -s -v -b 4096 "$DISPOSITIVO_ATUAL"
            ;;
        2)
            echo -e "\n${VERMELHO}[ATENÇÃO] Este teste grava padrões em cada bloco do pendrive e IRÁ APAGAR TUDO!${SEM_COR}"
            read -rp "Tem absoluta certeza que deseja continuar? Digite 'CONFIRMAR': " conf_bad
            if [[ "$conf_bad" != "CONFIRMAR" ]]; then
                echo -e "Operação abortada."
                pausar
                return 0
            fi
            # Desmonta tudo
            for p in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
                umount -f "/dev/$p" 2>/dev/null || true
            done
            echo -e "\n${VERMELHO}Iniciando badblocks destrutivo (leitura/escrita)...${SEM_COR}\n"
            badblocks -w -s -v -b 4096 "$DISPOSITIVO_ATUAL"
            ;;
        *)
            echo -e "${VERMELHO}Opção inválida!${SEM_COR}"
            ;;
    esac

    pausar
}

# Formatação e recriação de partição
formatar_pendrive() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${VERMELHO}============================================================${SEM_COR}"
    echo -e "${VERMELHO}               FORMATAÇÃO DE PENDRIVE                      ${SEM_COR}"
    echo -e "${VERMELHO}============================================================${SEM_COR}\n"
    echo -e "Dispositivo selecionado: ${AMARELO}$DISPOSITIVO_ATUAL${SEM_COR}"
    echo -e "${VERMELHO}[AVISO] Todos os dados em $DISPOSITIVO_ATUAL serão permanentemente apagados!${SEM_COR}\n"

    echo -e "Escolha o sistema de arquivos para a formatação:"
    echo -e "  [1] FAT32 (Compatibilidade máxima: Windows, Linux, Mac, TV, Som)"
    echo -e "  [2] NTFS  (Compatível com Windows/Linux, suporta arquivos > 4GB)"
    echo -e "  [3] exFAT (Compatível com Windows/Mac/Linux moderno, sem limite de 4GB)"
    echo -e "  [4] EXT4  (Padrão Linux nativo, com permissões de usuário)"
    echo -e "  [0] Voltar"
    echo ""
    read -rp "Opção: " opt_format

    if [[ "$opt_format" == "0" ]]; then
        return 0
    fi

    local fstype_cmd=""
    local rotulo_padrao="MEU_USB"

    case "$opt_format" in
        1) fstype_cmd="vfat"; rotulo_padrao="PENDRIVE" ;;
        2) fstype_cmd="ntfs"; rotulo_padrao="PENDRIVE" ;;
        3) fstype_cmd="exfat"; rotulo_padrao="PENDRIVE" ;;
        4) fstype_cmd="ext4"; rotulo_padrao="pendrive" ;;
        *) echo -e "${VERMELHO}Opção inválida.${SEM_COR}"; pausar; return 0 ;;
    esac

    read -rp "Nome/Rótulo do pendrive (padrão: $rotulo_padrao): " rotulo
    rotulo="${rotulo:-$rotulo_padrao}"
    # Remove espaços do rótulo para evitar erros
    rotulo="${rotulo// /_}"

    echo -e "\n${VERMELHO}Tem certeza que deseja apagar e formatar $DISPOSITIVO_ATUAL em $fstype_cmd com rótulo '$rotulo'? [s/N]${SEM_COR}"
    read -rp "Confirmação: " conf_format
    if [[ ! "$conf_format" =~ ^[sS]$ ]]; then
        echo -e "Formatação cancelada."
        pausar
        return 0
    fi

    # Desmonta tudo
    echo -e "\n${CIANO}1. Desmontando partições existentes...${SEM_COR}"
    for p in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
        umount -f "/dev/$p" 2>/dev/null || true
    done

    # Limpar tabela de partição antiga (wipefs)
    echo -e "${CIANO}2. Limpando assinaturas anteriores do disco...${SEM_COR}"
    wipefs -a "$DISPOSITIVO_ATUAL" &>/dev/null || true

    # Criar nova tabela MBR (msdos) e 1 partição ocupando 100%
    echo -e "${CIANO}3. Criando nova tabela de partição MBR...${SEM_COR}"
    parted -s "$DISPOSITIVO_ATUAL" mklabel msdos
    
    local part_type="primary"
    if [[ "$fstype_cmd" == "vfat" ]]; then
        parted -s -a optimal "$DISPOSITIVO_ATUAL" mkpart "$part_type" fat32 1MiB 100%
    elif [[ "$fstype_cmd" == "ntfs" ]]; then
        parted -s -a optimal "$DISPOSITIVO_ATUAL" mkpart "$part_type" ntfs 1MiB 100%
    elif [[ "$fstype_cmd" == "exfat" ]]; then
        parted -s -a optimal "$DISPOSITIVO_ATUAL" mkpart "$part_type" 1MiB 100%
    else
        parted -s -a optimal "$DISPOSITIVO_ATUAL" mkpart "$part_type" ext4 1MiB 100%
    fi

    # Notifica o kernel sobre as novas partições
    udevadm settle 2>/dev/null || sleep 2
    partprobe "$DISPOSITIVO_ATUAL" 2>/dev/null || sleep 2
    sleep 1

    # Identificar a nova partição
    local nova_part
    nova_part=$(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2 | head -n 1)

    if [[ -z "$nova_part" ]]; then
        nova_part="${DISPOSITIVO_ATUAL}1"
    else
        nova_part="/dev/$nova_part"
    fi

    echo -e "${CIANO}4. Formatando partição $nova_part com $fstype_cmd...${SEM_COR}"
    case "$fstype_cmd" in
        vfat)
            mkfs.vfat -F 32 -n "$rotulo" "$nova_part"
            ;;
        ntfs)
            mkfs.ntfs -f -L "$rotulo" "$nova_part"
            ;;
        exfat)
            mkfs.exfat -n "$rotulo" "$nova_part"
            ;;
        ext4)
            mkfs.ext4 -F -L "$rotulo" "$nova_part"
            ;;
    esac

    sync
    PARTICAO_ATUAL="$nova_part"
    echo -e "\n${VERDE}[SUCESSO] Pendrive formatado com sucesso!${SEM_COR}"
    echo -e "Partição: ${AMARELO}$PARTICAO_ATUAL${SEM_COR} | Rótulo: ${AMARELO}$rotulo${SEM_COR}"
    pausar
}

# Restaurar pendrive zerando os primeiros MB (útil para pendrive "invisível" ou corrompido)
zerar_tabela_mbr() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${VERMELHO}--- ZERAR CABEÇALHO / MBR (REVIVER PENDRIVE TRAVADO) ---${SEM_COR}\n"
    echo -e "Esta função grava zeros nos primeiros 10MB do pendrive ($DISPOSITIVO_ATUAL),"
    echo -e "eliminando tabelas corrompidas e estruturas travadas do disco.\n"
    echo -e "${VERMELHO}[ATENÇÃO] TODOS OS DADOS SERÃO PERDIDOS!${SEM_COR}\n"

    read -rp "Deseja prosseguir? Digite 'ZERAR' para confirmar ou 0 para voltar: " resp_zerar
    if [[ "$resp_zerar" == "0" || "$resp_zerar" != "ZERAR" ]]; then
        echo -e "Operação cancelada."
        pausar
        return 0
    fi

    # Desmonta tudo
    for p in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
        umount -f "/dev/$p" 2>/dev/null || true
    done

    echo -e "\n${CIANO}Zerando os primeiros 10MB de $DISPOSITIVO_ATUAL...${SEM_COR}"
    dd if=/dev/zero of="$DISPOSITIVO_ATUAL" bs=1M count=10 status=progress conv=fsync

    echo -e "${CIANO}Criando nova tabela de partição padrão (msdos/MBR)...${SEM_COR}"
    parted -s "$DISPOSITIVO_ATUAL" mklabel msdos
    parted -s -a optimal "$DISPOSITIVO_ATUAL" mkpart primary fat32 1MiB 100%

    udevadm settle 2>/dev/null || sleep 2
    partprobe "$DISPOSITIVO_ATUAL" 2>/dev/null || sleep 2
    sleep 1

    local nova_p
    nova_p=$(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2 | head -n 1)
    if [[ -n "$nova_p" ]]; then
        nova_p="/dev/$nova_p"
        echo -e "${CIANO}Formatando nova partição como FAT32...${SEM_COR}"
        mkfs.vfat -F 32 -n "PENDRIVE" "$nova_p"
        PARTICAO_ATUAL="$nova_p"
    fi

    sync
    echo -e "\n${VERDE}[CONCLUÍDO] Disco zerado e reinicializado com sucesso!${SEM_COR}"
    pausar
}

# Gravar imagem ISO no pendrive (Criar pendrive inicializável / bootável)
gravar_imagem_iso() {
    cabecalho
    garantir_selecao || return 0

    # Certificar que a operação será no disco inteiro (/dev/sdX) e não em partição isolada
    local disco_alvo="$DISPOSITIVO_ATUAL"
    local tipo_dev
    tipo_dev=$(lsblk -no TYPE "$disco_alvo" 2>/dev/null)
    if [[ "$tipo_dev" == "part" ]]; then
        local pk
        pk=$(lsblk -no PKNAME "$disco_alvo" 2>/dev/null)
        if [[ -n "$pk" ]]; then
            disco_alvo="/dev/$pk"
        fi
    fi

    # Proteção de segurança contra discos de sistema
    if is_disco_sistema "$disco_alvo"; then
        echo -e "${VERMELHO}[ALERTA MÁXIMO] $disco_alvo contém partições vitais do sistema! Operação abortada.${SEM_COR}"
        pausar
        return 1
    fi

    echo -e "${CIANO}--- GRAVAR IMAGEM ISO / CRIAR PENDRIVE BOOTÁVEL ---${SEM_COR}\n"
    echo -e "Esta função grava uma imagem (.iso ou .img) diretamente no pendrive:"
    echo -e "Dispositivo de destino: ${VERDE}${disco_alvo}${SEM_COR}"
    echo -e "Capacidade do pendrive: ${AMARELO}$(lsblk -dn -o SIZE "$disco_alvo" 2>/dev/null)${SEM_COR}\n"
    echo -e "${VERMELHO}[ATENÇÃO] TODAS AS PARTIÇÕES E DADOS DO PENDRIVE SERÃO APAGADOS!${SEM_COR}\n"
    echo -e "Dica: Você pode arrastar o arquivo ISO para o terminal ou usar [Tab] para autocompletar."
    echo -e "Digite ${NEGRITO}0${SEM_COR} a qualquer momento para cancelar.\n"

    local caminho_iso=""
    while true; do
        read -e -rp "Caminho do arquivo ISO: " caminho_iso

        if [[ "$caminho_iso" == "0" ]]; then
            echo -e "Operação cancelada."
            pausar
            return 0
        fi

        # Remove aspas caso o usuário tenha arrastado o arquivo para o terminal
        caminho_iso="${caminho_iso#\'}"
        caminho_iso="${caminho_iso%\'}"
        caminho_iso="${caminho_iso#\"}"
        caminho_iso="${caminho_iso%\"}"
        
        # Expande ~ caso exista
        eval caminho_iso="$caminho_iso" 2>/dev/null || true

        if [[ -z "$caminho_iso" || ! -f "$caminho_iso" ]]; then
            echo -e "${VERMELHO}[ERRO] Arquivo não encontrado ou inválido: '$caminho_iso'${SEM_COR}\n"
            continue
        fi

        if [[ ! -r "$caminho_iso" ]]; then
            echo -e "${VERMELHO}[ERRO] Sem permissão para ler o arquivo: '$caminho_iso'${SEM_COR}\n"
            continue
        fi

        break
    done

    # Comparar tamanho da imagem com a capacidade do disco
    local tam_iso_bytes tam_disco_bytes
    tam_iso_bytes=$(stat -c%s "$caminho_iso" 2>/dev/null || wc -c < "$caminho_iso")
    tam_disco_bytes=$(lsblk -bno SIZE "$disco_alvo" 2>/dev/null | head -n 1)

    local tam_iso_hum tam_disco_hum
    tam_iso_hum=$(numfmt --to=iec-i --suffix=B "$tam_iso_bytes" 2>/dev/null || ls -lh "$caminho_iso" | awk '{print $5}')
    tam_disco_hum=$(lsblk -dno SIZE "$disco_alvo" 2>/dev/null)

    echo ""
    echo -e "Arquivo de imagem:      ${VERDE}$caminho_iso${SEM_COR} (${tam_iso_hum})"
    echo -e "Pendrive de destino:    ${AMARELO}$disco_alvo${SEM_COR} (${tam_disco_hum})"

    if [[ -n "$tam_disco_bytes" && "$tam_iso_bytes" -gt "$tam_disco_bytes" ]]; then
        echo -e "\n${VERMELHO}[ERRO CRÍTICO] A imagem ISO ($tam_iso_hum) é maior que a capacidade do pendrive ($tam_disco_hum)!${SEM_COR}"
        echo -e "A gravação não pode ser realizada."
        pausar
        return 1
    fi

    echo ""
    echo -e "${VERMELHO}Para confirmar a destruição dos dados em $disco_alvo e a gravação da ISO,${SEM_COR}"
    read -rp "digite exatamente 'GRAVAR' ou '0' para cancelar: " confirmacao

    if [[ "$confirmacao" != "GRAVAR" ]]; then
        echo -e "Operação cancelada pelo usuário."
        pausar
        return 0
    fi

    # Desmonta todas as partições do pendrive antes de gravar
    echo -e "\n${AMARELO}1. Desmontando partições ativas de $disco_alvo...${SEM_COR}"
    for p in $(lsblk -lno NAME "$disco_alvo" 2>/dev/null | tail -n +2); do
        umount -f "/dev/$p" 2>/dev/null || true
    done

    echo -e "${CIANO}2. Gravando imagem ISO em $disco_alvo via dd...${SEM_COR}"
    echo -e "Aguarde, este processo pode levar alguns minutos dependendo da velocidade da porta e da mídia.\n"

    if dd if="$caminho_iso" of="$disco_alvo" bs=4M status=progress oflag=sync; then
        echo -e "\n${CIANO}3. Sincronizando buffers de disco (sync)...${SEM_COR}"
        sync
        udevadm settle 2>/dev/null || sleep 2
        partprobe "$disco_alvo" 2>/dev/null || true

        # Atualizar partição selecionada
        local p1
        p1=$(lsblk -lno NAME "$disco_alvo" 2>/dev/null | tail -n +2 | head -n 1)
        if [[ -n "$p1" ]]; then
            PARTICAO_ATUAL="/dev/$p1"
        else
            PARTICAO_ATUAL=""
        fi

        echo -e "\n${VERDE}============================================================${SEM_COR}"
        echo -e "${VERDE}[SUCESSO] Imagem ISO gravada com sucesso em $disco_alvo!${SEM_COR}"
        echo -e "${VERDE}Seu pendrive agora é inicializável (bootável).${SEM_COR}"
        echo -e "${VERDE}============================================================${SEM_COR}"
        echo -e "${AMARELO}Nota:${SEM_COR} Para restaurar este pendrive para uso normal no futuro,"
        echo -e "utilize a Opção [8] (Zerar Tabela / Reviver Pendrive Travado)."
    else
        echo -e "\n${VERMELHO}[ERRO] Falha durante a gravação da imagem ISO no dispositivo.${SEM_COR}"
    fi

    pausar
}

# Teste simples de velocidade de escrita e leitura
teste_velocidade() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${CIANO}--- TESTE DE DESEMPENHO (LEITURA E ESCRITA) ---${SEM_COR}\n"
    escolher_particao || return 0

    local ponto_montagem
    ponto_montagem=$(lsblk -no MOUNTPOINT "$PARTICAO_ATUAL" | head -n 1)

    local montado_temporariamente=false
    if [[ -z "$ponto_montagem" ]]; then
        ponto_montagem="/mnt/teste_pendrive_$$"
        mkdir -p "$ponto_montagem"
        echo -e "Montando $PARTICAO_ATUAL em $ponto_montagem para o teste..."
        if ! mount "$PARTICAO_ATUAL" "$ponto_montagem" 2>/dev/null; then
            echo -e "${VERMELHO}Não foi possível montar $PARTICAO_ATUAL. O sistema de arquivos pode estar corrompido.${SEM_COR}"
            rmdir "$ponto_montagem" 2>/dev/null || true
            pausar
            return 0
        fi
        montado_temporariamente=true
    fi

    local arq_teste="${ponto_montagem}/.teste_velocidade_temp.bin"

    echo -e "\n${AMARELO}1. Testando velocidade de ESCRITA (gravando arquivo temporário de 100MB)...${SEM_COR}"
    dd if=/dev/zero of="$arq_teste" bs=1M count=100 conv=fdatasync status=progress

    echo -e "\n${AMARELO}2. Limpando cache do sistema...${SEM_COR}"
    sync; echo 3 > /proc/sys/vm/drop_caches

    echo -e "\n${AMARELO}3. Testando velocidade de LEITURA (lendo arquivo gravado)...${SEM_COR}"
    dd if="$arq_teste" of=/dev/null bs=1M count=100 status=progress

    # Limpeza
    rm -f "$arq_teste"
    sync

    if $montado_temporariamente; then
        umount "$ponto_montagem" 2>/dev/null || true
        rmdir "$ponto_montagem" 2>/dev/null || true
    fi

    echo -e "\n${VERDE}[CONCLUÍDO] Teste de velocidade concluído.${SEM_COR}"
    pausar
}

# Ejetar / Desconectar com segurança
ejetar_pendrive() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${AMARELO}Desconectando e ejetando $DISPOSITIVO_ATUAL com segurança...${SEM_COR}\n"
    
    # Sincroniza dados pendentes
    echo -e "Sincronizando buffers de gravação (sync)..."
    sync

    # Desmonta partições
    for p in $(lsblk -lno NAME "$DISPOSITIVO_ATUAL" | tail -n +2); do
        echo -e "Desmontando /dev/$p..."
        umount -f "/dev/$p" 2>/dev/null || true
    done

    # Ejetar
    local ejetado=false
    if command -v udisksctl &>/dev/null; then
        if udisksctl power-off -b "$DISPOSITIVO_ATUAL" 2>/dev/null; then
            ejetado=true
        fi
    fi

    if ! $ejetado && command -v eject &>/dev/null; then
        if eject "$DISPOSITIVO_ATUAL" 2>/dev/null; then
            ejetado=true
        fi
    fi

    if $ejetado; then
        echo -e "\n${VERDE}[OK] O pendrive foi desligado/ejetado com segurança. Você pode removê-lo da porta USB.${SEM_COR}"
        DISPOSITIVO_ATUAL=""
        PARTICAO_ATUAL=""
    else
        echo -e "\n${AMARELO}[AVISO] Partições desmontadas e dados sincronizados. Remova o pendrive com segurança.${SEM_COR}"
    fi
    pausar
}

# Exibir informações completas do dispositivo
informacoes_dispositivo() {
    cabecalho
    garantir_selecao || return 0

    echo -e "${CIANO}--- INFORMAÇÕES DETALHADAS DO DISPOSITIVO ---${SEM_COR}\n"
    udevadm info --query=all --name="$DISPOSITIVO_ATUAL" | grep -E "ID_VENDOR|ID_MODEL|ID_FS_TYPE|ID_SERIAL|DEVNAME" || true
    echo ""
    fdisk -l "$DISPOSITIVO_ATUAL" 2>/dev/null || true
    echo ""
    blkid | grep "${DISPOSITIVO_ATUAL}" || true
    pausar
}

# Menu Principal
menu_principal() {
    while true; do
        cabecalho
        echo -e "  [1] Selecionar/Alterar Pendrive"
        echo -e "  [2] Ver Informações Detalhadas do Pendrive"
        echo -e "  [3] Desmontar Partições com Segurança"
        echo -e "  [4] Verificar Integridade do Sistema de Arquivos (Somente Leitura)"
        echo -e "  [5] Reparar Sistema de Arquivos (Corrigir Erros)"
        echo -e "  [6] Verificar Setores Defeituosos (Badblocks)"
        echo -e "  [7] Formatar Pendrive (FAT32, NTFS, exFAT ou EXT4)"
        echo -e "  [8] Zerar Tabela / Reviver Pendrive Travado (DD + Nova MBR)"
        echo -e "  [9] Gravar Imagem ISO no Pendrive (Criar Pendrive Bootável)"
        echo -e "  [10] Teste de Velocidade (Leitura e Escrita)"
        echo -e "  [11] Ejetar Pendrive com Segurança"
        echo -e "  ------------------------------------------------------------"
        echo -e "  [0] Sair"
        echo ""
        read -rp "Selecione uma opção [0-11]: " opcao

        case "$opcao" in
            1) selecionar_dispositivo ;;
            2) informacoes_dispositivo ;;
            3) desmontar_pendrive ;;
            4) verificar_sistema_arquivos ;;
            5) reparar_sistema_arquivos ;;
            6) verificar_badblocks ;;
            7) formatar_pendrive ;;
            8) zerar_tabela_mbr ;;
            9) gravar_imagem_iso ;;
            10) teste_velocidade ;;
            11) ejetar_pendrive ;;
            0) 
                echo -e "\n${VERDE}Saindo... Até logo!${SEM_COR}"
                exit 0
                ;;
            *)
                echo -e "\n${VERMELHO}Opção inválida! Escolha um número de 0 a 11.${SEM_COR}"
                pausar
                ;;
        esac
    done
}

# Início do programa
verificar_root
menu_principal
