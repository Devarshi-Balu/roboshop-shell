#log_files variables
script_name="$(basename "$0" .sh)"
script_dir_path="$(realpath "$(dirname "$0")")"
logs_dir="${script_dir_path}/logs"
timestamp=$(date +"%Y%m%d_%H%M%S")
log_file="${logs_dir}/${script_name}_${timestamp}.log"

mkdir -p $logs_dir
exec > >(tee -a $log_file) 2>&1

#color varibles
R="\e[31m"
G="\e[32m"
Y="\e[33m"
B="\e[34m"
N="\e[0m"

user_id=$(id -u)

if [[ $user_id -ne 0 ]]; then 
    echo "Please run the script as root user"; 
    exit 1; 
fi

#function for validating the commands executions with exit status  
function validate(){
    if [[ "$?" -ne 0 ]]; then 
        echo -e "$1 ... $R Failure $N";
        exit 1;
    else 
        echo -e "$1 ... $G Success $N";
    fi
}

dnf install maven -y
validate "installing maven package"

useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
validate "adding roboshop system user"

mkdir -p /app 

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip 
validate "downloading the shipping code files"

(
    set -e 

    cd /app 
    unzip /tmp/cart.zip

    mvn clean package 
    mv target/shipping-1.0.jar shipping.jar 

    chown -R "roboshop:roboshop" /app
)
validate "unzip, installing packages and changing the ownership of /app"

cp "${script_dir_path}/shipping.service" "/etc/systemd/system/shipping.service" 
validate "copying the shipping service file" 

systemctl daemon-reload
validate "loading the service"

systemctl enable shipping 
systemctl start shipping
validate "enabling and starting the service"

#installing the mysql client packages
dnf install mysql -y 
validate "installing mysql package"

mysql -h <MYSQL-SERVER-IPADDRESS> -uroot -pRoboShop@1 < /app/db/schema.sql
validate "adding schema to the db" 

mysql -h <MYSQL-SERVER-IPADDRESS> -uroot -pRoboShop@1 < /app/db/app-user.sql 
validate "adding app user data to the db" 

mysql -h <MYSQL-SERVER-IPADDRESS> -uroot -pRoboShop@1 < /app/db/master-data.sql
validate "adding master data to the db"

systemctl restart shipping
validate "restarting the shipping service"
