#!/usr/bin/env zsh

_KIT_DEPENDENCIES=("jq" "fzf")
_KIT_DEFAULT_REPO_PATH=$HOME/.kit

function kit() {
  zmodload zsh/zutil

  for cmd in "${_KIT_DEPENDENCIES[@]}"; do
    if ! command -v $cmd &>/dev/null; then
      echo "$(_kit_error "'$cmd' is not installed. Please install $cmd to use kit")"
      return 1
    fi
  done

  case $1 in
    init)
      shift
      _kit_cmd_init "$@"
      ;;

    create)
      shift
      _kit_cmd_create "$@"
      ;;

    run)
      shift
      _kit_cmd_run "$@"
      ;;

    open)
      shift
      _kit_cmd_open "$@"
      ;;

    manifest)
      shift
      _kit_cmd_manifest "$@"
      ;;

    fix)
      shift
      _kit_cmd_fix "$@"
      ;;

    rm|remove)
      shift
      _kit_cmd_remove "$@"
      ;;

    ls|list)
      shift
      _kit_cmd_list "$@"
      ;;

    cd)
      shift
      _kit_cmd_cd "$@"
      ;;

    help|--help|-h)
      _kit_help
      ;;

    *)
      _kit_help
      return 1
      ;;
  esac
}

function _kit_cmd_init() {
  local usage=(
    "$(_kit_info 'Initializes kit by setting up the necessary configuration and script storage path.')"
    "$(_kit_info 'You can specify a custom repository path using the --repo option.')"
    "$(_kit_info 'If no repository path is provided, the default path will be used:') $_KIT_DEFAULT_REPO_PATH"

    "\nUsage: "
    "  $(_kit_highlight 'kit init [-r|--repo]')"
    "  $(_kit_highlight 'kit init [-h|--help]')"
  )

  local flag_help
  local arg_repo
  zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {r,-repo}:=arg_repo || {
      echo "$(_kit_error 'Failed to parse options')"
      return 1
    }

  if [[ -n "$flag_help" ]]; then
    print -l $usage
    return
  fi

  local config_path=$(_kit_util_get_user_config_path)

  if [[ ! -d "$config_path/kit" ]]; then
    command mkdir -p "$config_path/kit" || {
      echo "$(_kit_error 'Failed to create configuration directory')"
      return 1
    }
  fi

  local repo_path
  if [[ -z $arg_repo ]]; then
    repo_path=$_KIT_DEFAULT_REPO_PATH
  else
    repo_path=$arg_repo[-1]
  fi

  if [[ ! -e "$config_path/kit/config.json" ]]; then
    jq --arg repo "$repo_path" -n '{ repo: $repo }' > "$config_path/kit/config.json"
  fi

  if [[ ! -d "$repo_path" ]]; then
    command mkdir -p $repo_path || {
      echo "$(_kit_error 'Failed to create repository path')"
      return 1
    }
    echo "{}" > $(_kit_util_get_path_mapping_path)
  fi

  echo "$(_kit_success 'kit has been successfully initialized.')"
  echo
  echo "$(_kit_highlight 'Your scripts will be stored in') $repo_path"
  echo "For more information on how to create scripts, use $(_kit_highlight 'kit create --help')"
}

