#!/bin/sh

set -euo pipefail

SCRIPT_NAME=${0##*/}
API_URL="https://api.porkbun.com/api/json/v3"

CREDENTIALS_PATH="$HOME/.config/porkbun-cli/credentials"
DRY_RUN=0

print_help() {
  cat <<EOF >&2
Interact with Porkbun API.

Usage:
${SCRIPT_NAME} [--api-key <api-key>] [--secret-api-key <secret-api-key>] [--dry-run] -- <command>

Notes:
--api-key and --secret-api-key may be omitted if credentials are found in
$CREDENTIALS_PATH

Commands:

Canonical:
  create <domain> [<subdomain>] --type <type> --content <content> [--ttl <ttl>] [--prio <prio>]
  edit <domain> <id> --type <type> --content <content> [--name <name>] [--ttl <ttl>] [--prio <prio>]
  edit-by-name-type <domain> [<subdomain>] --type <type> --content <content> [--ttl <ttl>] [--prio <prio>]
  delete <domain> <id>
  delete-by-name-type <domain> [<subdomain>] --type <type> [--ttl <ttl>] [--prio <prio>]
  retrieve <domain> [<id>]
  retrieve-by-name-type <domain> [<subdomain>] --type <type>

Non-canonical:
  upsert-by-name-type <domain> [<subdomain>] --type <type> --content <content> [--ttl <ttl>] [--prio <prio>] [--multiple-behavior <unique|append>]
EOF
}

post_request() {
  URL="$1"
  BODY="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    cat<<EOF >&2
POST $URL
$BODY
EOF
  else
    curl \
      --fail-with-body \
      --silent \
      -X POST \
      -L "$URL" \
      -H 'content-type: application/json' \
      -d "$BODY"
  fi
}

# Retrieve credentials
[ -f "$CREDENTIALS_PATH" ] && source "$CREDENTIALS_PATH"

# BEGIN: Global arg parse
GLOBAL_OPTS="$(getopt -o 'k:s:' -l 'api-key:,secret-api-key:,dry-run' --name "$0" -- "$@")"
eval set -- "$GLOBAL_OPTS"

while true; do
  case "$1" in
    --api-key|-k)        PORKBUN_API_KEY="$2"; shift 2;;
    --secret-api-key|-s) PORKBUN_SECRET_API_KEY="$2"; shift 2;;
    --dry-run)           DRY_RUN=1; shift;;
    --)                  shift; break;;
    *)                   print_help; exit 1;;
  esac
done
# END

if [ -z "${PORKBUN_SECRET_API_KEY:-}" ] ||\
  [ -z "${PORKBUN_API_KEY:-}" ]; then
  print_help
  echo "Credentials not found" >&2
  exit 1
fi
CREDENTIALS_BODY=$(cat <<EOF
{
  "secretapikey": "$PORKBUN_SECRET_API_KEY",
  "apikey": "$PORKBUN_API_KEY"
}
EOF
)

SUBCOMMAND="$1"
shift


create() {
  DOMAIN="${1:-}"
  shift
  OPTS="$(getopt -o 't:c:l:p:' -l 'type:,content:,ttl:,prio:' -- "$@")"
  eval set -- "$OPTS"

  TTL=""
  PRIO=""
  while true; do
    case "$1" in
      --type|-t)    TYPE="$2"; shift 2;;
      --content|-c) CONTENT="$2"; shift 2;;
      --ttl|-l)     TTL="$2"; shift 2;;
      --prio|-p)    PRIO="$2"; shift 2;;
      --)           shift; break;;
      *)            print_help; exit 1; ;;
    esac
  done
  NAME="${1:-}"
  shift

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${TYPE:-}" ] ||\
    [ -z "${CONTENT:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/create/$DOMAIN"
  BODY=$(cat <<EOF | jq -sr 'add | with_entries(select(.value | . != ""))'
{
  "name": "$NAME",
  "type": "$TYPE",
  "content": "$CONTENT",
  "ttl": "$TTL"
}

$CREDENTIALS_BODY
EOF
  )
  post_request "$URL" "$BODY"
}

