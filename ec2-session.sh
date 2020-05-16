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
    echo "  --wait-stop,                Program will wait for EC2 to stop before exiting if enabled."
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
    echo "Starting EC2 instance: $1..."
    aws ec2 start-instances --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2") > /dev/null
    if [ $? != 0 ]; then
        exit $?
    fi
    next_status="starting"
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
    next_status="stopping"
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

ssh_into_instance()
{
    ssh $([[ ! -z $no_strict_host_key_checking ]] && echo "-o StrictHostKeyChecking=no") -i $1 $2@$3
    if [ $? -eq 255 ]; then
        echo -ne "\nRetry once? (y): "
        read retry
        if [ $retry == "y" ]; then
            ssh $([[ ! -z $no_strict_host_key_checking ]] && echo "-o StrictHostKeyChecking=no") -i $1 $2@$3
        fi
    fi
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

wait_instance_stop()
{
    spin "Waiting for EC2 instance: $1 to stop..." & local spinpid=$!
    aws ec2 wait instance-stopped --instance-ids $1 $([[ ! -z $2 ]] && echo "--profile $2")
    if [ $? != 0 ]; then
        kill "$spinpid"
        exit $?
    fi
    kill "$spinpid"
    echo -e "\r$1 stopped!                                                             \n"
}

unexpected_exit()
{
    echo -e "\nProgram exited before $next_status. Ensure your EC2 instance is in your desired state."
    exit 1
}

instance_id=
profile=
user=
key=
no_strict_host_key_checking=
wait_stop=
next_status="starting"

trap unexpected_exit INT TERM

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
        --wait-stop )
            wait_stop=true
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
ip=$(get_started_instance_ip $instance_id $profile)

echo -e "Please wait for instance to be ready to accept SSH connections...\n"
sleep 5
ssh_into_instance $key $user $ip


stop_instance $instance_id $profile
if [[ ! -z $wait_stop ]]; then
    wait_instance_stop $instance_id $profile
fi

sleep 1
exit
