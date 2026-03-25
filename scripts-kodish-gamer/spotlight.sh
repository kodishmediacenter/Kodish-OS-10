#!/bin/bash

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

PASTA="$HOME/Imagens/Spotlight"
mkdir -p "$PASTA"

JSON=$(curl -s -H "User-Agent: WindowsShellClient/1.0" \
"https://fd.api.iris.microsoft.com/v4/api/selection?placement=88000820&bcnt=1&country=US&locale=en-US&fmt=json")

INNER=$(echo "$JSON" | jq -r '.batchrsp.items[0].item' | jq)
URL=$(echo "$INNER" | jq -r '.ad.landscapeImage.asset')

NOME="$PASTA/spotlight_$(date +%Y-%m-%d_%H-%M-%S).jpg"

if [ ! -z "$URL" ]; then
    curl -L "$URL" -o "$NOME"
    echo "Imagem salva em: $NOME"

    PROPS=$(xfconf-query -c xfce4-desktop -l | grep last-image)
    for P in $PROPS; do
        xfconf-query -c xfce4-desktop -p "$P" -s "$NOME"
    done

    echo "Wallpaper do XFCE atualizado!"
else
    echo "Erro: não encontrou URL"
fi