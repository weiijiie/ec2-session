#! /usr/bin/bash

usage()
{
    echo "Usage: ./ec2-session.sh"
    echo "Description: Starts the specified AWS EC2 instance and uses ssh to connect to it. Stops the instance after exiting. Will attempt to use the profile passed in followed by the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY to authenticate. Otherwise, will default to using the default AWS profile found in ~/.aws/credentials "
    echo -e "\nFlags:"
    echo "  -i | --instance-id,         Instance ID of EC2 instance to be started."
    echo "  -k | --key,                 Path to private key used to SSH into your EC2 instance."
    echo "  -u | --user,                User on EC2 instance to SSH into."
    echo "  -p | --profile,             AWS CLI profile to use. Optional"
    echo "  --NoStrictHostKeyChecking,  Disables strict host key checking for SSH."
}

spin()
{
    sp='/-\|'
    printf ' '
    sleep 0.5
    while true; do
        printf "\r%.1s $1" "$sp"
        sp=${sp#?}${sp%???}
        sleep 1
    done
}

start_instance()
{
    aws ec2 start-instances --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2") > /dev/null
    if [ $? != 0 ]; then
        exit $?
    fi
}

wait_instance_start()
{
    spin "Waiting for EC2 instance: $1 to start..." & local spinpid=$!
    aws ec2 wait instance-running --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2")
    if [ $? != 0 ]; then
        kill "$spinpid"
        exit $?
    fi
    kill "$spinpid"
    echo -e "\r$1 started!                                                             \n"
}

get_started_instance_ip()
{
    local ip=$(aws ec2 describe-instances --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2") \
        --query 'Reservations[0].Instances[0].PublicIpAddress' | tr -d '"')
    if [ $? != 0 ]; then
        exit $?
    fi
    echo $ip
}

stop_instance()
{
    echo "Stopping EC2 instance: $1..."
    sleep 0.5
    aws ec2 stop-instances --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2") > /dev/null
    if [ $? != 0 ]; then
        exit $?
    fi
}

instance_id=
profile=
user=
key=
no_strict_host_key_checking=

while [ "$1" != "" ]; do
    case $1 in
        -i | --instance-id )
            shift
            instance_id=$1
            ;;
        -p | --profile )
            shift
            profile=$1
            ;;
        -u | --user )
            shift
            user=$1
            ;;
        -k | --key )
            shift
            key=$1
            ;;
        --NoStrictHostKeyChecking )
            no_strict_host_key_checking=true
            ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$instance_id" || -z "$key" || -z "$user" ]]; then
    usage
    exit 1
fi

start_instance $instance_id $profile
wait_instance_start $instance_id $profile
sleep 2
ip=$(get_started_instance_ip $instance_id $profile)
echo -e "Please wait for instance to be ready to accept SSH connections...\n"
ssh $([[ ! -z $no_strict_host_key_checking ]] && echo "-o StrictHostKeyChecking=no") -i $key $user@$ip
stop_instance $instance_id $profile
