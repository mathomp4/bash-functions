# vim: ft=bash 
sq() {
   squeue "$@" | rpen.py -k RUNNING "$USER" PENDING COMPLET
}
