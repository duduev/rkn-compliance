#!/usr/bin/env bash
# Проверяет то, что ломает установку скилла: фронтматтер, имена, регистрацию в плагине.
# Совместим с bash 3.2 (macOS) и bash 5 (CI).
set -uo pipefail

cd "$(dirname "$0")/.."

fail=0
count=0
err() { echo "  ✗ $1"; fail=1; }

skills=$(find skills -name SKILL.md | sort)

if [ -z "$skills" ]; then
  echo "✗ Скиллы не найдены в skills/"
  exit 1
fi

for skill in $skills; do
  dir=$(dirname "$skill")
  count=$((count + 1))
  echo "→ $dir"

  # Фронтматтер должен открываться в первой строке
  [ "$(head -1 "$skill")" = "---" ] || err "SKILL.md не начинается с фронтматтера (---)"

  name=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[ ]*/,""); print; exit}' "$skill")
  desc=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description:[ ]*/,""); print; exit}' "$skill")

  [ -n "$name" ] || err "нет поля name"
  [ -n "$desc" ] || err "нет поля description"

  # Имя: только строчные латинские буквы, цифры, дефисы — иначе агенты не подхватят
  if [ -n "$name" ]; then
    echo "$name" | grep -qE '^[a-z0-9-]+$' || err "name '$name' — допустимы только a-z, 0-9 и дефис"
    [ "$name" = "$(basename "$dir")" ] || err "name '$name' не совпадает с именем папки '$(basename "$dir")'"
  fi

  # Лимит фронтматтера по спецификации — 1024 символа
  fm_len=$(awk '/^---$/{n++; if(n==2) exit} n>=1{print}' "$skill" | wc -c | tr -d ' ')
  [ "$fm_len" -le 1024 ] || err "фронтматтер $fm_len символов, лимит 1024"

  # description должен описывать КОГДА применять, а не что скилл делает
  case "$desc" in
    "Use when"*) ;;
    *) err "description должен начинаться с 'Use when...'" ;;
  esac

  # Скилл должен быть зарегистрирован в манифесте плагина
  if [ -f .claude-plugin/plugin.json ]; then
    grep -q "\"\./$dir\"" .claude-plugin/plugin.json \
      || err "не зарегистрирован в .claude-plugin/plugin.json (нужна запись \"./$dir\")"
  fi

  # Ссылки на прикреплённые файлы не должны вести в никуда
  for ref in $(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$skill" 2>/dev/null | sort -u); do
    [ -f "$dir/$ref" ] || err "битая ссылка на $ref"
  done

  echo "  слов в SKILL.md: $(wc -w < "$skill" | tr -d ' ')"
done

if [ "$fail" -ne 0 ]; then
  echo "✗ Проверка не пройдена"
  exit 1
fi

echo "✓ Все скиллы валидны ($count)"
