# Define custom variables for iTerm2
iterm2_print_user_vars() {
  local short_host

  # Check if the Slurm node name variable exists and is not empty
  if [ -n "$SLURMD_NODENAME" ]; then
    short_host="$SLURMD_NODENAME"
  else
    # 1. Strip the domain (everything after the first dot)
    short_host="${HOST%%.*}"

    # 2. Explicitly strip "gs6101-" if it exists at the start of the string
    short_host="${short_host#gs6101-}"
  fi

  # Send it to iTerm2
  iterm2_set_user_var shortHostname "$short_host"
}