function _kit_cmd_create() {
  local usage=(
    "$(_kit_info 'It allows you to create a new script.')"
    "$(_kit_info 'Optionally, you can associate it with a specific path using further options.\n')"

    "Usage: "
    "  $(_kit_highlight 'kit create <script_name>')"
    "  $(_kit_highlight 'kit create <script_name> [-p|--path=<path>]')"
    "  $(_kit_highlight 'kit create <script_name> [-c|--cmd=<command>]')"
    "  $(_kit_highlight 'kit create <script_name> [-d|--desc=<description>]')"
    "  $(_kit_highlight 'kit create [-h|--help]')"
  )

  if [[ "$1" == "-help" || "$1" == "--help" ]]; then
    print -l $usage && return
  fi

  local script_name=$1
  if [[ -z "$script_name" || "$script_name" == -* ]]; then
    echo "$(_kit_info 'No script name provided. Please specify a valid script name.')"
    echo
    echo "$(_kit_info 'For more details, use') $(_kit_highlight 'kit create --help')"

    return 1
  fi

  shift

  local flag_help
  local arg_cmd
  local arg_path="."
  local arg_about=""

  zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {c,-cmd}=flag_cmd \
    {a,-about}:=arg_about \
    {p,-path}:=arg_path || {
      echo "$(_kit_error 'Failed to parse options')"
      return 1
    }

  if [[ -n "$flag_help" ]]; then
    print -l $usage
    return
  fi

  script_path="$(_kit_util_get_repo_path)/$script_name"
  if [ -d $script_path ]; then
    echo "$(_kit_info 'A script with this name already exists.')"
    echo "$(_kit_info 'Please choose a different script name.')"
    return 1
  fi

  local arg_path_value=$arg_path[-1]
  if [[ $arg_path_value == "." ]]; then
    path_to_map=$(pwd)
  else
    if [ ! -d $arg_path_value ]; then
      echo "$(_kit_info 'The specified path does not exist.')"
      echo "$(_kit_info 'Please provide a valid directory path.')"
      return 1
    fi

    path_to_map=$arg_path_value
  fi

  command mkdir $script_path

  local exec=""
  local entry=""

  if [[ -n "$flag_cmd" ]]; then
    local exec="."
    local entry="run.sh"

    touch "$script_path/run.sh"
  fi

  jq --arg about "$arg_about[-1]" \
     --arg exec "$exec" \
     --arg entry "$entry" \
     -n '{ about: $about, exec: $exec, entry: $entry}' > "$script_path/manifest.json"

  _kit_util_update_path_mappings $script_name $path_to_map

  echo "$(_kit_success 'The script folder has been successfully created.')"

  echo -e "\n$(_kit_info 'Location'): $(_kit_highlight $script_path)"

  echo -e "\nTo open the script folder, run the following command:"
  echo "  $(_kit_highlight 'kit open') $script_name"

  if [[ -z "$flag_cmd" ]]; then
    echo -e "\nTo configure the entry point and execution command, use:"
    echo "  $(_kit_highlight 'kit manifest') $script_name $(_kit_highlight '--exec . --entry run.sh')"
  fi
}

function _kit_cmd_run() {
  local usage=(
    "$(_kit_info 'Executes a specified script with any additional arguments or flags you provide.')"
    "$(_kit_info 'To run all scripts associated with the current directory, use') $(_kit_highlight 'kit run .')"
    "$(_kit_info 'This will execute all associated scripts in order.')"

    "\nUsage: "
    "  $(_kit_highlight 'kit run <script_name> [args...] [flags]')"
    "  $(_kit_highlight 'kit run [-h|--help]')"
    "  $(_kit_highlight 'kit run .') $(_kit_info '(to run all scripts associated with the current directory)')"
  )

  if [[ "$1" == "--help" || "$1" == "-help" || "$1" == "-h" ]]; then
    print -l $usage

    return
  fi

  local script_name=$1

  if [[ -z  $script_name ]]; then
    local scripts=($(_kit_util_get_script_names))
    selected_script=$(printf "%s\n" "${scripts[@]}" | fzf --height 40% --reverse --border --prompt "Select a script: ")

    if [[ -n $selected_script ]]; then
      print -z "kit run $selected_script"
    fi

    return 1
  fi

  shift
  local script_args=($@)

  if [[ $script_name == "." ]]; then
    local current_path=$(pwd)
    local script_names=($(jq -r --arg path "$current_path" 'if .[$path] != null then .[$path][] else empty end' $(_kit_util_get_path_mapping_path)))

    for script_name in "${script_names[@]}"; do
      _kit_util_run_script_by_name $script_name $script_args
    done

    return 0
  fi

  _kit_util_run_script_by_name $script_name $script_args
}

function _kit_cmd_open() {
  local script_name=$1
  local editor=$(_kit_util_get_default_editor)

  if [[ -z "$script_name" ]]; then
    echo "$(_kit_info 'No script name provided.')"
    echo "$(_kit_info 'Please specify the name of the script you want to open.')"

    return 1;
  fi

  local script_path="$(_kit_util_get_repo_path)/$script_name"

  if [[ ! -d $script_path ]]; then
    echo "$(_kit_info "The script '$script_name' does not exist in the repository.")"
    echo
    echo "$(_kit_info 'You can list available scripts using') $(_kit_highlight 'kit list')"
    return 1
  fi

  local entry=$(jq -r .entry $script_path/manifest.json)

  if [[ -n "$entry" && -e "$script_path/$entry" ]]; then
    script_path+="/$entry"
  fi

  "$editor" $script_path
}

