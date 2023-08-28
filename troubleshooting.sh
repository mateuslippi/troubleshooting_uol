#!/usr/bin/env bash
#
# troubleshooting.sh - Automatização de ferramentas de troubleshooting.
#
# Autor:      Mateus Lippi
# Manutenção: Mateus Lippi
#
# ------------------------------------------------------------------------ #
# Este programa irá auxiliar os sysAdmins iniciantes e até mesmo os mais experientes a executarem
# comandos muito úteis para a realização de troubleshooting nos servidores Linux.
#
# Exemplos:
#     $ ./troubleshooting.sh --verificar-disco - Fará a verificação de uso de espaço em disco
#       e irá exibir o sistema de arquivos das partições.
# ------------------------------------------------------------------------ #
# Histórico:
#
#   v1.0 24/06/2023, Mateus:
#   v1.1 23/07/2023, Mateus: Adicionado a função "limpar_cache"
#   v1.2 26/07/2023, Mateus: Adicionado a possibilidade de passarmos multiplos arquivos de log para a função "--compactar-logs"
#   v1.3 26/07/2023, Mateus: Removido as funções "verificar_disco e scanear_rede" e adicionado a função "buscar_consumo"
#   v1.4 28/08/2023, Mateus: Adicionado a função "Liberar Inodes"
# ------------------------------------------------------------------------ #
# Testado em:
#   bash 5.1.16(1)-release
# -----------------------VARIÁVEIS ---------------------------------------- #
MENSAGEM_USO="
     $(basename "$0") - [OPÇÕES]

        -h, --ajuda - Menu de ajuda

        -v, --versao - Versão do programa

        -a, --compactar-logs ARQUIVO1 [ARQUIVO2 ARQUIVO3 ...] - Realiza a compactação dos arquivos de log especificados sem prejudicar o funcionamento do host e da aplicação em questão.

        -b, --buscar-consumo - Realiza a busca pelos 50 arquivos que mais ocupam espaço em disco do sistema.   

        -c, --checar-certificado CERTIFICADO - Realiza a checagem das principais informações de um certificado SSL.

        -d, --checar-dns URL - Realiza a checagem de registros DNS do tipo A da URL informada.

        -l, --limpar-cache - Realiza a limpeza de cache do YUM (Caso o sistema seja RHEL based), de logs do journalctl (Retendo apenas o do último dia)
            e força a rotação do logrotate.

        -i, --liberar-inodes - Realiza a liberação de inodes.

        -j, --lista-jumpers - Exibe uma lista de jumpers Linux.

        -z, --instalar-zabbix - Realiza a instalação completa do ZabbixAgent2 (Disponível por enquanto só para Ubuntu).        
        "

MENSAGEM_JUMPER="

    Lista de jumpers Linux:

    - jbpainfsr090.corp.tvglobo.com.br
    - operacao1.globoi.com
"

FLAG_CHECAR_CERTIFICADO=0
FLAG_INSTALAR_AGENTE2_ZABBIX=0
FLAG_CHECAR_DNS=0
FLAG_COMPACTAR_LOGS=0
FLAG_LIMPAR_CACHE=0
FLAG_BUSCAR_CONSUMO=0
FLAG_LIBERAR_INODES=0
# -----------------------FUNÇÕES-------------------------------------------- #

liberar_inodes() {
    ls -la /var/spool/clientmqueue | awk '{print "rm " $9}'|sh +
}

buscar_consumo() {
    # root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    find / -xdev -type f -size +5M -exec du -sh {} ';' | sort -rh | head -n50
}

limpar_cache() {
    # root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    # limpar cache yum

    # Rhel based?
    which yum > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        # Limpeza de cache do yum.
        yum clean packages && yum clean headers && yum clean metadata && yum clean all 
        wait
    fi
    # Remover os logs do journalctl, exceto o do último dia
    journalctl --vacuum-time=1
    wait

    # Forçar rotação de logs do logrotate
    logrotate -f /etc/logrotate.conf
}

compactar_logs() {
    # root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    for arquivo_log in "$@"; do
        # Checa se o arquivo passado como parâmetro realmente existe.
        if [ -e "$arquivo_log" ]; then
            gzip -f9c "$arquivo_log" > "$arquivo_log.$(date --rfc-3339=date).gz" && > "$arquivo_log"           
        else 
            echo "O arquivo $arquivo_log passado como parâmetro não existe" >&2 && exit 1
        fi
    done
}

