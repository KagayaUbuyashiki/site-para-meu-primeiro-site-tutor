#!/usr/bin/env bash
# =============================================================================
#  conquistas.sh — desbloqueia as conquistas fáceis do GitHub neste repositório
#
#  Conquistas:
#    - Quickdraw            -> abre e fecha uma issue em menos de 5 minutos
#    - YOLO                 -> faz merge de um PR sem review
#    - Pull Shark           -> 2 PRs mergeados (nível base)
#    - Pair Extraordinaire  -> PR mergeado com commit em coautoria (opcional)
#
#  Requisitos:
#    - git e GitHub CLI (gh) instalados   -> https://cli.github.com
#    - estar logado:  gh auth login
#    - rodar de dentro da pasta clonada do repositório
#
#  Uso:
#    ./conquistas.sh
#    ./conquistas.sh --prs 3                                   # mais PRs
#    ./conquistas.sh --coautor "Nome <email@da-outra-conta.com>"  # Pair Extraordinaire
# =============================================================================
set -euo pipefail

NUM_PRS=2
COAUTOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prs)     NUM_PRS="$2"; shift 2 ;;
    --coautor) COAUTOR="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

info() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# 0. Verificações
# ---------------------------------------------------------------------------
command -v gh  >/dev/null || { echo "Instale o GitHub CLI: https://cli.github.com"; exit 1; }
command -v git >/dev/null || { echo "Instale o git."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Faça login antes: gh auth login"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Rode dentro da pasta do repositório."; exit 1; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
BASE=${BASE:-main}
info "Repositório: $REPO (branch base: $BASE)"

# Garante que a branch base existe e tem pelo menos um commit
if ! git rev-parse HEAD >/dev/null 2>&1; then
  info "Repositório vazio, criando commit inicial"
  git checkout -B "$BASE"
  [[ -f README.md ]] || echo "# $(basename "$REPO")" > README.md
  git add -A
  git commit -m "Commit inicial"
  git push -u origin "$BASE"
fi
git checkout "$BASE"
git pull --ff-only origin "$BASE" || true

# Issues podem estar desativadas no repositório
gh repo edit "$REPO" --enable-issues >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 1. Quickdraw — abrir e fechar uma issue rapidinho
# ---------------------------------------------------------------------------
info "Quickdraw: abrindo e fechando uma issue"
ISSUE_URL=$(gh issue create --repo "$REPO" \
  --title "Quickdraw $(date +%s)" \
  --body "Issue aberta e fechada automaticamente.")
gh issue close "$ISSUE_URL" --repo "$REPO" --comment "Fechada em segundos ⚡"
ok "Issue fechada: $ISSUE_URL"

# ---------------------------------------------------------------------------
# 2. YOLO + Pull Shark (+ Pair Extraordinaire, se tiver coautor)
# ---------------------------------------------------------------------------
mkdir -p .conquistas

for i in $(seq 1 "$NUM_PRS"); do
  BRANCH="conquista-pr-$i-$(date +%s)"
  info "PR $i/$NUM_PRS na branch $BRANCH"

  git checkout -b "$BRANCH"
  echo "PR $i criado em $(date -u +%Y-%m-%dT%H:%M:%SZ)" > ".conquistas/pr-$i.txt"
  git add ".conquistas/pr-$i.txt"

  MSG="Conquista: PR $i"
  if [[ -n "$COAUTOR" && "$i" -eq 1 ]]; then
    git commit -m "$MSG" -m "Co-authored-by: $COAUTOR"
  else
    git commit -m "$MSG"
  fi

  git push -u origin "$BRANCH"

  PR_URL=$(gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" \
    --title "$MSG" --body "PR automático para conquistas do GitHub.")

  # Merge sem review = YOLO
  gh pr merge "$PR_URL" --repo "$REPO" --merge --delete-branch
  ok "Mergeado: $PR_URL"

  git checkout "$BASE"
  git pull --ff-only origin "$BASE"
  git branch -D "$BRANCH" 2>/dev/null || true
  sleep 3
done

# ---------------------------------------------------------------------------
info "Pronto!"
echo "Conquistas esperadas: Quickdraw, YOLO, Pull Shark$([[ -n "$COAUTOR" ]] && echo ', Pair Extraordinaire')"
echo "Elas podem levar algumas horas para aparecer em:"
echo "  https://github.com/$(gh api user -q .login)?tab=achievements"
