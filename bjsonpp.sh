# jwsy - https://github.com/jwsy/JSON.sh/blob/master/bjsonpp.sh
# bash and egrep JSON prettyprinter 
# Usage: ./bjsonpp.sh < jsonobj

# Adapted from https://github.com/dominictarr/JSON.sh

throw () {
  echo "$*" >&2
  exit 1
}

# JWSY for printing tabs
tabn () {
    if ! [[ $1 =~ ^[0-9]+$ ]] ; then
        echo "Error: $1 is Not a number"
    elif [[ $1 -eq 0 ]] ; then
        printf ""
    else  
        for i in `seq 1 $1`
        do
            printf "  "
        done
    fi 
}

tokenize () {
  local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
  local CHAR='[^[:cntrl:]"\\]'
  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'
  egrep -ao "$STRING|$NUMBER|$KEYWORD|$SPACE|." --color=never |
    egrep -v "^$SPACE$"  # eat whitespace
}

pp_array () {
  local tabstops=$2
  local index=0
  printf "\n"
  tabn $[tabstops]
  read -r token
  case "$token" in
    ']') 
        printf "\n"
        tabn $[tabstops-1]
        printf "]" ;;
    *)
      while :
      do
        pp_value "$1" "$index" ${tabstops}
        let index=$index+1
        read -r token
        case "$token" in
          ']') 
              printf "\n"
              tabn $[tabstops-1]
              printf "]"
              break ;;
          ',') 
              printf "," 
              printf "\n"
              tabn $[tabstops] ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  value=`printf '[%s]' "$ary"`
}

pp_object () {
  local tabstops=$2
  local key
  local obj=''
  read -r token
  case "$token" in
    '}') 
        tabn $[tabstops-1]
        printf "\n}" ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') 
              printf "\n"
              tabn ${tabstops}
              printf "${token} "
              key=$token ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') 
              printf ": " ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        pp_value "$1" "$key" $[tabstops+1]
        obj="$obj$key:$value"        
        read -r token
        case "$token" in
          '}') 
              printf "\n"
              tabn $[tabstops-1]
              printf "}"
              break ;;
          ',')
              printf "," 
              obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  value=`printf '{%s}' "$obj"`
}

pp_value () {
  local tabstops=$3
  local jpath="${1:+$1,}$2"
  case "$token" in
    '{')
        printf "{"
        pp_object "$jpath" $[tabstops+1] ;;
    '[') 
        printf "["
        pp_array  "$jpath" $[tabstops+1] ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[^0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *) 
        printf "%s" "${token}"
        value=$token ;;
  esac
  #printf "[%s]\t%s\n" "$jpath" "$value"
}

pp () {
  read -r token
  pp_value "" "" 0
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF GOT $token" ;;
  esac
}

if [ $0 = $BASH_SOURCE ];
then
  tokenize | pp
fi