checar_certificado() {
    curl -v --silent "https://$1" --stderr - | grep -i 'Server Certificate\|subject\|start date\|expire date'
}

checar_dns() {
    saida=$(dig "$1" +short)

    if [ -z "$saida" ]; then
        echo "Não existe um registro DNS do tipo A associado a este host."
        exit 0
    fi

    dig "$1" +short
}

instalar_agente2_zabbix () {
    # root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    # 10050 aberta?
    porta=10050
    ss -ln | grep -i "$porta" > /dev/null
    if [ $? -eq 0 ]; then
        echo "A porta $porta já está sendo utilizada. Por favor, realize o tratamento" >&2
        exit 1
    fi

    # Verificação do Ubuntu
    ubuntu_versao=$(grep -i "DISTRIB_RELEASE=" /etc/lsb-release | cut -d = -f 2)

    # Instalação dos repositórios
    wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu"$ubuntu_versao"_all.deb
    sudo dpkg -i zabbix-release_6.0-4+ubuntu"$ubuntu_versao"_all.deb
    sudo apt update

    # Instalação do Zabbix-Agent2
    apt install zabbix-agent2 zabbix-agent2-plugin-*

    # Inicialização pelo boot e start do zabbix-agent2
    systemctl enable zabbix-agent2
    systemctl restart zabbix-agent2

}

# ---------------------- EXECUÇÃO ----------------------------------------- #
lista_arquivos=()

# TRATAMENTO DE PARÂMETROS
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--ajuda)
            echo "$MENSAGEM_USO"
            exit 0
            ;;
        -v|--versao)
            echo "Versão 1.4"
            exit 0
            ;;
        -a|--compactar-logs)
            FLAG_COMPACTAR_LOGS=1
            shift
            # Coletar a lista de arquivos de log passados como parâmetros
            lista_arquivos=("$@")
            break
            ;;
        -b|--buscar-consumo)
            FLAG_BUSCAR_CONSUMO=1
            ;;            
        -c|--checar-certificado)
            FLAG_CHECAR_CERTIFICADO=1
            URL=$2
            # obs: O uso deste shift é necessário para que o programa não entenda o $2 como um novo "case", se não ele vai identificar como uma "Opção inválida".
            # afinal de contas, o "$2" neste caso é um parâmetro e não uma opção para o "case".
            shift
            ;;
        -d|--checar-dns)
            FLAG_CHECAR_DNS=1
            URL_DNS=$2
            shift
            ;;
        -l|--limpar-cache)
            FLAG_LIMPAR_CACHE=1
            ;;
        -i|--liberar-inodes)
            FLAG_LIBERAR_INODES=1
            ;;
        
        -j|--lista-jumpers)
            echo "$MENSAGEM_JUMPER"
            exit 0
            ;;
        -z|--instalar-zabbix)
            FLAG_INSTALAR_AGENTE2_ZABBIX=1
            ;;
        *)
            echo "Opção inválida: $1" >&2
            echo "$MENSAGEM_USO" >&2
            exit 1
            ;;
    esac
    # O uso deste shift é utilizado para descartar um "case" que já foi tratado e não deixar o programa em looping infinito.
    shift
done

# ATIVAÇÃO DE FUNÇÕES
if [ $FLAG_CHECAR_CERTIFICADO -eq 1 ]; then
    checar_certificado "$URL"
fi

if [ $FLAG_INSTALAR_AGENTE2_ZABBIX -eq 1 ]; then
    instalar_agente2_zabbix
fi

if [ $FLAG_CHECAR_DNS -eq 1 ]; then
    checar_dns "$URL_DNS"
fi

if [ $FLAG_COMPACTAR_LOGS -eq 1 ]; then
    compactar_logs "${lista_arquivos[@]}"
fi

if [ $FLAG_LIMPAR_CACHE -eq 1 ]; then
    limpar_cache
fi

if [ $FLAG_LIBERAR_INODES -eq 1 ]; then
    liberar_inodes
fi

if [ $FLAG_BUSCAR_CONSUMO -eq 1 ]; then
    buscar_consumo
fi