edit() {
  DOMAIN="${1:-}"
  ID="${2:-}"
  shift 2
  OPTS="$(getopt -o 't:c:n:l:p:' -l 'type:,content:,name:,ttl:,prio:' -- "$@")"
  eval set -- "$OPTS"

  NAME=""
  TTL=""
  PRIO=""
  while true; do
    case "$1" in
      --type|-t)    TYPE="$2"; shift 2;;
      --content|-c) CONTENT="$2"; shift 2;;
      --name|-n)    NAME="$2"; shift 2;;
      --ttl|-l)     TTL="$2"; shift 2;;
      --prio|-p)    PRIO="$2"; shift 2;;
      --)           shift; break;;
      *)            print_help; exit 1; ;;
    esac
  done

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${ID:-}" ] ||\
    [ -z "${TYPE:-}" ] ||\
    [ -z "${CONTENT:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/edit/$DOMAIN/$ID"
  BODY=$(cat <<EOF | jq -sr 'add | with_entries(select(.value | . != ""))'
{
  "name": "$NAME",
  "type": "$TYPE",
  "content": "$CONTENT",
  "ttl": "$TTL"
}

$CREDENTIALS_BODY
EOF
  )

  post_request "$URL" "$BODY"
}

edit_by_name_type() {
  DOMAIN="${1:-}"
  shift
  OPTS="$(getopt -o 't:p:c:l:' -l 'type:,prio:,content:,ttl:' -- "$@")"
  eval set -- "$OPTS"

  TTL=""
  PRIO=""
  while true; do
    case "$1" in
      --type|-t)    TYPE="$2"; shift 2;;
      --content|-c) CONTENT="$2"; shift 2;;
      --ttl|-l)     TTL="$2"; shift 2;;
      --prio|-p)    PRIO="$2"; shift 2;;
      --)           shift; break;;
      *)            print_help; exit 1; ;;
    esac
  done
  SUBDOMAIN="${1:-}"
  shift

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${TYPE:-}" ] ||\
    [ -z "${CONTENT:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/editByNameType/$DOMAIN/$TYPE"
  if [ -n "$SUBDOMAIN" ]; then
    URL="$URL/$SUBDOMAIN"
  fi

  BODY=$(cat <<EOF | jq -sr 'add | with_entries(select(.value | . != ""))'
{
  "content": "$CONTENT",
  "ttl": "$TTL"
}

$CREDENTIALS_BODY
EOF
  )

  post_request "$URL" "$BODY"
}

delete() {
  DOMAIN="${1:-}"
  ID="${2:-}"
  shift 2

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${ID:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/delete/$DOMAIN/$ID"
  BODY="$CREDENTIALS_BODY"

  post_request "$URL" "$BODY"
}

delete_by_name_type() {
  DOMAIN="${1:-}"
  shift
  OPTS="$(getopt -o 't:' -l 'type:' -- "$@")"
  eval set -- "$OPTS"

  while true; do
    case "$1" in
      --type|-t) TYPE="$2"; shift 2;;
      --)        shift; break;;
      *)         print_help; exit 1;;
    esac
  done
  SUBDOMAIN="${1:-}"
  shift

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${TYPE:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/deleteByNameType/$DOMAIN/$TYPE"
  if [ -n "$SUBDOMAIN" ]; then
    URL="$URL/$SUBDOMAIN"
  fi
  BODY="$CREDENTIALS_BODY"
  post_request "$URL" "$BODY"
}

