#!/bin/bash

FUNCAO_NYAA='
nyaa() {
    if [[ -z "$1" ]]; then
        echo "Use: nyaa CODIGO"
        return 1
    fi

    flatpak run com.stremio.Stremio "https://nyaa.si/download/${1}.torrent"
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
if grep -q "nyaa()" "$ARQUIVO"; then
    echo "Função nyaa já existe em $ARQUIVO"
else
    echo "$FUNCAO_NYAA" >> "$ARQUIVO"
    echo "Função adicionada em $ARQUIVO"
fi

echo "Reinicie o terminal ou rode:"
echo "source $ARQUIVO"
