# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Biblioteca com utilitario (ex: chamada de trans)
source ~/bomnegocio/lib/bash/lib_bn.sh

#source ~/.git-prompt.sh

# User specific aliases and functions
export GREP_OPTIONS='--color=auto'
export DISPLAY=mbpdothgosalles.srv.office:0.0
export NUMBER_OF_PARALLEL_JOBS=1
export PAGER="less"

parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}
get_current_date() {
	date +%Y%m%d
}
function apagabranch() {
        git push origin :$1
        git branch -D $1
        echo git branch -D $1
}
function genport() {
    echo $(expr \( $(id -u) - \( $(id -u) / 100 \) \* 100 \) \* 200 + 20000 + ${1})
}
function CC() {
  if [ -n "$1" ]; then
	git checkout CTC-$1
  else
	echo "Informe o código da issue."
  fi
}
export TRANS_PORT=$(genport 5)

function unit-tt() {
  if [ -n "$1" ]; then
	cd ~/bomnegocio/daemons/trans && make rs-$1 && cd ~/bomnegocio
  else
	echo "Informe o teste de trans."
  fi
}

function unit-ta() {
  if [ -n "$1" ]; then
	cd ~/bomnegocio/regress/final && make rs-api-$1 && cd ~/bomnegocio
  else
	echo "Informe o teste de api."
  fi
}

# get bconf entries from trans
# usage examples:
# $ bconf
# $ bconf common.brand
# $ bconf common.brand 23205
function bconf() {
    # get the project folder
    local PROJ_FOLDER=bomnegocio

    # get transaction-server port
    local REGRESS_TRANS_PORT=$2
    if [ ! -n "$2" ]; then
        local REGRESS_TRANS_PORT=`awk '/REGRESS_TRANS_PORT/{ print $3 }' ${HOME}/$PROJ_FOLDER/build/constants`
    fi

    # execute command grepping for the desired key
    if [ -n "$1" ]; then
        printf "cmd:bconf\ncommit:1\nend\n" | nc localhost $REGRESS_TRANS_PORT | grep ${1} --color=auto
    else
        printf "cmd:bconf\ncommit:1\nend\n" | nc localhost $REGRESS_TRANS_PORT
    fi
}

function trans() {
        trans_port=$(genport 5)
        printf "cmd:$(echo "$@" | tr ' ' '\n' | tr '\#' ' ')\ncommit:1\nend\n---\n"
        printf "cmd:$(echo "$@" | tr ' ' '\n' | tr '\#' ' ')\ncommit:1\nend\n" | nc localhost ${trans_port}
}

function get_ip(){
        ifconfig | grep 'inet addr' | cut -d: -f2 | awk '{print $1}' | head -1
}

function bdb_cmd(){
        echo "$(make -C $HOME/bomnegocio rinfo 2>/dev/null| grep -e '^psql' |tr ';' ' ')"
}

function generate_dev_token(){
        curl -X POST -d "username=dev&cpasswd=&login=Login" -k https://dev03c6.srv.office:23811/controlpanel
        last_dev_token
}

function last_dev_token(){
        $(bdb_cmd) -tc 'select token from tokens where admin_id=9999 order by created_at desc limit 1' | tr -d '\n '
}

function last_ad(){
        $(bdb_cmd) -tc 'select ad_id from ads order by ad_id desc limit 1' | tr -d '\n '
}

function last_unreview_ad(){
        $(bdb_cmd) -tc "select ad_id from ad_actions where state in ('pending_review', 'locked') order by ad_id desc limit 1" | tr -d '\n '
}

function review_ad(){
        ad_id=$1
        last_action_id=$($(bdb_cmd) -tc 'select action_id from ad_actions where ad_id='$ad_id' order by action_id desc limit 1' | tr -d '\n ')
        token=$(generate_dev_token)
        trans review token:$token ad_id:$ad_id action_id:$last_action_id remote_addr:$(get_ip) action:accept filter_name:accepted
}

function review_last_ad(){
        if [[ $(last_unreview_ad | wc -c) > 0 ]]; then
          review_ad $(last_unreview_ad)
        else
          echo "WARNING: There is not ad in the pending review queue"
        fi
}

function testtrans(){
        if [ -n "$1" ]; then
                DISPLAY=:$(id -u) BROWSER=firefox bundle exec rspec -e "Legacy Trans Tests $1"
        else
                bundle exec rake test $(find spec/transactions/ -type f)
        fi
}

function testapi(){
        if [ -n "$1" ]; then
                DISPLAY=:$(id -u) BROWSER=firefox bundle exec rspec -e "Legacy API Tests $1"
        else
                rake firefox test $(find spec/api/ -type f)
        fi
}