function _kit_cmd_manifest() {
  local usage=(
    "$(_kit_info 'Updates the manifest file for an existing script.')"
    "$(_kit_info 'You can specify the entry point using the --entry option and the execution command using the --exec option.')"

    "\nUsage: "
    "  $(_kit_highlight 'kit manifest <script_name> [-e|--entry <entry>] [-x|--exec <exec>]')"
    "  $(_kit_highlight 'kit manifest [-h|--help]')"

    "\nExample: "
    "  $(_kit_highlight 'kit manifest my_script --entry main.js --exec node')"
  )

  if [[ "$1" == "-help" || "$1" == "--help" ]]; then
    print -l $usage && return
  fi

  local script_name=$1
  if [[ -z "$script_name" || "$script_name" == -* ]]; then
    echo "$(_kit_info 'No script name provided. Please specify a valid script name.')"
    echo
    echo "$(_kit_info 'For more details, use') $(_kit_highlight 'kit manifest --help')"

    return 1
  fi

  shift

  local flag_help
  local arg_entry=""
  local arg_exec=""
  local arg_about=""

  zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {e,-entry}:=arg_entry \
    {x,-exec}:=arg_exec \
    {a,-about}:=arg_about ||
    return 1

  if [[ -n "$flag_help" ]]; then
    print -l $usage 
    return
  fi

  local script_entry=$arg_entry[-1]
  local script_exec=$arg_exec[-1]
  local script_about=$arg_about[-1]

  local script_path="$(_kit_util_get_repo_path)/$script_name"
  local manifest_file="$script_path/manifest.json"

  if [[ ! -e "$manifest_file" ]]; then
    echo "$(_kit_info 'A script with this name does not exist. Please ensure the script name is correct.')"
    return 1
  fi

  local manifest_content=$(command cat $manifest_file)

  if [[ ! -z "$script_exec" ]]; then
    manifest_content=$(echo $manifest_content | jq --arg value "$script_exec" '.exec = $value')
  fi

  if [[ ! -z "$script_entry" ]]; then
    manifest_content=$(echo $manifest_content | jq --arg value "$script_entry" '.entry = $value')
  fi

  if [[ ! -z "$script_about" ]]; then
    manifest_content=$(echo $manifest_content | jq --arg value "$script_about" '.about = $value')
  fi

  echo $manifest_content > $manifest_file
  echo $manifest_content | jq .
}

function _kit_cmd_fix() {
  local path_mappings=$(command cat $(_kit_util_get_path_mapping_path))
  local updated_path_mappings=$(command cat $(_kit_util_get_path_mapping_path))

  # Get all paths from the mappings
  local paths=($(echo $path_mappings | jq -r 'keys[]'))

  for mapped_path in "${paths[@]}"; do
    # If the mapped path no longer exists, remove it from the mapping
    if [[ ! -d "$mapped_path" ]]; then
      updated_path_mappings=$(echo $updated_path_mappings | jq --arg path "$mapped_path" 'del(.[$path])')
      continue
    fi

    local scripts=($(echo $path_mappings | jq -r --arg path "$mapped_path" '.[$path][]'))
    for script_name in "${scripts[@]}"; do
      local script_path="$(_kit_util_get_repo_path)/$script_name"

      # If the script directory no longer exists, remove it from the mapping
      if [[ ! -d "$script_path" ]]; then
        updated_path_mappings=$(echo $updated_path_mappings | jq --arg path "$mapped_path" --arg script_name "$script_name" '.[$path] |= map(select(. != $script_name))')
      fi
    done

    local mapped_path_scripts_length=$(echo "$updated_path_mappings" | jq --arg path "$mapped_path" '.[$path] | length')

    # If a path doesn't have any scripts, remove the key
    if [[ "$mapped_path_scripts_length" -eq 0 ]]; then
      updated_path_mappings=$(echo "$updated_path_mappings" | jq --arg path "$mapped_path" 'del(.[$path])')
    fi
  done

  # Save the updated path mappings
  echo $updated_path_mappings > $(_kit_util_get_path_mapping_path)

  echo "$(_kit_success 'The path mapping file has been successfully synced.')"
}

