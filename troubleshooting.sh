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
# ------------------------------------------------------------------------ #
# Testado em:
#   bash 5.1.16(1)-release
# -----------------------VARIÁVEIS ---------------------------------------- #
MENSAGEM_USO="
     $(basename "$0") - [OPÇÕES]

        -h, --ajuda - Menu de ajuda
        -v, --versao - Versão do programa
        -d, --verificar-disco - Realiza a verificação de espaço em disco e exibe
             o sistema de arquivos utilizado nas partições.
        -n, --scanear-rede REDE - Realiza uma varredura de hosts na rede informada e envia
             para o arquivo 'hosts.txt'
        -j, --lista-jumpers - Exibe uma lista de jumpers Linux.

        -z, --instalar-zabbix - Realiza a instalação completa do ZabbixAgent2 (Disponível por enquanto só para Ubuntu).

        --compactar-logs ARQUIVO - Realiza a compactação do arquivo de log especificado sem prejudicar o funcionamento do host e da aplicação em questão.
            obs: Por enquanto só funciona com apenas UM arquivo por vez!

        --checar-dns URL - Realiza a checagem de registros DNS do tipo A da URL informada."

MENSAGEM_JUMPER="

    Lista de jumpers Linux:

    - jbpainfsr090.corp.tvglobo.com.br
    - operacao1.globoi.com
"

FLAG_VERIFICAR_DISCO=0
FLAG_SCANEAR_REDE=0
FLAG_CHECAR_CERTIFICADO=0
FLAG_INSTALAR_AGENTE2_ZABBIX=0
FLAG_CHECAR_DNS=0
FLAG_COMPACTAR_LOGS=0
# -----------------------TESTES--------------------------------------------- #

# root?
#[ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1
# -----------------------FUNÇÕES-------------------------------------------- #
compactar_logs() {
    
    #root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    #Buscando os atributos do arquivo de log original
    permissao=$(stat -c "%a" "$1")
    usuario=$(stat -c "%U" "$1")
    grupo=$(stat -c "%G" "$1")

    #Comprime e "zera" o arquivo de log original, mantendo todas as permissões para o funcionamento correto da aplicação.
    gzip -f9c "$1" > "$1.$(date --rfc-3339=date).gz" && > "$1"
    chmod "$permissao" "$1"
    chown "$usuario":"$grupo" "$1"
}

verificar_disco() {
    df -hT
}

scanear_rede() {
    nmap "$1" > hosts.txt
}

checar_certificado() {
    curl -v --silent "https://$1" --stderr - | grep -i 'Server Certificate\|subject\|start date\|expire date'

}

checar_dns() {
    saida=$(dig $1 +short)

    if [ -z $saida ]; then
        echo "Não existe um registro DNS do tipo A associado a este host."
        exit 0
    fi

    dig $1 +short
}

#Função disponível por enquanto só para o Ubuntu 20.04 LTS
instalar_agente2_zabbix () {
    #root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    #10050 aberta?
    porta=10050
    ss -ln | grep -i "$porta" > /dev/null
    if [ $? -eq 0 ]; then
        echo "A porta $porta já está sendo utilizada. Por favor, realize o tratamento"
        exit 1
    fi

    #Verificação do Ubuntu
    ubuntu_versao=$(grep -i "DISTRIB_RELEASE=" /etc/lsb-release | cut -d = -f 2)

    #Instação dos repositórios
    wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu"$ubuntu_versao"_all.deb
    sudo dpkg -i zabbix-release_6.0-4+ubuntu"$ubuntu_versao"_all.deb
    sudo apt update

    #Instalação do Zabbix-Agent2
    apt install zabbix-agent2 zabbix-agent2-plugin-*

    #Inicialização pelo boot e start do zabbix-agent2
    systemctl enable zabbix-agent2
    systemctl restart zabbix-agent2

}
# ---------------------- EXECUÇÃO ----------------------------------------- #

#TRATAMENTO DE PARÂMETROS
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--ajuda)
            echo "$MENSAGEM_USO"
            exit 0
            ;;
        -j|--lista-jumpers)
            echo "$MENSAGEM_JUMPER"
            exit 0
            ;;
        -v|--versao)
            echo "Versão 1.0"
            exit 0
            ;;
        -d|--verificar-disco)
            FLAG_VERIFICAR_DISCO=1
            ;;
        -n|--scanear-rede)
            FLAG_SCANEAR_REDE=1
            REDE=$2
            shift
            ;;
        -z|--instalar-zabbix)
            FLAG_INSTALAR_AGENTE2_ZABBIX=1
            ;;
        -c|--checar-certificado)
            FLAG_CHECAR_CERTIFICADO=1
            URL=$2
            shift
            ;;
        --checar-dns)
            FLAG_CHECAR_DNS=1
            URL_DNS=$2
            shift
            ;;
        
        --compactar-logs)
            FLAG_COMPACTAR_LOGS=1
            ARQUIVO_LOG=$2
            shift
            ;;
        *)
            echo "Opção inválida: $1" >&2
            echo "$MENSAGEM_USO" >&2
            exit 1
            ;;
    esac
    shift
done


# ATIVAÇÃO DE FUNÇÕES
if [ $FLAG_VERIFICAR_DISCO -eq 1 ]; then
    verificar_disco
fi

if [ $FLAG_SCANEAR_REDE -eq 1 ]; then
    scanear_rede "$REDE"
fi

if [ $FLAG_CHECAR_CERTIFICADO -eq 1 ]; then
    checar_certificado "$URL"
fi

if [ $FLAG_INSTALAR_AGENTE2_ZABBIX -eq 1 ]; then
    instalar_agente2_zabbix
fi

if [ $FLAG_CHECAR_DNS -eq 1 ]; then
    checar_dns $URL_DNS
fi

if [ $FLAG_COMPACTAR_LOGS -eq 1 ]; then
    compactar_logs $ARQUIVO_LOG
fi