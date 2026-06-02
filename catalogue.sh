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

dnf module disable nodejs -y
validate "disbaling the nodejs module"

dnf module enable nodejs:20 -y 
validate "enabling nodejs:20 version"

dnf install nodejs -y 
validate "installing nodejs"

useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
validate "adding roboshop system user"

#setting up the app directory
mkdir /app 
curl -o "/tmp/catalogue.zip" "https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip" 
validate "downloading the "

(
    set -e

    cd /app 
    unzip /tmp/catalogue.zip
    npm install 
    
    chown -R "roboshop:roboshop" /app
)
validate "unzip, installing packages and changing the ownership of /app"

cp "${script_dir_path}/catalogue.service" "/etc/systemd/system/catalogue.service"
validate "copying the service file for catalogue"

systemctl daemon-reload
validate "loading the service"

systemctl enable catalogue 
systemctl start catalogue
validate "enabling and starting the catalogue service"

cp "${script_dir_path}/mongo.repo" "/etc/yum.repos.d/mongo.repo"
validate "copying the repo file for mongodb"

dnf install mongodb-mongosh -y
validate "install mongsh client"

mongosh --host mongodb.rb.devarshi.live </app/db/master-data.js
validate "inserting the master data into the monogdb server"