# default to zsh so a bare `source alias.bashrc` (realias/rr) still lands
# in a valid branch instead of skipping both shell-specific blocks
myShell="${1:-${myShell:-zsh}}"

#################################################################
#######################  varibels ###############################
## {{SYSADMIN_DIR}} is substituted by 05_shell/apply.sh from the station
## config (station.sysadmin_dir, default /data/sysadmin) — one knob
## per station instead of a hardcoded path here.
sys="{{SYSADMIN_DIR}}"
SYSADMIN=$sys
bashRoot="$sys/00_bashrc"
bashScripts="$sys/01_scripts"
bashColor="$bashRoot/bashrc_colors"
bashAlias="$bashRoot/alias.bashrc"
helpRoot="$sys/help"
gitRoot="$HOME/proj/myGits"

#################################################################
#######################  secrets (optional) ######################
# source-if-present: real values never live in this file or in git.
# See gensys/secrets/README.md. {{GENSYS_REPO_ROOT}} is substituted by
# 05_shell/apply.sh at copy time with this repo clone's actual location
# (computed live, not hand-edited) — works regardless of where the repo
# ends up checked out.
[ -f "{{GENSYS_REPO_ROOT}}/secrets/hosts.env" ] && source "{{GENSYS_REPO_ROOT}}/secrets/hosts.env"
# GPT_API is an env file too (exports OPENAI_API_KEY), not a raw key —
# sourcing it here is what makes claude-monitor & co find the key.
[ -f "{{GENSYS_REPO_ROOT}}/secrets/api-keys/GPT_API" ] && source "{{GENSYS_REPO_ROOT}}/secrets/api-keys/GPT_API"

#################################################################
#######################  folders  ###############################
proj="/proj"
data="/data"

#################################################################
#######################  PATH  ##################################
PATH=$PATH:$HOME/.vim/plugin
export EDITOR='vim'

#################################################################
######################## general ################################
alias 88="ping 8.8.8.8"
alias space='df -h |head -1 ; df -h | head -4 | tail -1 ;df -h | grep data'
alias realias='source $bashAlias $myShell'
alias rr=realias
alias vialias='vi $bashAlias ; realias'
alias vimrc='vi ~/.vimrc'
mkcd() { mkdir -p "$1" && cd "$1" ; }
alias hyber='systemctl hibernate'   # pm-hibernate (pm-utils) is long gone from Ubuntu
alias firefox2="ulimit -Sv 700000 && firefox"
alias ee=eog
alias ss="sleep 1 ; xset -display :0 dpms force off"

# bilingual (English/Hebrew) keyboard input-source toggle
alias keySetEng="gsettings set org.gnome.desktop.input-sources current 0"
alias keySetHeb="gsettings set org.gnome.desktop.input-sources current 1"

#################################################################
#######################  system  ################################
alias sys='cc ; cd $sys ; tit "sysadmin" '
alias data='cc ; cd $data ; tit "data" ; a'

#################################################################
#######################  console  ###############################
alias cc='clear -x'
alias xx='exit'

#################################################################
######################## file browser  ###########################
alias nn='nnn'

#################################################################
######################## clipboard  #############################
function clip2file() { echo saveImgTo=./$1.png ; xclip -selection clipboard -t image/png -o > $1.png ;}
alias c2f=clip2file
function showImgFunction() { eog $1 ; }
alias img="showImgFunction $1"

#################################################################
######################## tops  ##################################
alias topmem=' free -h ;echo " "  ;ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head'
alias mm=topmem
## for 5 sec
alias topCpu="timeout 5 top -b -d 1 -c | awk '\$1 ~ /^[0-9]+$/ && \$9>70 {print \"Process ID: \" \$1, \"CPU Usage: \" \$9 \"%\", \"Command: \" substr(\$0, index(\$0,\$12))}'"

#################################################################
######################## network  ################################
alias publicIP="wget -qO- http://ipecho.net/plain ; echo"
alias stip='$bashScripts/shell/setStaticIPbyUUID.sh'

#################################################################
######################## PS1 ####################################

