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
#     $ ./troubleshooting.sh -d - Fará a verificação de uso de espaço em disco
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

        -h - Menu de ajuda
        -v - Versão do programa
        -d - Realiza a verificação de espaço em disco e exibe
             o sistema de arquivos utilizado nas partições.
        -n - Realiza uma varredura de hosts na rede informada e envia
             para o arquivo 'hosts.txt'
        -j - Exibe uma lista de jumpers Linux.

        -z - Realiza a instalação completa do ZabbixAgent2 (Disponível por enquanto só para Ubuntu 20.04 LTS)
"
MENSAGEM_JUMPER="

    Lista de jumpers Linux:

    - jbpainfsr090.corp.tvglobo.com.br
    - operacao1.globoi.com
"

FLAG_VERIFICAR_DISCO=0
FLAG_SCANEAR_REDE=0
FLAG_CHECK_CERT=0
FLAG_ZABBIX_AGENT_INSTALL=0
# -----------------------TESTES--------------------------------------------- #

# root?
#[ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1
# -----------------------FUNÇÕES-------------------------------------------- #
verificar_disco() {
    df -hT
}

scanear_rede() {
    nmap "$1" > hosts.txt
}

check_certi() {
    curl -v --silent "$1" --stderr - | grep -i 'Server Certificate\|subject\|start date\|expire date'

}

#Função disponível por enquanto só para o Ubuntu 20.04 LTS
zabbix_agent_install () {
    #root?
    [ $UID -ne 0 ] && echo "Por favor, execute este programa como root" && exit 1

    #10050 aberta?
    porta=10050
    ss -ln | grep -i "$porta" > /dev/null
    if [ $? -eq 0 ]; then
        echo "A porta $porta já está sendo utilizada. Por favor, realize o tratamento"
        exit 1
    fi

    #Instação dos repositórios
    wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu20.04_all.deb
    sudo dpkg -i zabbix-release_6.0-4+ubuntu20.04_all.deb
    sudo apt update

    #Instalação do Zabbix-Agent2
    apt install zabbix-agent2 zabbix-agent2-plugin-*

    #Inicialização pelo boot e start do zabbix-agent2
    systemctl enalbe zabbix-agent2
    systemctl restart zabbix-agent2

}
# ---------------------- EXECUÇÃO ----------------------------------------- #
while getopts ":hjvdnzc:" opcao; do
    case $opcao in
        h)
            echo "$MENSAGEM_USO"
            exit 0
            ;;

        j)  
            echo "$MENSAGEM_JUMPER"
            exit 0
            ;;   
            
        v)
            echo "Versão 1.0"
            exit 0
            ;;
        d)
            FLAG_VERIFICAR_DISCO=1
            ;;
        n)
            FLAG_SCANEAR_REDE=1
            REDE=$OPTARG
            ;;

        z)
            FLAG_ZABBIX_AGENT_INSTALL=1
            ;;

        c)  FLAG_CHECK_CERT=1
            URL="https://$OPTARG"
            ;;

        \?)
            echo "Opção inválida: -$OPTARG" >&2
            echo "$MENSAGEM_USO" >&2
            exit 1
            ;;
    esac
done

# ATIVAÇÃO DE FUNÇÕES
if [ $FLAG_VERIFICAR_DISCO -eq 1 ]; then
    verificar_disco
fi

if [ $FLAG_SCANEAR_REDE -eq 1 ]; then
    scanear_rede "$REDE"
fi

if [ $FLAG_CHECK_CERT -eq 1 ]; then
    check_certi "$URL"
fi

if [ $FLAG_ZABBIX_AGENT_INSTALL -eq 1 ]; then
    zabbix_agent_install
fi
# ...
