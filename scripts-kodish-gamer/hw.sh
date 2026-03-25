clear
echo Kodish Game OS 10 
echo
echo Hora
date "+%T"
echo 
echo Previsão do Tempo
curl -s wttr.in/Carapicuiba?format=3
echo
echo Endereço IP: 
ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk '{print $2}'
echo
echo Endereço IP na Internet 
curl ipinfo.io/ip
echo
echo
echo Arquitetura 
uname -m
echo 
echo Versão do Kernel 
uname -r
echo 
echo Consumo de Memoria RAM
free -h
echo 
echo Espaço em Disco e Partição
df -h

echo 
echo ========================================
echo
echo     F1 Radio 
echo     F2 Limpar Janela 
echo 	 F3 Update Pac e Flatpaks
echo     F4 Gerenciador de Tarefas 
echo 	 F5 Voltar para Smart Terminal
echo     F6 Update Flatpak e OS   
echo     F7 Gerenciar Comentarios
echo     F8 Abrir Canivete de IA 
echo
echo =========================================
echo ''