PS1CLEAN="${PS1CLEAN:-$PS1}"   # capture once — realias must not re-capture the prefixed prompt
SPACE=main
if [[ $myShell == "bash" ]] ; then
        #colorize
        source $bashColor
        if [ `whoami` == root ]
        then
        PS1="($SPACE)\[$txtblu\]\[\e]0;$tit\a\]\[$txtred\]${debian_chroot:+($debian_chroot)}\u@\[$txtblu\]\h:\w\$\[$txtrst\] "
        else
        PS1="($SPACE)\[$txtblu\]\[\e]0;$tit\a\]\[$txtylw\]${debian_chroot:+($debian_chroot)}\u@\[$txtblu\]\h:\w\$\[$txtrst\] "
        fi
        alias ps1sht='export PROMPT_DIRTRIM=1'
        alias ps1wht='PS1="\[$txtwht\]\[\e]0;\u@\h: \w\a\]\[$txtwht\]${debian_chroot:+($debian_chroot)}\u@\[$txtwht\]\h:\w\$\[$txtrst\] "'
  alias tit='source $bashScripts/shell/tit.sh $1'
fi

if [[ $myShell == "zsh" ]] ; then
# In ZSH, you need to create an alias using a function to support parameters.
function tit() { source $bashScripts/shell/titZSH.sh $1 ;}
PS1="($SPACE)$PS1CLEAN"
fi

#################################################################
######################## help    ################################
## pages live in gensys/03_help/, installed to $helpRoot by 05_shell
alias h='cc; cat $helpRoot/welcome'
alias hh='cc; cd $helpRoot ; ls '
alias h.alias='cc; cat $helpRoot/h_alias'
alias aliash=h.alias
alias h.keys='cc; cat $helpRoot/h_keys'
alias kk=h.keys
alias h.git='cc; cat $helpRoot/h_git'
alias h.docker='cc; cat $helpRoot/h_docker'
alias h.wifi='cc; cat $helpRoot/h_wifi'
alias h.pdf='cc; cat $helpRoot/h_pdf'
alias h.code='cc; cat $helpRoot/h_code'
alias h.dev='cc; cat $helpRoot/h_dev'
alias h.find='cc; cat $helpRoot/h_find'
alias h.ai='cc; cat $helpRoot/h_ai'
alias h.ts='cc; cat $helpRoot/h_tailscale'
alias h.tailscale=h.ts
alias h.services='cc; cat $helpRoot/h_services'
alias h.gensys='cc; cat $helpRoot/h_gensys'
alias a='cc ; if [ -f ./readme.md ]; then cat ./readme.md ; else cat ./README.md ; fi '
alias aa='vi ./readme.md ; cc ; cat ./readme.md '

#################################################################
######################## REGOLITH ###############################
alias reg-conf='cd ~/.config/regolith'
alias reg-fresh="regolith-look refresh"
alias reg-reload="i3-msg reload"
## rename shell
function i3-name() { $bashScripts/shell/wrsp_name.sh  $1 ; }
alias name="i3-name"
## open a new workspace with a name, instead of a bare number
function i3-newname() { $bashScripts/shell/wrsp_addNewNamed.sh  $1 ; }
alias newname="i3-newname"
## move the focused i3 workspace to a physical monitor output — the
## scripts carry {{MON_*}} tokens rendered per-station from
## desktop.monitors.* (see 00_configs/<station>.yaml), so this stays
## general even though the monitor names behind it aren't.
alias wname='$bashScripts/multiScreen/thisName.sh'
alias ll0='$bashScripts/multiScreen/scrLay0.sh'
alias ll1='$bashScripts/multiScreen/scrLay1.sh'
alias ll2='$bashScripts/multiScreen/scrLay2.sh'

#################################################################
#################### HW  ########################################
## Station-specific serial/USB peripherals (which device lands on which
## ttyUSBn is per-box) live in 00_configs/<station>_aliases, not here.

#################################################################
############### local programs  #################################
#################################################################
PROJROOT="$HOME/proj"

alias ll="$bashScripts/maps/mapls.sh"

## taskStack — fzf-based multi-project task-runner. Code lives on /data
## (survives the reinstall via 04_storage, same-disk reasoning as the
## personal agent servers in 08_ai-agent-tools — nothing to vendor here,
## just the alias). /data/.taskit.projects (the project list) is on /data
## too, so it survives as-is; edit it there to add/remove projects.
## Path is the real /data one — the /data/proj→/proj bind mount is optional
## and applied by no layer (04_storage/README.md "On-demand bind mounts").
tasks_script="/data/proj/myGits/syso/stacker/taskStack/demo1.sh"
alias pp='source $tasks_script /data/.taskit.projects'

alias jupi="jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --NotebookApp.token='' --NotebookApp.password='' $HOME/proj"
alias jlab="jupyter lab"
## Obsidian binary (/usr/bin/obsidian) is installed by 01_base (official
## .deb) — the old alias pointed at an AppImage under $sys/local that only
## existed on the pre-merge host.
alias oo='obsidian'

