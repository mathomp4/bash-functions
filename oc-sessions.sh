# vim: ft=bash
# List top-level OpenCode sessions across projects.
oc-sessions() (
   set -o pipefail

   if [[ $# -gt 1 || ( $# -eq 1 && ! $1 =~ ^[1-9][0-9]*$ ) ]]; then
      printf 'Usage: oc-sessions [positive-count]\n' >&2
      exit 1
   fi

   local page cursor='' count limit remaining=${1:-50}
   {
      while (( remaining > 0 )); do
         limit=$remaining
         (( limit > 100 )) && limit=100
         page=$(opencode api get \
            "/api/session?limit=$limit&parentID=null&order=desc${cursor:+&cursor=$cursor}") || exit 1

         jq -c --argjson n "$remaining" '.data[:$n][] | {
            ID: .id,
            TITLE: (.title // ""),
            DIRECTORY: .location.directory
         }' <<< "$page" || exit 1

         count=$(jq -e '.data | length' <<< "$page") || exit 1
         (( count > 0 )) || break
         remaining=$((remaining - count))
         cursor=$(jq -r '.cursor.next // empty | @uri' <<< "$page") || exit 1
         [[ -n $cursor ]] || break
      done
   } | nu --stdin -c '$in | lines | each { from json } | table'
)
