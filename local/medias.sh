#!/bin/sh
# Fabrique trois petites vidéos de test, rangées comme les objets du bucket : media/demo-N.mp4.
# Les fichiers produits dans ./bucket/media peuvent ensuite être copiés tels quels dans Cloud Storage.
set -eu
mkdir -p /bucket/media
if [ -f /bucket/media/demo-3.mp4 ]; then
  echo "Les vidéos de démonstration existent déjà."
  exit 0
fi
apk add --no-cache ffmpeg >/dev/null
n=1
for source in testsrc testsrc2 smptebars; do
  ffmpeg -loglevel error -y -f lavfi -i "$source=duration=6:size=640x360:rate=25" \
    -pix_fmt yuv420p -movflags +faststart "/bucket/media/demo-$n.mp4"
  n=$((n + 1))
done
ls -lh /bucket/media
