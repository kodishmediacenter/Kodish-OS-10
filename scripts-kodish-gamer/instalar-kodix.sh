#!/bin/bash

FUNCAO_KODIX='
kodix() {
    if [ -z "$1" ]; then
        echo "kodix nome"
        return 1
    fi
    wget https://raw.githubusercontent.com/kodishmediacenter/kodix/refs/heads/main/$1.sh 
    clear	
    sh $1.sh	
}
'

# Detecta shell padrão
SHELL_NAME=$(basename "$SHELL")

if [ "$SHELL_NAME" = "zsh" ]; then
    ARQUIVO="$HOME/.zshrc"
else
    ARQUIVO="$HOME/.bashrc"
fi

# Verifica se já existe
if grep -q "kodix()" "$ARQUIVO"; then
    echo "Função nyaa já existe em $ARQUIVO"
else
    echo "$FUNCAO_KODIX" >> "$ARQUIVO"
    echo "Função adicionada em $ARQUIVO"
fi

echo "Reinicie o terminal ou rode:"
echo "source $ARQUIVO"