retrieve() {
  DOMAIN="${1:-}"
  ID="${2:-}"

  if [ -z "${DOMAIN:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/retrieve/$DOMAIN"
  if [ -n "${ID:-}" ]; then
    URL="$URL/$ID"
  fi
  BODY="$CREDENTIALS_BODY"

  post_request "$URL" "$BODY"
}

retrieve_by_name_type() {
  DOMAIN="${1:-}"
  shift
  OPTS="$(getopt -o 't:' -l 'type:' -- "$@")"
  eval set -- "$OPTS"

  while true; do
    case "$1" in
      --type|-t)      TYPE="$2"; shift 2;;
      --)             shift; break;;
      *)              print_help; exit 1;;
    esac
  done
  SUBDOMAIN="${1:-}"
  shift

  if [ -z "${DOMAIN:-}" ] ||\
    [ -z "${TYPE:-}" ]; then
    print_help
    exit 1
  fi

  URL="$API_URL/dns/retrieveByNameType/$DOMAIN/$TYPE"
  if [ -n "$SUBDOMAIN" ]; then
    URL="$URL/$SUBDOMAIN"
  fi
  BODY="$CREDENTIALS_BODY"
  post_request "$URL" "$BODY"
}

upsert_by_name_type() {
  DOMAIN="${1:-}"
  shift
  OPTS="$(getopt -o 't:p:c:l:b' -l 'type:,prio:,content:,ttl:,multiple-behavior:' -- "$@")"
  eval set -- "$OPTS"

  TTL=""
  PRIO=""
  MULTIPLE_BEHAVIOR="error"
  while true; do
    case "$1" in
      --type|-t)              TYPE="$2"; shift 2;;
      --content|-c)           CONTENT="$2"; shift 2;;
      --ttl|-l)               TTL="$2"; shift 2;;
      --prio|-p)              PRIO="$2"; shift 2;;
      --multiple-behavior|-b) MULTIPLE_BEHAVIOR="$2"; shift 2;;
      --)                     shift; break;;
      *)                      print_help; exit 1; ;;
    esac
  done
  SUBDOMAIN="${1:-}"
  shift

  RECORD_INFO=$(retrieve_by_name_type "$DOMAIN" "$SUBDOMAIN" --type "$TYPE")
  NUM_RECORDS=$(echo "$RECORD_INFO" | jq '.records | length')
  # Create new record
  case "$NUM_RECORDS" in
    0)
      create "$DOMAIN" "$SUBDOMAIN" \
        --type "$TYPE" \
        --content "$CONTENT" \
        --ttl "$TTL" \
        --prio "$PRIO"
      ;;
    1)
      edit_by_name_type "$DOMAIN" "$SUBDOMAIN" \
        --type "$TYPE" \
        --content "$CONTENT" \
        --ttl "$TTL" \
        --prio "$PRIO"
      ;;
    *)
      case "$MULTIPLE_BEHAVIOR" in
        unique)
          delete_by_name_type "$DOMAIN" "$SUBDOMAIN" \
            --type "$TYPE" \
            --prio "$PRIO"

          create "$DOMAIN" "$SUBDOMAIN" \
            --type "$TYPE" \
            --content "$CONTENT" \
            --ttl "$TTL" \
            --prio "$PRIO"
          ;;
        append)
          create "$DOMAIN" "$SUBDOMAIN" \
            --type "$TYPE" \
            --content "$CONTENT" \
            --ttl "$TTL" \
            --prio "$PRIO"
          ;;
        *)
          cat <<EOF >&2
Expected 0 or 1 records on subdomain $SUBDOMAIN type $TYPE, but
got $NUM_RECORDS.

- Set --multiple-behavior=unique to remove all existing records for subdomain
  $SUBDOMAIN type $TYPE and set a single new record, or
- Set --multiple-behavior=append to append a record for subdomain $SUBDOMAIN
  type $TYPE
EOF
          exit 1
          ;;
      esac
      ;;
  esac
}

case "$SUBCOMMAND" in
  create)                create "$@";;
  edit)                  edit "$@";;
  edit-by-name-type)     edit_by_name_type "$@";;
  delete)                delete "$@";;
  delete-by-name-type)   delete_by_name_type "$@";;
  retrieve)              retrieve "$@";;
  retrieve-by-name-type) retrieve_by_name_type "$@";;
  upsert-by-name-type)   upsert_by_name_type "$@";;
  *)
    echo "Unknown subcommand: $SUBCOMMAND" >&2
    exit 1
esac