function vaila() {
		if [[ "$(parse_git_branch)" == "release" ]]; then
			if [ ! -n "$1" ]; then
				echo "É o RELEASE ou a TAG que quer mandar???"
			else
				git push origin $1
			fi
		else
		  	git push origin $(parse_git_branch)
		fi
}

function commit_msg() {
		if [ ! -n "$1" ]; then
			echo "Cadê a mensagem do commit???"
		else
			echo 'git commit -m "'$(parse_git_branch)' - '$1'."'
			git commit -m "$(parse_git_branch) - $1."
		fi
}

function fuse() {
	    local SERVER="dev02c6"
	    local USER="lmaia"
	    local VOLUME="/Volumes/${SERVER}"
		diskutil unmount force /Volumes/dev02c6
		#umount $VOLUME
		mkdir -p $VOLUME
		sshfs -o auto_cache,reconnect,workaround=all ${USER}@${SERVER}.srv.office:/home/${USER}/$VOLUME
}

# List USs from the last TAG until now
function uss_from_last_tag { git log --grep=$1 $(git rev-parse --abbrev-ref HEAD) --not $(git describe --long --match 'v[0-9.]*' | perl -ne '/(v[0-9.]+)-([0-9]*)-g[0-9A-F]*/i; print $1') | perl -nle 'BEGIN{$pre=shift}$uss{$&}++ if /\b$pre-?\d+/i}{print for sort {my $na = $& if $a =~ /\d+$/; my $nb = $& if $b =~ /\d+$/; return $na <=> $nb} keys %uss' $1; suspects=$(git log --all-match --grep="$1" --grep="This reverts commit" $(git rev-parse --abbrev-ref HEAD) --not $(git describe --long --match 'v[0-9.]*' | perl -ne '/(v[0-9.]+)-([0-9]*)-g[0-9A-F]*/i; print $1') | perl -nle 'BEGIN{$pre=shift}$uss{$&}++ if /\b$pre-?\d+/i}{print for sort {my $na = $& if $a =~ /\d+$/; my $nb = $& if $b =~ /\d+$/; return $na <=> $nb} keys %uss' $1); [ -z "$suspects" ] || echo -e "\nUSs suspected to be reverted:\n$suspects"; }

# Reset
Color_Off='\e[0m'       # Text Reset


# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