#################################################################
###############   GIT    ########################################
#################################################################
## add ssh keys to each shell — key files themselves live under secrets/ssh/
## (gensys/secrets/README.md), NOT here. Same {{GENSYS_REPO_ROOT}}
## substitution as the "secrets (optional)" block above.
## gitKey_private_gitlab was referenced by the pre-merge alias file but no
## such key file was ever found on the source host — dropped rather than
## fabricated.
alias git.solerom="ssh-add {{GENSYS_REPO_ROOT}}/secrets/ssh/gitKey_private_github 1>/dev/null 2>/dev/null"
alias git.trip="ssh-add {{GENSYS_REPO_ROOT}}/secrets/ssh/tripRepo_ 1>/dev/null 2>/dev/null"
alias git.keys="ssh-add -l"
## no killall/restart here: SSH_AUTH_SOCK is served by the desktop's
## socket-activated gcr-ssh-agent (always up), not a literal "ssh-agent"
## process — killall only ever matched an unrelated legacy child gnome-
## keyring-daemon spawns for a socket nothing uses, so it did nothing but
## print "ssh-agent: no process found" when that child wasn't up.
alias git.sol="git.solerom"

alias gitstat="git status -s"
alias gitall="$bashScripts/gitScripts/statusOnAll.sh $gitRoot"
alias gitorphen="bash $bashScripts/gitScripts/gitBookOrpRunner.sh ."
alias gitsrc="git config --get remote.origin.url"
alias gitFromMain="echo pls run: git pull origin main"
alias git.ls="curl -s  https://api.github.com/users/solerom/repos | grep -o 'git@[^\"]*' "

gitup() {
  # Check if current directory is inside a git repository
  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not inside a Git repository."
    return 1
  fi
  local message="${1:-auto update}"
  git add .
  git commit -m "$message"
  git push
}

alias mygit='clear; cd $gitRoot ; git.sol; tit "my-gits" '

#################################################################
###############   TMUX    ########################################
#################################################################
alias tmux.tree='$bashScripts/tmux/lisTree.sh'

#################################################################
######################## /proj    ###############################
#################################################################
## connect over ssh — embedded dev board. Both DEVBOARD_IP and DEVBOARD_PASS
## come from secrets/hosts.env (PASS is the board family's default, not
## actually sensitive — see the note there)
alias sshh='sshpass -p "$DEVBOARD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DEVBOARD_IP}'

alias home='cc ; tit projHOME ; cd $PROJROOT ; ls'

#################################################################
######################## remote hosts (secrets/hosts.env)  #######
#################################################################
alias vps1='sshpass -p "$VPS1_PASS" ssh ${VPS1_USER}@${VPS1_HOST}'
alias tab1='sshpass -p "$TAB1_PASS" ssh -p ${TAB1_PORT} ${TAB1_HOST}'
alias sshlp='sshpass -p "$SSHLP_PASS" ssh ${SSHLP_USER}@${SSHLP_HOST}'

#################################################################
#################### dockers ####################################
alias dok_ps='sudo docker ps'
alias dok_ls='docker container ls -a'
alias d.killall='docker kill $(docker ps -q)'

#################################################################
######################## code    ################################
alias vv='cscope -R'

#################################################################
######################## SERVICES ################################
alias nfson='service nfs-kernel-server restart;echo exported: ; exportfs'
alias nmres='service network-manager restart'
alias nmoff='service network-manager stop'

#################################################################
######################## /aproj    ###############################
#################################################################
alias ap='cd $HOME/aproj'

#################################################################
######################## /agents  ###############################
#################################################################
alias cld='claude --dangerously-skip-permissions'
alias cld_mon='claude-monitor'
alias clw_start='systemctl --user restart openclaw-gateway.service'
alias clw_stop='systemctl --user stop openclaw-gateway.service'
alias oll_start='sudo systemctl restart ollama'
alias oll_stop='sudo systemctl stop ollama'

#################################################################
################ station-specific aliases (LAST) #################
## The active station's <station>_aliases companion (next to its yaml in
## 00_configs/, see that README's "Separation contract") is installed by
## 05_shell/apply.sh under the fixed name $bashRoot/station_aliases — this
## line needs no station knowledge. Sourced last on purpose: the station
## file uses vars set above ($sys, $data, $proj, $tasks_script) and may
## override general aliases. Stations without a companion simply have no
## file here — silently skipped (if-form, not `[ ] &&`: this is the file's
## last command, and a bare failed test would make sourcing alias.bashrc
## itself return non-zero on companion-less stations).
if [ -f "$bashRoot/station_aliases" ]; then
  source "$bashRoot/station_aliases"
fi