function _kit_cmd_remove() {
  local usage=(
    "$(_kit_info 'Removes script/s from the kit repository')"

    "\nUsage: "
    "  $(_kit_highlight 'kit remove <script_name>')"
    "  $(_kit_highlight 'kit remove [-h|--help]')"
  )

  if [[ "$1" == "--help" || "$1" == "-help" || "$1" == "-h" ]]; then
    print -l $usage

    return
  fi

  local script_name=$1

  if [[ -z "$script_name" ]]; then
    echo "$(_kit_info 'No script name provided. Please specify the name of the script to remove.')"
    return
  fi


  # Handling multiple scripts at once
  if [[ "$script_name" == "." ]]; then
    local scripts=($(_kit_util_get_script_names))
    local selected_scripts=$(printf "%s\n" "${scripts[@]}" | fzf --height 40% --reverse --border --prompt "Select one or more scripts: " --multi)

    local joined_selected_scripts=$(echo "$selected_scripts" | tr '\n' ',' | sed 's/,$//')
    echo "These scripts will be removed: $joined_selected_scripts"

    echo -n "$(_kit_info 'Are you sure you want to proceed? (y/n) ')"
    read -r reply

    if [[ "$reply" =~ ^[Yy]$ || "$reply" == "yes" ]]; then
      for selected_script in ${(f)selected_scripts}; do
        local script_path="$(_kit_util_get_repo_path)/$selected_script"
        command rm -r $script_path
      done

      echo "\n$(_kit_success 'The selected scripts have been removed from the repo.')"
      _kit_cmd_fix
    else
      echo "$(_kit_info 'Operation canceled.')"
    fi

    return
  fi

  local script_path="$(_kit_util_get_repo_path)/$script_name"
  if [[ ! -d "$script_path" ]]; then
    echo "$(_kit_info 'The script') \"$script_name\" $(_kit_info 'does not exist.')"
    return
  fi

  echo -n "$(_kit_info 'Are you sure you want to remove the script? (y/n) ')"
  read -r reply

  if [[ "$reply" =~ ^[Yy]$ || "$reply" == "yes" ]]; then
    command rm -r $script_path
    echo "$(_kit_success 'The script has been removed successfully.')"
    _kit_cmd_fix
  else
    echo "$(_kit_info 'Operation canceled.')"
  fi

}

function _kit_cmd_list() {
  local usage=(
    "$(_kit_info 'Lists the available scripts. By default, it lists all scripts that have been created.')"
    "$(_kit_info 'If you run the command with \".\" (e.g. kit list .), it lists the scripts associated with the current directory.')"
    "$(_kit_info 'Use the --json option to get the output in JSON format.')"

    "\nUsage: "
    "  $(_kit_highlight 'kit list [.] [-j|--json]')"
    "  $(_kit_highlight 'kit list [-h|--help]')"
  )

  local list_path="*"
  local format=""

  if [[ ! -z "$1" && "$1" != -* ]]; then
    list_path="$1"
    shift
  fi

  local flag_help
  local flag_json
  zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {j,-json}=flag_json ||
    return 1

  if [[ -n "$flag_help" ]]; then
    print -l $usage
    return
  fi

  local scripts
  if [[ "$list_path" == "*" ]]; then
    scripts=($(_kit_util_get_script_names))
  else
    local current_path=$(pwd)
    scripts=($(jq -r --arg path "$current_path" 'if .[$path] != null then .[$path][] else empty end' $(_kit_util_get_path_mapping_path)))
  fi

  if [[ ! -z "$flag_json" ]]; then
    local data="{}"
    for script in "${scripts[@]}"; do
      manifest=$(_kit_cmd_manifest "$script")
      data=$(echo "$data" | jq --arg script "$script" --argjson manifest "$manifest" '. + {($script): $manifest}')
    done

    echo $data | jq .
  else
    for script in "${scripts[@]}"; do
      echo $script
    done
  fi
}

function _kit_cmd_cd() {
  local script_name=$1

  if [[ -z "$script_name" ]]; then
    echo "$(_kit_info 'No script name provided.')"
    echo "$(_kit_info 'Please specify the name of the script you want to switch to.')"

    return 1;
  fi

  local script_path="$(_kit_util_get_repo_path)/$script_name"

  if [[ ! -d $script_path ]]; then
    echo "$(_kit_info "The script '$script_name' does not exist in the repository.")"
    echo
    echo "$(_kit_info 'You can list available scripts using') $(_kit_highlight 'kit list')"
    return 1
  fi

  command cd $script_path
}

function _kit_util_run_script_by_name() {
  local script_name=$1
  shift
  local script_args=$@

  local script_path="$(_kit_util_get_repo_path)/$script_name"

  if [[ ! -d "$script_path" ]]; then
    echo "$(_kit_error "Script '$script_name' does not exist")"
    return 1
  fi

  local manifest_file="$(_kit_util_get_repo_path)/$script_name/manifest.json"
  local manifest=$(command cat $manifest_file)

  local exec=$(echo $manifest | jq -r --arg field "exec" '.[$field]')
  local entry=$(echo $manifest | jq -r --arg field "entry" '.[$field]')

  if [[ -z "$exec" || "$exec" == "null" ]]; then
    "$script_path/$entry" "$@"
  else
    if [[ -z "$entry" ]]; then
      eval "$exec" $@
    else
      eval "$exec" "$script_path/$entry" $@
    fi
 
  fi
}