# Aliases
alias lm='echo Luciano \"Lûk\" Maia'
alias ll='ls -lhas --color=auto'
alias rf='make -C ~/bomnegocio rfast'
alias ra='make -C ~/bomnegocio rall'
alias gg='git grep'
alias gst='git st'
alias gss='git stash'
alias gsd='git sdiff'
alias gd='git diff'
alias gbr='git branch'
alias gbl='git blame'
alias gt='git tag -a'
alias gm='git merge --no-ff'
alias ga='git add'
alias gco='git co'
alias gci='gcim'
alias gcim='commit_msg'
alias gcia='git ci --amend'
alias gl='git log'
alias gsw='git show'
alias grb='git rebase'
alias grs='git reset'
alias grv='git revert'
alias gcp='git cherry-pick'
alias M='git co master'
alias S='git co stable'
alias R='git co release'
alias cc='CC'
alias cC='CC'
alias Cc='CC'
alias ltt='rtest spec/transactions/legacy_spec.rb'
alias utt='unit-tt'
alias unitt='unit-tt'
alias uta='unit-ta'
alias unita='unit-ta'
alias rtest='bundle exec rake test'
alias rr='bundle exec rake firefox test rerun'
alias xton= 'trans bconf_overwrite key:*.*.common.stat_counter.xiti.display value:1 && make -C ~/bomnegocio apache-restart'
alias xtoff='trans bconf_overwrite key:*.*.common.stat_counter.xiti.display value:0 && make -C ~/bomnegocio apache-restart'
alias tt='bundle exec rake test $(find ~/bomnegocio/spec/transactions/ -type f)'
alias ta='bundle exec rake test $(find ~/bomnegocio/spec/api/ -type f)'
alias makesfa='make -C ~/bomnegocio rc kill && make -C ~/bomnegocio cleandir++ && make -C ~/bomnegocio rall'
alias i='make -C ~/bomnegocio rinfo'
alias bn='cd ~/bomnegocio'
alias c='~/bomnegocio/compile.sh'
alias car='~/bomnegocio/compile.sh && make -C ~/bomnegocio apache-restart'
alias ama="bundle exec rake account_mail_accept"
alias bdb='$(make -C ~/bomnegocio rinfo | grep -oe "^psql.*[^;]")'
alias pega="git fetch origin; git pull --rebase origin \$(parse_git_branch)"
alias pulla='pega'
alias vemca='pega'
alias manda='vaila'
alias pusha='manda'
alias pm='pega && manda'
alias redis_account='$(make -C ~/bomnegocio rinfo | grep "redis accounts server" | perl -pe "s/ - redis accounts server//g")'
alias redis_linkmanager='$(make -C ~/bomnegocio rinfo | grep "redis link manager server" | perl -F"\s+-\s+" -nale "print @F[0]")'
alias redis_paymentapi='$(make -C ~/bomnegocio rinfo | grep "redis payment api server" | perl -F"\s+-\s+" -nale "print @F[0]")'
alias redis_mobile='$(make -C ~/bomnegocio rinfo | grep "redismobile server" | perl -F"\s+-\s+" -nale "print @F[0]")'
alias redis_fav='$(make -C ~/bomnegocio rinfo | grep "redis favorites server" | perl -F"\s+-\s+" -nale "print @F[0]")'
alias flushdb='echo flushdb | redis_account'
alias vi='vim'
alias grep_nostuff="grep --exclude=*svn* --exclude=*.swp --exclude=*.o --exclude=*.so*"
alias vimdiff="vimdiff -c 'windo set wrap'"
alias tail_translog="clear; tail -f $HOME/bomnegocio/regress_final/logs/trans.log $HOME/bomnegocio/regress_final/logs/payment_trans.log"
alias tail_paymentlog="clear; tail -f /opt/logs/PAYMENT_CALLBACK/\$(get_current_date).log /opt/logs/PAYMENT/\$(get_current_date).log /opt/logs/PAYMENT_API/\$(get_current_date).log /opt/logs/RECEIPT/\$(get_current_date).log $HOME/bomnegocio/regress_final/logs/payment_trans.log"
alias tail_controlpanel="clear; tail -f $HOME/bomnegocio/regress_final/logs/trans.log /opt/logs/CONTROLPANEL/\$(get_current_date).log"
alias retry="make -C ~/bomnegocio/ apache-regress-restart trans-regress-reload selenium_stop && make -C ~/bomnegocio/ selenium_start && make -C ~/bomnegocio/ rco"
alias ti="make -C ~/bomnegocio/ ti"
alias rb="make -C ~/bomnegocio/ rb"
alias rp="make -C ~/bomnegocio/ rp"
alias ri="make -C ~/bomnegocio/ rebuild-index"
alias rif="make -C ~/bomnegocio/ rebuild-index-full"
alias rept="make -C ~/bomnegocio/ rept"
alias rall="make -C ~/bomnegocio/ rall"
#alias delete_aindex="rm -rf $(sed -nre 's/.*db_name=//p' /home/tlima/bomnegocio/regress_final/conf/asearch.conf){,.new,.index} && make -C ~/bomnegocio/ rebuild-index-full"
#alias delete_zindex="rm -rf $(sed -nre 's/.*db_name=//p' /home/tlima/bomnegocio/regress_final/conf/zsearch.conf){,.new,.index} && make -C ~/bomnegocio/ rebuild-index-full"
alias ninja_compile="rm ~/bomnegocio/ninja_build/build.ninja && ~/bomnegocio/compile.sh"
alias open_modified="vim -p \`git status --porcelain | sed -ne 's/^ M ~\/bomnegocio\//p'\`"
alias add_new="git add -N \`git status --porcelain | sed -ne 's/^?? ~\/bomnegocio\//p'\`"
alias php_interactive="php -c ~/bomnegocio/ninja_build/regress/conf/php.ini -a"
alias desfaztudo="git reset --hard origin/\$(parse_git_branch)"
alias rodameufilho='make -C ../.. rall && make -C ../.. rc kill && make rc rd && make selenium_stop selenium_start'
alias :tabe='vi'
alias rtr='~/bomnegocio/regress_final/bin/template_runner'
alias ff='find . -iname'
alias rk='bundle exec rake'
alias bdb='$(bdb_cmd)'
alias bdbstage='psql -h 172.16.1.59 -U postgres blocketdb'
alias gerastage='make -C ~/bomnegocio rc kill && make -C ~/bomnegocio cleandir++ && rm -rf rpm/{ia32e,noarch} && make -C ~/bomnegocio rpm-staging'
alias i='make -C ~/bomnegocio rinfo'
alias esion='trans bconf_overwrite key:*.*.esi.enabled value:1 && make -C ~/bomnegocio/ apache-restart'
alias esioff='trans bconf_overwrite key:*.*.esi.enabled value:0 && make -C ~/bomnegocio/ apache-restart'

