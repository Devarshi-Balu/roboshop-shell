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

dnf module disable nginx -y
validate "disabling nginx module"

dnf module enable nginx:1.24 -y
validate "enabling nginx 1.24 version"

dnf install nginx -y 
validate "installing nginx package"

systemctl enable nginx 
systemctl start nginx 
validate "enabling and starting nginx"

rm -rf /usr/share/nginx/html/*
validate "removing existing html file in /usr/share/nginx/html/*.html"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip
validate "downloading the frontend code files zip folder"

(
    set -e 
    cd /usr/share/nginx/html 
    unzip -o /tmp/frontend.zip
)
validate "unzipping the code files"

cp -f "${script_path_dir}/nginx.conf" "etc/nginx/nginx.conf"
validate "copying the nginx config file"

systemctl restart nginx 
validate "restarting nginx module"