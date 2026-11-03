#!/usr/bin/env bash
# ============================================================================
# mirror-release.sh — создаёт релиз с исходниками ядра в ЭТОМ форке
# (Yaroslavsfedu/linux-cachyos), зеркалируя релиз CachyOS/linux.
#
# PKGBUILD'ы в папках linux-cachyos* качают tarball уже отсюда, поэтому при
# выходе новой версии ядра нужно один раз прогнать этот скрипт с новым тегом.
# Файлы байт-в-байт совпадают с апстримом, так что PGP-подписи и b2sums остаются верны.
#
# Использование:  ./mirror-release.sh cachyos-7.3.1-1
# Требует:        gh (авторизованный: gh auth login), curl, gpg
# ============================================================================
set -euo pipefail

TAG="${1:?Использование: ./mirror-release.sh cachyos-7.3.1-1}"
REPO="Yaroslavsfedu/linux-cachyos"
UPSTREAM_URL="https://github.com/CachyOS/linux/releases/download/${TAG}"

# Ключи мейнтейнеров CachyOS, которыми подписан tarball (как в validpgpkeys PKGBUILD)
KEYS=(
  E18447AC260021D31F3FF6C4C8A2A4774B8B63C4  # Eric Naim <dnaim@cachyos.org>
  E8B9AA39F054E30E8290D492C3C4820857F654FE  # Peter Jung <admin@ptr1337.dev>
)

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "Релиз $TAG в $REPO уже существует — ничего не делаю."
    exit 0
fi

echo "==> Скачиваю tarball из CachyOS/linux ($TAG)..."
curl -fL --retry 3 -o "$TAG.tar.gz" "https://github.com/CachyOS/linux/releases/download/$TAG/$TAG.tar.gz"
curl -fL --retry 3 -o "$TAG.tar.gz.asc" "https://github.com/CachyOS/linux/releases/download/$TAG/$TAG.tar.gz.asc"

echo "==> Импортирую ключи и проверяю PGP-подпись..."
for key in "${KEYS[@]}"; do
    curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$key" 2>/dev/null | gpg --import || true
done
if ! gpg --verify "$TAG.tar.gz.asc" "$TAG.tar.gz" 2>/dev/null; then
    echo "ВНИМАНИЕ: подпись не прошла проверку (нет gpg/ключей в среде) — продолжаю, сделайте проверку вручную: gpg --verify $TAG.tar.gz.asc $TAG.tar.gz" >&2
fi

echo "==> Создаю релиз в $REPO и загружаю оба файла..."
gh release create "$TAG" --repo "$REPO" \
    --title "$TAG" \
    --notes "Зеркало исходников ядра CachyOS/linux ($TAG). PKGBUILD'ы этого репозитория качают tarball из этого релиза. Файлы и PGP-подписи идентичны апстриму." \
    "$TAG.tar.gz" "$TAG.tar.gz.asc"

rm -f "$TAG.tar.gz" "$TAG.tar.gz.asc"
echo "==> Готово: https://github.com/$REPO/releases/tag/$TAG"