alias tags='git tag | sort -V'

alias auth_restart='make -C ~/bomnegocio/ auth_service-st{op,art}'

alias nextgen_compile='scl enable python33 bash ; git clean -fdx ; . bootstrap.sh ; ./compile.sh'
alias nextgen_test='scl enable python33 bash ; git clean -fdx ; . bootstrap.sh ; RUNTESTS=1 COVERAGE=1 ./compile.sh'

#alias nextgen_adreply='curl -v -d \'{"cc_sender": false, "message": {"email": "tsmlima@gmail.com", "phone": "", "name": "Thiago", "body": "Teste final 2"}}\' -H "Content-Type: application/json" http://dev02c6.srv.office:20817/api/v1/public/ads/3456789/messages'

alias uss='uss_from_last_tag QC; uss_from_last_tag CTC; uss_from_last_tag VER; uss_from_last_tag PEI; uss_from_last_tag NEX; uss_from_last_tag TF'

alias joia='token=$(trans authenticate username:dev passwd:da39a3ee5e6b4b0d3255bfef95601890afd80709 remote_addr:127.0.0.1 | grep token) && trans nb_tool_copy_from_production remote_addr:127.0.0.1 $token'
alias superjoia='make -C ~/bomnegocio/ rall && bdb < release.txt && > regress_final/logs/trans.log && joia'
alias joiainvbconf='token=$(trans authenticate username:dev passwd:da39a3ee5e6b4b0d3255bfef95601890afd80709 remote_addr:127.0.0.1 | grep token) && trans nb_tool_copy_to_bconf_production deploy_id:1 remote_addr:127.0.0.1 $token'
alias joiainvdb='token=$(trans authenticate username:dev passwd:da39a3ee5e6b4b0d3255bfef95601890afd80709 remote_addr:127.0.0.1 | grep token) && trans nb_tool_copy_to_database_production deploy_id:1 remote_addr:127.0.0.1 $token'

alias enviaemail='make -C ~/bomnegocio/ sendmail-restore'
alias logaemail='make -C ~/bomnegocio/ sendmail-replace'

alias ocs='gco optional_confirmation_signup'

function trans_admin() {
	trans $* $(admin_token) remote_addr:127.0.0.1 remote_browser:Mozilla
}

function expire_ad(){
    if [ "$#" -lt 1 ]; then
        echo "Usage: expire_ad [list_id]";
        return
    fi

    printf "cmd:deletead\nid:"$1"\nmonthly:1\nreason:expired_deleted\ncommit:1\nend\n" | nc localhost ${TRANS_PORT} > .expire_ad_temp
    if [ "$(grep TRANS_ERROR .expire_ad_temp -i)" == "" ]; then
        printf "cmd:flushqueue\nqueue:monthly_deleted\ncommit:1\nend\n" | nc localhost ${TRANS_PORT}
		make -C ~/bomnegocio rebuild-asearch rebuild-dsearch
    fi

    cat .expire_ad_temp
    rm .expire_ad_temp
}

if [ -f ~/config/bashcolors ]; then
        . ~/config/bashcolors
fi

# Define basic PS1 with coloring: [User ~/Folder]
PS1="$IBlack\t$Green\u$Color_Off@$Cyan\h$Color_Off:$Blue\w$Color_Off|"
#PS1="\[$Green\]\t\[$Red\]-\[$Cyan\]\u\[$Yellow\]\[$Yellow\]\w\[\033[m\]\[$Magenta\]\$(__git_ps1)\[$White\]\$ "
# Define git stuff, if is in a git folder, it shows the name of the branch.
# And color it yellow when have no changes, and red if there is.
PS1=$PS1'$(git branch &>/dev/null;\
if [ $? -eq 0 ]; then \
  echo "$(echo `git status` | grep "nothing to commit" > /dev/null 2>&1; \
  if [ "$?" -eq "0" ]; then \
    # @4 - Clean repository - nothing to commit
    echo "'$Yellow'"$(__git_ps1 "%s"); \
  else \
    # @5 - Changes to working tree
    echo "'$IRed'"$(__git_ps1 "%s"); \
  fi)"; \
fi)'
export PS1=$PS1$Color_Off'\$ ';

# Auto-complete for the conf function bellow
complete -F _conf_complete conf
complete -C ~/scripts/rake_autocomplete.rb -o default rake

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

if [[ $PWD == $HOME ]]; then
	cd ~/bomnegocio/
fi

export LC_CTYPE=en_US.iso-8859-1
export LANG="$LC_CTYPE"
