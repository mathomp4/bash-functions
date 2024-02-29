# vim: ft=bash 
function rgi () {
   rg -g '!build*' -g '!install*' $@
}