function _kit_util_update_path_mappings() {
  local script_name=$1
  local script_path=$2

  local path_mapping_file_path=$(_kit_util_get_path_mapping_path)

  # Check the script path exists
  if jq --arg path "$script_path" 'has($path)' $path_mapping_file_path | grep -q 'true'; then
    local scripts=($(jq -r --arg path $script_path '.[$path][]' $path_mapping_file_path))

      # Check if the script name is already in the list
      if [[ ${scripts[(Ie)$script_name]} -le 0 ]]; then
        jq --arg path "$script_path" --arg name "$script_name" \
          '.[$path] += [$name]' $path_mapping_file_path > "$(_kit_util_get_repo_path)/.temp.json"
      fi
  else 
      jq --arg path "$script_path" --arg name "$script_name" \
        '. + {($path): [$name]}' $path_mapping_file_path > "$(_kit_util_get_repo_path)/.temp.json"
  fi

  mv "$(_kit_util_get_repo_path)/.temp.json" $path_mapping_file_path
}

function _kit_util_get_user_config_path() {
  local config_path
  if [[ -n "$XDG_CONFIG_HOME" ]]; then
    config_path=$XDG_CONFIG_HOME
  else
    config_path=$HOME/.config
  fi

  echo $config_path
}

function _kit_util_get_default_editor() {
  if [[ -n "$EDITOR" ]]; then
    echo "$EDITOR"
  elif [[ -n "$VISUAL" ]]; then
    echo "$VISUAL"
  else
    echo "vim"
  fi
}

function _kit_util_get_config() {
  local config_path=$(_kit_util_get_user_config_path)
  command cat "$config_path/kit/config.json"
}

function _kit_util_get_repo_path() {
  local config_path=$(_kit_util_get_config)

  echo $config_path | jq -r .repo
}

function _kit_util_get_path_mapping_path() {
  local repo_path="$(_kit_util_get_repo_path)"

  echo "$repo_path/.kit_path_mapping.json" 
}

function _kit_util_get_script_names() {
  echo $(command ls -d $(_kit_util_get_repo_path)/*/ | xargs -n 1 basename)
}

function _kit_help() {
  echo "kit helps you create, organize and run scripts across projects."
  echo "Store scripts centrally or link them to specific directories for easy access"
  echo "based on your current location. It simplifies script management with project-specific"
  echo "scoping and interactive searching."
  echo
  echo "Usage: $(_kit_info 'kit {command} [options]')"
  echo
  echo "Commands:"
  echo "  $(_kit_highlight 'init')        Initialize kit"
  echo "  $(_kit_highlight 'create')      Create a new script"
  echo "  $(_kit_highlight 'run')         Run a script with additional arguments"
  echo "  $(_kit_highlight 'open')        Open the specified script in the default editor"
  echo "  $(_kit_highlight 'manifest')    Update the manifest file for an existing script"
  echo "  $(_kit_highlight 'fix')         Synchronize the path mappings by removing outdated or broken entries"
  echo "  $(_kit_highlight 'rm|remove')   Remove one or more scripts from the repo"
  echo "  $(_kit_highlight 'ls|list')     List available scripts"
  echo "  $(_kit_highlight 'cd')          Change to the script's directory"
  echo
  echo "Options:"
  echo "  -h, --help      Show this help message"
}

# Green text with a check mark
_kit_success() {
  echo -e "\e[32m✔ $1\e[0m"
}

# Blue text for info
_kit_info() {
  echo -e "\e[34m$1\e[0m"
}

# Bold text for highlighting
_kit_highlight() {
  echo -e "\e[1m$1\e[0m"
}

# Red text with a cross mark for errors
_kit_error() {
  echo -e "\e[31m✘ $1\e[0m"
}

_kit_completion() {
  local state
  typeset -A opt_args

  _arguments \
    '1: :->subcmd' \
    '2: :->script' && return 0

  case $state in
    subcmd)
      compadd init create run open manifest fix remove list cd
      ;;
    script)
      if [[ $words[2] == "run" || 
            $words[2] == "open" || 
            $words[2] == "manifest" || 
            $words[2] == "remove" || 
            $words[2] == "rm" ||
            $words[2] == "cd" ]]; then
        local scripts=($(_kit_util_get_script_names))

        compadd "$@" $scripts
      fi
      ;;
  esac
}

compdef '_kit_completion' kit
