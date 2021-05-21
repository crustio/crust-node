#!/bin/bash

source $scriptdir/utils.sh

config_help()
{
cat << EOF
Crust config usage:
    help                                  show help information
    show                                  show configurations
    set                                   set and generate new configurations
    generate                              generate new configurations                              
EOF
}

config_show()
{
	cat $configfile
}

config_set_all()
{
	local chain_name=""
	read -p "Enter crust node name (default:crust-node): " chain_name
	chain_name=`echo "$chain_name"`
	if [ x"$chain_name" == x"" ]; then
		chain_name="crust-node"
	fi
	sed -i "22c \\  name: \"$chain_name\"" $configfile &>/dev/null
	log_success "Set crust node name: '$chain_name' successfully"

	local mode=""
	while true
	do
		read -p "Enter crust node mode from 'isolation/owner/member' (default:isolation): " mode
		mode=`echo "$mode"`
		if [ x"$mode" == x"" ]; then
			mode="isolation"
			break
		elif [ x"$mode" == x"isolation" ] || [ x"$mode" == x"owner" ] || [ x"$mode" == x"member" ]; then
			break
		else
			log_err "Input error, please input isolation/owner/member"
		fi
	done
	if [ x"$mode" == x"owner" ]; then
		sed -i '4c \\  chain: "authority"' $configfile &>/dev/null
		sed -i '6c \\  sworker: "disable"' $configfile &>/dev/null
		sed -i '8c \\  smanager: "disable"' $configfile &>/dev/null
		sed -i '10c \\  ipfs: "disable"' $configfile &>/dev/null
		log_success "Set crust node mode: '$mode' successfully"
		log_success "Set configurations done"
		return
	elif [ x"$mode" == x"isolation" ]; then
		sed -i '4c \\  chain: "authority"' $configfile &>/dev/null
		sed -i '6c \\  sworker: "enable"' $configfile &>/dev/null
		sed -i '8c \\  smanager: "'$mode'"' $configfile &>/dev/null
		sed -i '10c \\  ipfs: "enable"' $configfile &>/dev/null
		log_success "Set crust node mode: '$mode' successfully"
	else
		sed -i '4c \\  chain: "full"' $configfile &>/dev/null
		sed -i '6c \\  sworker: "enable"' $configfile &>/dev/null
		sed -i '8c \\  smanager: "'$mode'"' $configfile &>/dev/null
		sed -i '10c \\  ipfs: "enable"' $configfile &>/dev/null
		log_success "Set crust node mode: '$mode' successfully"
	fi

	local identity_backup=""
	while true
	do
		if [ x"$mode" == x"member" ]; then
			read -p "Enter the backup of account: " identity_backup
		else
			read -p "Enter the backup of controller account: " identity_backup
		fi

		identity_backup=`echo "$identity_backup"`
		if [ x"$identity_backup" != x"" ]; then
			break
		else
			log_err "Input error, backup can't be empty"
		fi
	done
	sed -i "15c \\  backup: '$identity_backup'" $configfile &>/dev/null
	log_success "Set backup successfully"

	local identity_password=""
	while true
	do
		if [ x"$mode" == x"member" ]; then
			read -p "Enter the password of account: " identity_password
		else
			read -p "Enter the password of controller account: " identity_password
		fi

		identity_password=`echo "$identity_password"`
		if [ x"$identity_password" != x"" ]; then
			break
		else
			log_err "Input error, password can't be empty"
		fi
	done
	sed -i '17c \\  password: "'$identity_password'"' $configfile &>/dev/null

	log_success "Set password successfully"
	log_success "Set configurations successfully"
	
	# Generate configurations
	config_generate
}

config_generate()
{
	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		log_err "Generate configuration files failed"
		exit 1
	fi
	log_success "Generate configurations successfully"
}

config()
{
	case "$1" in
		show)
			config_show
			;;
		set)
			config_set_all
			;;
		generate)
			config_generate
			;;
		*)
			config_help
	esac
}