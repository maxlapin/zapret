. "$IPSET_DIR/../config"

[ -z "$TMPDIR" ] && TMPDIR=/tmp
[ -z "$GZIP_LISTS" ] && GZIP_LISTS=1

[ -z "$IPSET_OPT" ] && IPSET_OPT="hashsize 262144 maxelem 2097152"
[ -z "$IPSET_OPT_EXCLUDE" ] && IPSET_OPT_EXCLUDE="hashsize 1024 maxelem 65536"

[ -z "$IPFW_TABLE_OPT" ] && IPFW_TABLE_OPT="algo addr:radix"
[ -z "$IPFW_TABLE_OPT_EXCLUDE" ] && IPFW_TABLE_OPT_EXCLUDE="algo addr:radix"


ZIPSET=zapret
ZIPSET6=zapret6
ZIPSET_EXCLUDE=nozapret
ZIPSET_EXCLUDE6=nozapret6
ZIPLIST="$IPSET_DIR/zapret-ip.txt"
ZIPLIST6="$IPSET_DIR/zapret-ip6.txt"
ZIPLIST_EXCLUDE="$IPSET_DIR/zapret-ip-exclude.txt"
ZIPLIST_EXCLUDE6="$IPSET_DIR/zapret-ip-exclude6.txt"
ZIPLIST_USER="$IPSET_DIR/zapret-ip-user.txt"
ZIPLIST_USER6="$IPSET_DIR/zapret-ip-user6.txt"
ZUSERLIST="$IPSET_DIR/zapret-hosts-user.txt"
ZHOSTLIST="$IPSET_DIR/zapret-hosts.txt"

ZIPSET_IPBAN=ipban
ZIPSET_IPBAN6=ipban6
ZIPLIST_IPBAN="$IPSET_DIR/zapret-ip-ipban.txt"
ZIPLIST_IPBAN6="$IPSET_DIR/zapret-ip-ipban6.txt"
ZIPLIST_USER_IPBAN="$IPSET_DIR/zapret-ip-user-ipban.txt"
ZIPLIST_USER_IPBAN6="$IPSET_DIR/zapret-ip-user-ipban6.txt"
ZUSERLIST_IPBAN="$IPSET_DIR/zapret-hosts-user-ipban.txt"
ZUSERLIST_EXCLUDE="$IPSET_DIR/zapret-hosts-user-exclude.txt"

BINPATH="$IPSET_DIR/../binaries/$(uname -p)"

IP2NET="$BINPATH/ip2net/ip2net"
MDIG="$BINPATH/mdig/mdig"
[ -z "$MDIG_THREADS" ] && MDIG_THREADS=30

exists()
{
 which "$1" >/dev/null 2>/dev/null
}

# BSD grep is damn slow with -f option. prefer GNU grep (ggrep) if present
# MacoS in cron does not include /usr/local/bin to PATH
if [ -x /usr/local/bin/ggrep ] ; then
 GREP=/usr/local/bin/ggrep
elif exists ggrep; then
 GREP=$(which ggrep)
else
 GREP=$(which grep)
fi

grep_supports_b()
{
 # \b does not work with BSD grep
 $GREP --version 2>&1 | $GREP -qE "BusyBox|GNU"
}
get_ip_regex()
{
 REG_IPV4='((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[12][0-9]|3[012]))?'
 REG_IPV6='[0-9a-fA-F]{1,4}:([0-9a-fA-F]{1,4}|:)+(/([0-9][0-9]?|1[01][0-9]|12[0-8]))?'
 # good but too slow
 # REG_IPV6='([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,7}:(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}(/[0-9]+)?|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}(/[0-9]+)?|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})(/[0-9]+)?|:((:[0-9a-fA-F]{1,4}){1,7}|:)(/([0-9][0-9]?|1[01][0-9]|12[0-8]))?'
 grep_supports_b && {
  REG_IPV4="\b$REG_IPV4\b"
  REG_IPV6="\b$REG_IPV6\b"
 }
}


ip2net4()
{
 if [ -x "$IP2NET" ]; then
  "$IP2NET" -4 $IP2NET_OPT4
 else
  sort -u
 fi
}
ip2net6()
{
 if [ -x "$IP2NET" ]; then
  "$IP2NET" -6 $IP2NET_OPT6
 else
  sort -u
 fi
}

zzexist()
{
 [ -f "$1.gz" ] || [ -f "$1" ]
}
zzcat()
{
 if [ -f "$1.gz" ]; then
 	gunzip -c "$1.gz"
 else
 	cat "$1"
 fi
}
zz()
{
 if [ "$GZIP_LISTS" = "1" ]; then
  gzip -c >"$1.gz"
  rm -f "$1"
 else
  cat >"$1"
  rm -f "$1.gz"
 fi
}
zzsize()
{
 local f="$1"
 [ -f "$1.gz" ] && f="$1.gz"
 wc -c <"$f" | xargs
}

digger()
{
 # $1 - hostlist
 # $2 - family (4|6)
 >&2 echo digging $(wc -l <"$1" | xargs) ipv$2 domains : "$1"

 if [ -x "$MDIG" ]; then
  zzcat "$1" | "$MDIG" --family=$2 --threads=$MDIG_THREADS --stats=1000
 else
  local A=A
  [ "$2" = "6" ] && A=AAAA
  zzcat "$1" | dig $A +short +time=8 +tries=2 -f - | $GREP -E '^[^;].*[^\.]$'
 fi
}

cut_local()
{
  $GREP -vE '^192\.168\.|^127\.|^10\.'
}
cut_local6()
{
  $GREP -vE '^::|^fc..:|^fd..:'
}

oom_adjust_high()
{
	[ -f /proc/$$/oom_score_adj ] && {
		echo setting high oom kill priority
		echo -n 100 >/proc/$$/oom_score_adj
	}
}

getexclude()
{
 oom_adjust_high

 [ -f "$ZUSERLIST_EXCLUDE" ] && {
  [ "$DISABLE_IPV4" != "1" ] && digger "$ZUSERLIST_EXCLUDE" 4 | sort -u > "$ZIPLIST_EXCLUDE"
  [ "$DISABLE_IPV6" != "1" ] && digger "$ZUSERLIST_EXCLUDE" 6 | sort -u > "$ZIPLIST_EXCLUDE6"
 }
}

getuser()
{
 getexclude
 [ -f "$ZUSERLIST" ] && {
  [ "$DISABLE_IPV4" != "1" ] && digger "$ZUSERLIST" 4 | cut_local | sort -u > "$ZIPLIST_USER"
  [ "$DISABLE_IPV6" != "1" ] && digger "$ZUSERLIST" 6 | cut_local6 | sort -u > "$ZIPLIST_USER6"
 }
 [ -f "$ZUSERLIST_IPBAN" ] && {
  [ "$DISABLE_IPV4" != "1" ] && digger "$ZUSERLIST_IPBAN" 4 | cut_local | sort -u > "$ZIPLIST_USER_IPBAN"
  [ "$DISABLE_IPV6" != "1" ] && digger "$ZUSERLIST_IPBAN" 6 | cut_local6 | sort -u > "$ZIPLIST_USER_IPBAN6"
 }
}

hup_zapret_daemons()
{
 echo forcing zapret daemons to reload their hostlist
 if exists killall; then
  killall -HUP tpws nfqws dvtws 2>/dev/null
 elif exists pkill; then
  pkill -HUP ^tpws$ ^nfqws$ ^dvtws$
 else
  echo no mass killer available ! cant HUP zapret daemons
 fi
}
