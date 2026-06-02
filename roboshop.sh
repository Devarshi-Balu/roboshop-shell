# script_name=$(awk -F "[/.]" '{ print (NF-1) }' <<< "$0" )
set -Eeuo pipefail

script_name="$(basename "${0}" .sh)"
script_dir_path="$(realpath $(dirname "$0"))"
logs_dir="${script_dir_path}/logs/"
time_stamp="$(date +%Y%m%d_%H%M%S)"


mkdir -p "${logs_dir}"
log_file="${logs_dir}/${script_name}_${time_stamp}.log"

exec > >(tee -a "${log_file}") 2>&1

echo "script run start @ $(date)"
export AWS_PROFILE="deva"

trap '
    echo Error! something is up!!
    echo command: $BASH_COMMAND
    echo LINENO: $LINENO
    echo script: $0
' ERR

#aws variables 
readonly IMAGE_ID="ami-0220d79f3f480ecf5"
readonly SECURITY_GROUPS="sg1" 
readonly DOMAIN_NAME="rb.devarshi.live"
readonly ZONE_ID="Z06569691EDOCEFWDOVQV"

for instance in "$@"; do 
    read -r INSTANCE_ID PRIVATE_IP < <(
        aws ec2 run-instances \
            --image-id "$IMAGE_ID" \
            --instance-type t3.micro \
            --security-groups "$SECURITY_GROUPS" \
            --count 1 \
            --tag-specifications \
            "ResourceType=instance,Tags=[{Key=Name,Value=${instance}}]" \
            --query 'Instances[0].[InstanceId,PrivateIpAddress]' \
            --output text
        )

    echo "successfully created the instance for the ${instance}"
    echo "Instance ID : ${INSTANCE_ID}"
    echo "Private IP  : ${PRIVATE_IP}"

    IpAddress="${PRIVATE_IP}"

    if [[ "$instance" == "frontend" ]]; then 
        aws ec2 wait instance-running \
        --instance-ids "$INSTANCE_ID"
        
        PUBLIC_IP=$(
            aws ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --query "Reservations[0].Instances[0].PublicIpAddress" \
                --output text 
        )

        echo "updating IP address of the frontend to the public IpAddress"
        IpAddress="${PUBLIC_IP}"
    fi

    RECORD_NAME="$instance.$DOMAIN_NAME"

    echo "updating the DNS record for the $instance"

    # declare -p PRIVATE_IP IpAddress # for debugging

    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch "$(
                      jq -n \
                        --arg record "$RECORD_NAME" \
                        --arg ip "$IpAddress" \
                        '
                          {
                            Comment: "Updating record",
                            Changes: [
                              {
                                Action: "UPSERT",
                                ResourceRecordSet: {
                                  Name: $record,
                                  Type: "A",
                                  TTL: 1,
                                  ResourceRecords: [
                                    {
                                      Value: $ip
                                    }
                                  ]
                                }
                              }
                            ]
                          }
                        '
                      )"

    echo -e "record updated for $instance, IpAddress:${IpAddress}, domain: $RECORD_NAME"
    echo "======================================="
done