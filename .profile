# Must be written using only portable Bourne shell syntax and commands.
# Leave shell specific customization to appropriate rc files.
# Where possible we try to use only commands we also have in emergency
# situations, like when in single user mode when nothing but the root
# file system is mounted, i.e. restrict to commands in /bin, /sbin or
# similar directories on the root file system.

# .profile is sourced at login by sh, ksh and bash. The zsh sources .zshrc.
# To get the same behaviour from zsh as well I did "cd; ln .profile .zshrc"
echo "File: ~${LOGNAME}/.profile"   # Tell the world who is responsible

# How do we suppress echo's newline on this system?
if test "x`echo -n`" = x-n; then
	# Ugh, System V echo.
	ECHO='echo'
	NONL='\c'
else
	# BSD, the One True Echo.
	ECHO='echo -n'
	NONL=''
fi

# Find the unqualified hostname.
if hostname >/dev/null 2>&1; then
	case `hostname` in
	*.*) _HOST=`echo 's/\..*//p' | ed -s '!hostname'`;;
	*)   _HOST=`hostname`;;
	esac
else
	_HOST=`uname -n | sed 's/\..*//'`
fi

# Find out what (Bourne compatible) shell we are running under. Put the result
# in $_SHELL (not $SHELL) so further actions can dependent on the shell type.
if test -n "${ZSH_VERSION}"; then
	_SHELL=zsh
elif test -n "${BASH_VERSION}"; then
	_SHELL=bash
elif test -n "${FCEDIT}"; then
	_SHELL=ksh
elif test "${PS3}" = ""; then
	_SHELL=sh
else
	_SHELL=unknown
fi

# Set _OS to a string describing the operating system type.
# The possible OS types are arbitrary, they are used to
# distinguish OS specific _setups. Modify to your liking.
# FreeBSD has a statically linked /sbin/sysctl on the root fs.
_OS="`sysctl -n kern.ostype 2>/dev/null`"
if test -z "${_OS}"; then
	case "`uname -sr`" in
		*BSD*)     _OS=`uname -s`;;
		SunOS\ 4*) _OS=SunOS;;
		SunOS\ 5*) _OS=Solaris;;
		IRIX\ 5*)  _OS=IRIX;;
		HP*)       _OS=HP-UX;;
		Linux*)    _OS=Linux;;
		*)         _OS=generic
			echo "warning: can't map \"`uname -sr`\" to an OS string,"
			echo "assuming ${_OS}. Edit your .profile if this is wrong."
		;;
	esac
fi

if test "x${HOME}" = x; then
	HOME=/root    # FreeBSD: in single user mode HOME is not set.
	export HOME   # This makes the /bin/sh read the files in /root.
	cd
fi

case "${_SHELL}" in
	bash)
		echo 'Shell: bash'
		;;
	ksh)
		echo 'Shell: ksh'
		;;
	sh)
		echo 'Shell: sh'
		;;
	zsh)
		echo 'Shell: zsh'
		setopt shwordsplit
		;;
	*)
		echo "Please add an entry for ${_SHELL} in ${HOME}/.profile"
		;;
esac

# Set umask
umask u=rwx,g=rx,o=rx

# Set the sequence of initialization:
# functions is first so that functions are usable by other dot files;
# functions, envars and aliases should not produce any output. Commands
# producing output should be executed in rc files.
# Does this shell support aliases? (Historic /bin/sh does not.)
if alias >/dev/null 2>&1; then
	_SETUP="functions envars aliases rc"
else
	_SETUP="functions envars rc"
fi

_PRINT=echo
for _setup in ${_SETUP}; do
	${_PRINT} "Setting up ${_setup}:"
	if test -r ${HOME}/.${_setup}; then
		${_PRINT} "  universal"
		. ${HOME}/.${_setup}
	fi
	for _WHAT in  \
		${_OS}    \
		${_HOST}  \
		${_SHELL} \
		${_OS}.${_HOST}    \
		${_OS}.${_SHELL}   \
		${_HOST}.${_SHELL} \
		${_OS}.${_HOST}.${_SHELL} \
		; do
		if test -r ${HOME}/.${_setup}.${_WHAT}; then
			${_PRINT} "  ${_WHAT} specific"
			. ${HOME}/.${_setup}.${_WHAT}
		fi
	done
done
unset _setup _SETUP _OS _HOST _SHELL _WHAT _PRINT
: # Force a true exit status.
