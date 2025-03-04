#!/usr/bin/bash

display_usage() {
    echo "사용법: $0 [-a 또는 -m] [0 또는 1]"
    echo "옵션:"
    echo "  -a    모든 점검 사항을 출력합니다."
    echo "  -m    취약 사항만 출력합니다."
    echo "인자:"
    echo "  0     로그를 저장하지 않습니다."
    echo "  1     로그를 저장합니다."
}

# 선의 길이 설정
line_length=58

# 선 생성 함수
generate_line() {
    local char=$1
    local length=$2
    printf '%*s' "$length" '' | tr ' ' "$char"
}

# 선 변수 생성
border_line=$(generate_line '=' "$line_length")
plus_line=$(generate_line '+' "$line_length")

result_print() {
    # 입력된 인자를 배열로 저장
    local input=("$@")

    # 코드, 점검 내용, 전체 결과 추출
    local code="${input[0]}"
    local check_content="${input[1]}"
    local overall_result="${input[2]}"

    # 출력 색상 정의
    local red
    local green
    local yellow
    local reset

    # 출력 대상에 따른 색상 코드 설정
    if [[ -t 1 ]]; then
        red="\e[31m"
        green="\e[32m"
        yellow="\e[33m"
        reset="\e[0m"  # 색상 초기화
    else
        red=""
        green=""
        yellow=""
        reset=""
    fi

    # 코드와 점검 내용 출력
    echo -e "[${yellow}${code}${reset}] ${check_content}"
    echo "----------------------------------------------------------"

    # 전체 결과 출력 (색상 적용)
    local result_color="$green"
    if [[ "$overall_result" == "취약" ]]; then
        result_color="$red"
    fi
    echo -e ": ${result_color}${overall_result}${reset}"

    # 세부 항목 출력
    local total_args=${#input[@]}
    for ((i=3; i<total_args; i+=3)); do
        local detail="${input[$i]}"
        local result="${input[$((i+1))]}"
        local requirement="${input[$((i+2))]}"

        # 결과에 따라 색상 적용
        local item_color="$green"
        if [[ "$result" == "취약" ]]; then
            item_color="$red"
        fi
        echo -e "\t${detail}: ${item_color}${result}${reset} (${requirement})"
    done

    echo "=========================================================="
}

display_server_info() {
    # 지역 변수 선언
    local os_ver
    local cur_time
    local order
    local hostname
    local ip_addresses
    local kernel_version
    local uptime_info
    local logged_in_users

    # OS 버전 가져오기
    if [ -f /etc/rocky-release ]; then
        os_ver=$(cat /etc/rocky-release)
    elif [ -f /etc/os-release ]; then
        os_ver=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        os_ver="Unknown OS"
    fi

    # 현재 시간 가져오기
    cur_time=$(date '+%Y-%m-%d %H:%M:%S')

    # 현재 사용자 가져오기
    order=$(logname 2>/dev/null || echo "$USER")

    # 호스트명 가져오기
    hostname=$(hostname)

    # IP 주소 가져오기
    ip_addresses=$(hostname -I 2>/dev/null)
    if [ -z "$ip_addresses" ]; then
        ip_addresses=$(ip addr show | grep 'inet ' | awk '{print $2}')
    fi

    # 커널 버전 가져오기
    kernel_version=$(uname -r)

    # 업타임 정보 가져오기
    uptime_info=$(uptime -p)

    # 현재 로그인된 사용자 목록 가져오기
    logged_in_users=$(who | awk '{print $1}' | sort | uniq | paste -sd ', ')

    # 출력 대상 확인 (exec 이전에 수행)
    if [[ -t 1 ]]; then
        is_tty=1
    else
        is_tty=0
    fi

    # 출력 색상 설정 (exec 이후에도 적용)
    if [ "$is_tty" -eq 1 ]; then
        red="\e[31m"
        green="\e[1m"
        yellow="\e[34m"
        reset="\e[0m"  # 색상 초기화
    else
        red=""
        green=""
        yellow=""
        reset=""
    fi

    # 서버 정보 출력
    echo -e "\n${yellow}$border_line${reset}"
    echo -e "${green} 방화벽 팀 리눅스 시스템 점검 스크립트 ${reset}"
    echo -e "${yellow}$border_line${reset}"

    printf "%-20s %s\n" "OS:" "$os_ver"
    printf "%-20s %s\n" "Hostname:" "$hostname"
    printf "%-20s %s\n" "Kernel Version:" "$kernel_version"
    printf "%-20s %s\n" "IP Addresses:" "$ip_addresses"
    printf "%-20s %s\n" "Uptime:" "$uptime_info"
    printf "%-20s %s\n" "Current Time:" "$cur_time"
    printf "%-20s %s\n" "Logged-in Users:" "$logged_in_users"
    printf "%-20s %s\n" "Order:" "$order"
    printf "%-20s %s\n" "Inspector:" "t.Firewall"
}

# Root 권한 확인 함수
check_root_user() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${red}[오류]${reset} 이 스크립트는 root 권한으로 실행해야 합니다."
        exit 1
    fi
}

# 배열을 순차적으로 출력하는 함수
print_array_elements()
{
    local array=("$@")  # 모든 인자를 배열로 받음
    local length=${#array[@]}  # 배열의 길이

    # 배열의 각 요소를 0부터 마지막까지 출력
    for ((i = 0; i < length; i++)); do
        echo "Element $i: ${array[$i]}"
    done
}

# 중복 검사 함수
is_in_array()
{
    local element="$1"
    shift
    local array=("$@")
    
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0  # 배열에 값이 있으면 true (0) 반환
        fi
    done
    return 1  # 값이 없으면 false (1) 반환
}

get_permission()
{
    index=${1}
    search_as=${2}
    string=${3}

    permission=0
    for (( i=${index}; i<=${search_as}; i++ )); do
        char="${string:$i:1}"
        if [[ "$char" == "r" ]]; then
            permission=$((permission + 4))
        elif [[ "$char" == "w" ]]; then
            permission=$((permission + 2))
        elif [[ "$char" == "x" ]]; then
            permission=$((permission + 1))
        else
            permission=$((permission + 0))
        fi
    done

    echo ${permission}
}

get_permission_result()
{
    permission=${1}
    # echo "${permission}"
    result=0

    result=$((result + $(get_permission 1 3 "${permission}") * 100))
    result=$((result + $(get_permission 4 6 "${permission}") * 10))
    result=$((result + $(get_permission 7 9 "${permission}")))

    echo ${result}
}

is_on_service() {
    service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        echo "active"
    else
        echo "inactive"
    fi
}

# 서비스의 부팅 시 시작 설정 확인 함수
is_service_enabled() {
    service_name=$1
    if systemctl is-enabled --quiet "$service_name"; then
        echo "enabled"
    else
        echo "disabled"
    fi
}


#############################################################################################
U_09()
{
    local output_mode=$1
    # 점검 코드 실행
    permission=`ls -l /etc/hosts | awk '{print $1}'`
    owner=`ls -l /etc/hosts | awk '{print $3}'`

    if [[ "$owner" == "root"  ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order1="소유자 root로 변경 필요"
    fi

    if [[ "$permission" == "-rw-------." ]]; then
        result2="양호"
        order2="rw-------"
    else
        result2="취약"
        order2="권한 설정 필요"
    fi

    if [[ "$result1" == "양호" && "$result2" == "양호" ]]; then
        result="양호"
    else
        result="취약"
    fi

    code="U_09"

    # 결과값 변수에 저장 ()
    desc="/etc/hosts 파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="Permission"
    detail_2_result=$result2
    detail_2_order=$order2

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_10()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -l /etc/xinetd.conf 2>/dev/null | awk '{print $1}'`
    owner=`ls -l /etc/xinetd.conf 2>/dev/null | awk '{print $3}'`

    if [[ "$check" ==  "" ]]; then
        result1="파일 없음"
        result2="파일 없음"
        order1="-"
        order2="-"
    else
        if [[ "$owner" == "root" ]]; then
            result1="양호"
            order1="-"
        else
            result1="취약"
            order1="소유자 root로 변경 필요"
        fi

        if [[ "$check" == "-rw-------." ]]; then
            result2="양호"
            order2="-"
        else
            result2="취약"
            order2="파일의 권한 설정 필요"
        fi
    fi

    if [[ "$result1" == "파일 없음" || "$result2" == "파일 없음" ]]; then
        result="파일 없음"
    elif [[ "$result1" == "취약" || "$result2" == "취약" ]]; then
        result="취약"
    else
        result="양호"
    fi

    code="U_10"

    # 결과값 변수에 저장 ()
    desc="/etc/(x)inetd.conf 파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="Permission"
    detail_2_result=$result2
    detail_2_order=$order2

    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
    
}

U_11()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -l /etc/rsyslog.conf | awk '{print $1}'`
    owner=`ls -l /etc/rsyslog.conf | awk '{print $3}'`

    if [[ "$owner" == "root" ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order="소유자 root로 변경 필요"
    fi

    if [[ "$check" == "-rw-r-----." ]]; then
        result2="양호"
        order2="-"
    else
        result2="취약"
        order2="권한 설정 필요"
    fi

    if [[ "$result1" == "양호" && "$result2" == "양호" ]]; then
        result="양호"
    else
        result="취약"
    fi

    code="U_11"

    # 결과값 변수에 저장 ()
    desc="/etc/syslog.conf 파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="Permission"
    detail_2_result=$result2
    detail_2_order=$order2

    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_12()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -l /etc/services | awk '{print $1}'`
    owner=`ls -l /etc/services | awk '{print $3}'`

    if [[ "$owner" == "root" || "$owner" == "bin" || "$owner" == "sys" ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order1="소유자 변경 필요"
    fi

    if [[ "$check" == "-rw-r--r--." ]]; then
        result2="양호"
        order2="-"
    else
        result2="취약"
        order2="권한 설정 필요"
    fi

    if [[ "$result1" == "양호" && "$result2" == "양호" ]]; then
        result="양호"
    else
        result="취약"
    fi

    code="U_12"

    # 결과값 변수에 저장 ()
    desc="/etc/services 파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="Permission"
    detail_2_result=$result2
    detail_2_order=$order2

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_13() # ls: cannot access '/bin/policytool': 그런 파일이나 디렉터리가 없습니다
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -alL /* | awk '{ print $1 }' | grep '^-rws'`

    if [[ "$check" == "" ]]; then
        result="양호"
    else
        result="취약"
    fi

    code="U_13"

    if [[ "$result" == "양호" ]]; then
        order="-"
    else
        order="설정 파일 점검 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="SUID, SGID 설정 파일점검"
    total_result=$result
    detail_1="SUID, SGID"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_14()
{
    local output_mode=$1
    # 점검 코드 실행
    owners=`ls -al /root/ | awk '{ print $3 }' | uniq`
    check=`ls -al /root/ | awk '{ if (substr($1, 9, 1) == "w") print $1 }' | uniq`

    for owner in $owners; do
        if [[ "$owner" == "root" ]]; then
            result1="양호"
            order1="-"
        else
            result1="취약"
            order1="소유자 root로 변경 필요"
        fi
    done

    if [[ "$check" == "" ]]; then
        result2="양호"
        order2="-"
    else
        result2="취약"
        order2="root와 소유자 외에 쓰기 권한 삭제 필요"
    fi

    code="U_14"

    if [[ "$result1" == "양호" && "$result2" == "양호" ]]; then
        result="양호"
    else
        result="취약"
    fi

    # 결과값 변수에 저장 ()
    desc="사용자, 시스템 시작파일 및 환경파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="Permission"
    detail_2_result=$result2
    detail_2_order=$order2

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        rresult_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_15()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`find / -type f -perm -2 -exec ls -l {} \; 2>/dev/null`

    if [[ "$check" == "" ]]; then
        result="양호"
        order="-"
    else
        result="취약"
        order="수정 및 삭제 필요"
    fi

    code="U_15"

    # 결과값 변수에 저장 ()
    desc="world writable 파일 점검"
    total_result=$result
    detail_1="world writable 파일"
    detail_1_result=$result
    detail_1_order=$order

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" $total_result "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_17()
{
    local output_mode=$1
    # 점검 코드 실행
    check1=`ls -al $HOME/.rhosts 2>/dev/null | awk '{ print $1 }'`
    owner1=`ls -al $HOME/.rhosts 2>/dev/null | awk '{ print $3 }'`
    check2=`ls -al /etc/hosts.equiv 2>/dev/null | awk '{print $1}'`
    owner2=`ls -al /etc/hosts.equiv 2>/dev/null | awk '{print $3}'`

    code="U_17"

    if [[ "$check1" == "-rw-------." ]]; then
        result1="양호"
        order1="-"
    elif [[ "$check1" == "" ]]; then
        result1="파일 없음"
        order1="-"
    else
        result1="취약"
        order1="파일 소유자 및 권한 설정 필요
    fi

    if [[ "$check2" == "-rw-------." ]]; then
        result2="양호"
        order2="-"
    elif [[ "$check2" == "" ]]; then
        result2="파일 없음"
        order2="-"
    else
        result2="취약"
        order2="파일 소유자 및 권한 설정 필요
    fi

    if [[ "$result1" == "파일 없음" && "$result2" == "파일 없음" ]]; then
        result="파일 없음"
    elif [[ "$result1" == "취약" || "$result2" == "취약" ]]; then
        result="취약"
    else
        result="양호"
    fi

    # 결과값 변수에 저장 ()
    desc="$HOME/.rhosts, hosts.equiv 사용 금지"
    total_result=$result
    detail_1="$HOME/.rhosts"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="/etc/hosts.equiv"
    detail_2_result=$result2
    detail_2_order=$order2


    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order2"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print $code "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order2"
    fi
}

U_19()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -al /etc/inetd.conf 2>/dev/null`

    code="U_19"

    if [[ "$check" == "" ]]; then
        result="파일 없음"
    else
        result="취약"
    fi

    if [[ "$result" == "파일 없음" ]]; then
        order="-"
    else
        order="fingerd 라인 주석처리 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="Finger 서비스 비활성화"
    total_result=$result
    detail_1="/etc/inetd.conf"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_20()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`cat /etc/passwd | grep ftp`

    code="U_20"

    if [[ "$check" == "" ]]; then
        result="양호"
    else
        result="취약"
    fi

    if [[ "$result" == "양호" ]]; then
        order="-"
    else
        order="접속 제한 설정 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="Anonymous FTP 비활성화"
    total_result=$result
    detail_1="Anonymous FTP"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_21()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -alL /etc/xinetd.d/* 2>/dev/null | egrep "rsh|rlogin|rexec" | egrep -v "grep|klogin|kshell|kexec" 2>/dev/null`

    code="U_21"

    if [[ "$check" == "" ]]; then
        result="양호"
    else
        result="취약"
    fi

    if [[ "$result" == "양호" ]]; then
        order="-"
    else
        order="불필요한 r 계열 서비스 비활성화 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="r 계열 서비스 비활성화"
    total_result=$result
    detail_1="r 계열 서비스"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_22()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -al /usr/bin/crontab | awk '{print $1}'`
    owner=`ls -al /usr/bin/crontab | awk '{print $3}'`

    code="U_22"

    if [[ "$check" == "rw-r-----." ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order1="권한 설정 필요"
    fi

    if [[ "$owner" == "root" ]]; then
        result2="양호"
        order2="-"
    else
        reulst2="취약"
        order2="소유자 root로 변경 필요"
    fi

    if [[ "$result1" == "취약" || "$result2" == "취약" ]]; then
        result="취약"
    else
        result="양호"
    fi

    # 결과값 변수에 저장 ()
    desc="crond 파일 소유자 및 권한 설정"
    total_result=$result
    detail_1="Owner"
    detail_1_result=$result2
    detail_1_order=$order2
    detail_2="Permission"
    detail_2_result=$result1
    detail_2_order=$order1

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_23()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`cat /etc/xinetd.d 2>/dev/null`

    code="U_23"

    if [[ "$check" == "" ]]; then
        result="파일 없음"
    else
        result="취약"
    fi

    if [[ "$result" == "파일 없음" ]]; then
        order="-"
    else
        order="파일 설정 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="DoS 공격에 취약한 서비스 비활성화"
    total_result=$result
    detail_1="DoS 공격 취약 서비스 여부"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_24()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -al /etc/rc.d/rc*.d/* 2>/dev/null | grep nfs`

    code="U_24"

    if [[ "$check" == "" ]]; then
        result="양호"
    else
        result="취약"
    fi

    if [[ "$result" == "양호" ]]; then
        order="-"
    else
        order="사용하지않는 NFS 서비스 중지 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="NFS 서비스 비활성화"
    total_result=$result
    detail_1="NFS 서비스"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_25()
{
    local output_mode=$1
    # 점검 코드 실행
    check=`ls -al /etc/rc.d/rc*.d/* 2>/dev/null | grep nfs`

    code="U_25"

    if [[ "$check" == "" ]]; then
        result="양호"
    else
        result="취약"
    fi

    if [[ "$result" == "양호" ]]; then
        order="-"
    else
        order="사용하지않는 NFS 서비스 중지 또는 everyone 공유 제한 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="NFS 접근 통제"
    total_result=$result
    detail_1="NFS 서비스"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}
#############################################################################################
U_50()
{
    local output_mode=$1
    desc="관리자 그룹에 최소한의 계정 포함"
    detail=()
    total_result="양호"

    
    group_value=$(cat /etc/group | grep root | sed 's/root:x:0://')

    detail+=("Root Privileges Users")
    if echo "$group_value" | awk -F', ' '{for(i=1;i<=NF;i++) if($i != "root") exit 1}'; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("/etc/group 의 설정 파일 점검")
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_50" "$desc" "$total_result" "${detail[@]}" #result $order
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_50" "$desc" "$total_result" "${detail[@]}" #result $order
    fi
}

U_51()
{
    local output_mode=$1
    # 계정이 존재하지 않는 GID 금지
    # 그룹 설정 파일에 불필요한 그룹
        # 1. 계정이 없고 관리에 사용되지 않는 그룹
        # 2. 계정은 있지만 관리에 사용되지 않는 그룹
    # gshadow_name=$(cat /etc/gshadow | cut -d':' -f1)
    # group_name=$(cat /etc/group | cut -d':' -f1)

    # duplication_name=$(comm -3 $(echo ${gshadow_name}) $(echo ${group_name}))
    # echo "${duplication_name}"
    desc="계정이 존재하지 않는 GID 금지"
    detail=()
    total_result="양호"

    # gshadow와 group 파일에서 그룹 이름 추출
    gshadow_name=$(cut -d':' -f1 /etc/gshadow)
    group_name=$(cut -d':' -f1 /etc/group)
    # 사용중인 GID 모두 추출
    used_GID=$(cut -d':' -f4 /etc/passwd)
    # 모든 GID 리스트
    GID_list=$(cut -d':' -f3 /etc/group)


    # gshadow와 group 이름을 배열로 변환
    gshadow_array=(${gshadow_name})
    group_array=(${group_name})

    # 중복되지 않은 그룹 이름을 찾기 위한 배열 비교
    # gshadow 배열에서 group 배열에 없는 항목 출력
    detail+=("gshadow에만 있는 그룹")
    gshadow_state="양호"
    gshadow_gname=()
    for gname in "${gshadow_array[@]}"; do
        if [[ ! " ${group_array[@]} " =~ " ${gname} " ]]; then
            gshadow_state="취약"
            gshadow_gname+=("$gname")
        fi
    done
    # gshadow_comm="$gshadow_gname 그룹들을 점검하시오."
    if [[ ${gshadow_state} == "취약" ]]; then
        gshadow_comm="${gshadow_gname} 그룹들을 점검하시오."
    else
        gshadow_comm="-"
    fi


    detail+=("${gshadow_state}")
    detail+=("${gshadow_comm}")

    # group 배열에서 gshadow 배열에 없는 항목 출력
    # echo "group에만 있는 그룹:"
    detail+=("group에만 있는 그룹")
    group_state="양호"
    group_gname=()

    for gname in "${group_array[@]}"; do
        if [[ ! " ${gshadow_array[@]} " =~ " ${gname} " ]]; then
            group_state="취약"
            group_gname+=("$gname")
        fi
    done
    # 
    if [[ ${group_state} == "취약" ]]; then
        group_comm="${group_gname} 그룹들을 점검하시오."
    else
        group_comm="-"
    fi

    detail+=("${group_state}")
    detail+=("${group_comm}")

    ###########################################################
    used_GID_array=(${used_GID})
    GID_array=(${GID_list})

    detail+=("사용중이지 않는 GID")
    GID_state="양호"
    GID_check_list=()

    for _GID_ in "${GID_array[@]}"; do
        found=0  # GID가 사용 중인 배열에 있는지 여부를 나타내는 플래그
        for used_GID in "${used_GID_array[@]}"; do
            if [[ "$used_GID" -eq "$_GID_" ]]; then
                found=1
                break
            fi
        done

        # GID가 used_GID_array에 없으면 취약으로 설정
        if [[ $found -eq 0 ]]; then
            GID_state="취약"
            # GID_check_list+=("$_GID_")  # GID_check_list에 해당 GID 추가
        fi
    done

    if [[ ${GID_state} == "취약" ]]; then
        GID_comm="/etc/group의 사용중이지 않는 GID를 점검하시오."
    else
        GID_comm="-"
    fi

    detail+=("${GID_state}")
    detail+=("${GID_comm}")

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_51" "$desc" "$total_result" "${detail[@]}" #result $order
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_51" "$desc" "$total_result" "${detail[@]}" #result $order
    fi
}

U_52()
{
    local output_mode=$1
    desc="동일한 UID 금지"
    detail=()
    total_result="양호"

    duplicate_UID=$(cut -d':' -f3 /etc/passwd | sort | uniq -d)

    detail+=("UID 중복 사용 금지")

    # 변수에 값이 있는지 확인
    if [[ -z "$duplicate_UID" ]]; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("중복 사용 된 UID: $duplicate_UID")
    fi
    
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_52" "$desc" "$total_result" "${detail[@]}" #result $order
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_52" "$desc" "$total_result" "${detail[@]}" #result $order
    fi
}

U_53()
{
    local output_mode=$1
    # 사용자 shell 점검
    desc="사용자 shell 점검"
    detail=()
    total_result="양호"

    no_use_data=$(grep -E "^(daemon|bin|sys|adm|listen|nobody|nobody4|noaccess|diag|operator|games|gopher)" /etc/passwd | grep -v "admin")

    while IFS=: read -r name _ _ _ _ _ shell; do
        
        detail+=("$name")
        
        # 쉘이 /bin/false 또는 /sbin/nologin인지 검사
        if [[ "$shell" == "/bin/false" || "$shell" == "/sbin/nologin" ]]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            detail+=("계정에 /bin/false(/sbin/nologin) 쉘이 부여되지 않았습니다.")
        fi
    done <<< "$no_use_data"

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_53" "$desc" "$total_result" "${detail[@]}" #result $order
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_53" "$desc" "$total_result" "${detail[@]}" #result $order
    fi
}

U_54()
{
    local output_mode=$1
    # Session Timeout 설정
    desc="사용자 shell 점검"
    detail=()
    total_result="양호"

    # TMOUT 설정이 작성되어 있는지
    TMOUT_set=$(cat /etc/profile | grep TMOUT)

    detail+=("session timeout 설정 여부")
    if [[ "$TMOUT_set" == "" ]]; then
        detail+=("취약")
        detail+=("Session Timeout 설정을 추가하십시오.")
    else
        detail+=("양호")
        detail+=("-")

    # TMOUT 설정값이 600인지
        detail+=("session timeout 설정 값")
        TMOUT_value=$(echo "$TMOUT_set" | grep -Eo 'TMOUT=[0-9]+' | cut -d'=' -f2)

        # TMOUT_value가 숫자인지 확인
        if [[ "$TMOUT_value" =~ ^[0-9]+$ ]]; then
            if [[ "$TMOUT_value" -gt 600 ]]; then
                detail+=("취약")
                detail+=("Session Timeout 값을 600 이하로 설정하십시오.")
            else
                detail+=("양호")
                detail+=("-")
            fi
        else
            detail+=("취약")
            detail+=("Session Timeout 값이 잘못 설정되었습니다.")
        fi

        # if [[ "$TMOUT_value" -gt 600 ]]; then
        #     detail+=("취약")
        #     detail+=("Session Timeout 값을 600이하로 설정하십시오.")
        # else
        #     detail+=("양호")
        #     detail+=("-")
        # fi

    # export TMOUT 가 작성되어 있는지
        detail+=("session timeout 적용 여부")
        TMOUT_export=$(cat /etc/profile | grep 'export TMOUT')
        if [[ "$TMOUT_export" == "" ]]; then
            detail+=("취약")
            detail+=("export TMOUT 명령어로 session timeout을 적용하세요.")
        else
            detail+=("양호")
            detail+=("-")
        fi
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_54" "$desc" "$total_result" "${detail[@]}" #result $order
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_54" "$desc" "$total_result" "${detail[@]}" #result $order
    fi
}

U_05()
{
    local output_mode=$1
    #변수 선언
    desc="root 홈, 패스 디렉터리 권한 및 패스 설정"
    detail=()
    total_result="양호"

    # root 검사
    detail+=("root")
    root_path=$PATH

    if [[ "$root_path" == *:*::* || "$root_path" == *:*.:* || "$root_path" == .* || "$root_path" == *:: ]]; then
        detail+=("취약")
        detail+=("환경변수 값에 . 또는 :: 포함 여부 확인")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 일반 사용자 검사
    for user_home in /home/*; do # 홈 디렉토리 기준으로 사용자를 검사하면 안되겠다. 삭제된 user 디렉토리가 남아 에러를 남긴다.
        if [[ -d "$user_home" ]]; then
            user=$(basename "$user_home")
            # 사용자의 PATH 변수 가져오기
            user_shell=$(grep "^${user}:" /etc/passwd | cut -d: -f7)

            # 만약 해당 사용자가 존재하지 않는다면 배열에 값 추가 하지 않는다.
            if [[ "$user_shell" != "" ]]; then
                detail+=("$user")
                if [[ -n "$user_shell" ]]; then
                    user_path=$(sudo -u "$user" "$user_shell" -c 'echo $PATH')

                    # PATH 변수에 . 또는 :: 가 포함되어 있는지 확인
                    if [[ "$user_path" == *:*::* || "$user_path" == *:*.:* || "$user_path" == .* || "$user_path" == *:: ]]; then
                        # 포함된 것을 인지
                        detail+=("취약")
                        detail+=("환경변수 값에 . 또는 :: 포함 여부 확인")
                    else
                        # 포함되지 않았다. 
                        detail+=("양호")
                        detail+=("-")
                    fi
                fi
            fi
        fi
    done

    # 최종 취약 여부 확인
    # local i=2
    # while [ $i -lt ${#detail[@]} ]; do
    #     if [[ $detail[$i] == "취약" ]]; then
    #         total_result="취약"
    #     fi
    #     # 인덱스를 세 개씩 증가시켜 다음 항목으로 이동
    #     i=$((i+3))
    # done
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
     #result $order
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_05" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_05" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_06() 
{
    local output_mode=$1
    # 파일 및 디렉터리 소유자 설정
    # 소유자가 존재하지 않는 파일과 동일한 UID로 설정을 바꾸게 되면 해당 파일의 소유권한을 갖게된다.
    desc="파일 및 디렉터리 소유자 설정"
    detail=()
    total_result="양호"

    find_nouser=$(find / -nouser 2>/dev/null) # 소유자가 없는 파일 조사
    find_nogroup=$(find / -nogroup 2>/dev/null) # 소유 그룹이 없는 파일 조사

    check_result() {
        local type=$1
        local items=$2
        local index_field=$3
        local result_title=$4

        detail+=("$type")
        
        if [ -z "$items" ]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            _ids=()

            # 소유자나 그룹 ID를 추출하여 중복 없이 저장
            while read -r item; do
                _id=$(ls -l "$item" | awk "{print \$$index_field}")
                if [[ ! " ${_ids[@]} " =~ " $_id " ]]; then
                    _ids+=("$_id")
                fi
            done <<< "$items"

            # 결과 저장
            detail+=("$(IFS=/; echo "${_ids[*]}"), $result_title")
        fi
    }

    # UID 검사 (3번째 필드가 소유자)
    check_result "UID" "$find_nouser" 3 "사용자 점검"
    
    # GID 검사 (4번째 필드가 그룹)
    check_result "GID" "$find_nogroup" 4 "그룹 번호 점검"

    # 총 결과 확인
    if [[ " ${detail[@]} " =~ " 취약 " ]]; then
        total_result="취약"
    fi

    # 결과 출력
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_06" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_06" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_07()
{
    local output_mode=$1
    desc="/etc/passwd 파일 소유자 및 권한 설정"
    detail=()
    total_result="양호"
    permission=($(ls -l /etc/passwd | awk '{print $1}'))
    owner=($(ls -l /etc/passwd | awk '{print $3}'))

    # echo "$permission" "$owner"
    # permission 값
    permission_value=($(get_permission_result "${permission}"))

    # echo "${permission_valu}"
    detail+=("Permission")
    # permission_value 값이 644 보다 크면?
    if ! [[ ${permission_value} -le 644 ]]; then
        detail+=("취약")
        detail+=("/etc/passwd 퍼미션 점검")
    else
        detail+=("양호")
        detail+=("-")
    fi

    detail+=("Owner")
    # owner 가 root가 아니면
    if [ ${owner} != "root" ]; then
        detail+=("취약")
        detail+=("/etc/passwd 소유자 점검")
    else
        detail+=("양호")
        detail+=("-")
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_07" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_07" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_08()
{
    local output_mode=$1
    desc="/etc/shadow 파일 소유자 및 권한 설정"
    detail=()
    total_result="양호"
    permission=($(ls -l /etc/shadow | awk '{print $1}'))
    owner=($(ls -l /etc/shadow | awk '{print $3}'))

    # echo "$permission" "$owner"
    # permission 값
    permission_value=($(get_permission_result "${permission}"))

    # echo "${permission_valu}"
    detail+=("Permission")
    # permission_value 값이 400 보다 크면?
    if ! [[ ${permission_value} -le 400 ]]; then
        detail+=("취약")
        detail+=("/etc/shadow 퍼미션 점검")
    else
        detail+=("양호")
        detail+=("-")
    fi

    detail+=("Owner")
    # owner 가 root가 아니면
    if [ ${owner} != "root" ]; then
        detail+=("취약")
        detail+=("/etc/shadow 소유자 점검")
    else
        detail+=("양호")
        detail+=("-")
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_08" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_08" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_16()
{
    local output_mode=$1
    desc="/dev에 존재하지 않는 device 파일 점검"
    detail=()
    total_result="양호"

    result=$(find /dev -type f -exec ls -l {} \;)

    detail+=("/device 점검 결과")
    if [ -s $result ]; then
        detail+=("취약")
        detail+=("${result}를 점검하세요.")
    else
        detail+=("양호")
        detail+=("-")
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_16" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_16" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_26()
{
    local output_mode=$1
    desc="automountd 서비스 데몬의 실행 여부 점검"
    detail=()
    total_result="양호"

    automount=$(is_on_service automount)
    autofs=$(is_on_service autofs)

    if [[ "$automount" == "inactive" && "$autofs" == "inactive" ]]; then
        
        detail+=("automount"); detail+=("양호"); detail+=("-")
        detail+=("autofs"); detail+=("양호"); detail+=("-")
        if [[ "$output_mode" == "all" ]]; then
            result_print "U_26" "$desc" "$total_result" "${detail[@]}"
        elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
            result_print "U_26" "$desc" "$total_result" "${detail[@]}"
        fi
        return

        else
        
        detail+=("automount"); detail+=("취약"); detail+=("$automount")
        detail+=("autofs"); detail+=("취약"); detail+=("$autofs")

        total_result="취약"
        if [[ "$output_mode" == "all" ]]; then
            result_print "U_26" "$desc" "$total_result" "${detail[@]}"
        elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
            result_print "U_26" "$desc" "$total_result" "${detail[@]}"
        fi
        
        # 추가 점검 사항
        # U_00
    fi
}

U_27()
{
    local output_mode=$1
    desc="불필요한 RPC 서비스의 실행 여부 점검"
    detail=()
    total_result="양호"

    conf_dir=$(find / -name "inetd.*" 2>/dev/null)

    if [[ "$conf_dir" == "" ]]; then
        
        detail+=("No RPC Service"); detail+=("양호"); detail+=("-")
        if [[ "$output_mode" == "all" ]]; then
            result_print "U_27" "$desc" "$total_result" "${detail[@]}"
        elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
            result_print "U_27" "$desc" "$total_result" "${detail[@]}"
        fi
        
        return

        else
        
        detail+=("No RPC Service"); detail+=("취약"); detail+=("/etc/inetd.conf 을 점검하십시오.")
        total_result="취약"
        if [[ "$output_mode" == "all" ]]; then
            result_print "U_27" "$desc" "$total_result" "${detail[@]}"
        elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
            result_print "U_27" "$desc" "$total_result" "${detail[@]}"
        fi
        # 추가 점검 사항
        # U_00
    fi
}

U_28()
{
    local output_mode=$1
    desc="안전하지 않은 NIS 서비스의 비활성화, 안전한 NIS+ 서비스의 활성화 여부 점검"
    detail=()
    total_result="양호"

    nis_services=("ypserv" "ypbind" "yppasswdd" "ypxfrd" "rpc.yppasswdd")

    nis_active=0
    for service in "${nis_services[@]}"; do
        status=$(is_on_service "$service")
        if [ "$status" = "active" ]; then
            detail+=("$service")
            detail+=("취약")
            detail+=("비활성화가 필요합니다.")
        #    echo "안전하지 않은 NIS 서비스 '$service'가 활성화되어 있습니다. 비활성화가 필요합니다."
            nis_active=1
        fi
    done

    if [ $nis_active -eq 0 ]; then
        detail+=("NIS 서비스")
        detail+=("양호")
        detail+=("-")
        # echo "모든 안전하지 않은 NIS 서비스가 비활성화되어 있습니다."
    fi

    # NIS+ 서비스 확인 (안전함)
    nisplus_service="nisplus"

    nisplus_status=$(is_on_service "$nisplus_service" 2>/dev/null)
    nisplus_enabled=$(is_service_enabled "$nisplus_service" 2>/dev/null)

    if [ "$nisplus_status" = "active" ]; then
        detail+=("NIS+")
        detail+=("양호")
        detail+=("-")
        # echo "안전한 NIS+ 서비스 '$nisplus_service'가 활성화되어 있습니다."
    else
        detail+=("NIS+")
        detail+=("취약")
        detail+=("활성화 필요")
        # echo "안전한 NIS+ 서비스 '$nisplus_service'가 활성화되어 있지 않습니다."
    fi

    if [ "$nisplus_enabled" = "enabled" ]; then
        detail+=("NIS+ 부팅 설정")
        detail+=("양호")
        detail+=("-")
        # echo "안전한 NIS+ 서비스 '$nisplus_service'가 부팅 시 시작되도록 설정되어 있습니다."
    else
        detail+=("NIS+ 부팅 설정")
        detail+=("취약")
        detail+=("부팅 시 시작되지 않도록 설정되어 있습니다.")
        # echo "안전한 NIS+ 서비스 '$nisplus_service'가 부팅 시 시작되지 않도록 설정되어 있습니다."
    fi

    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_28" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_28" "$desc" "$total_result" "${detail[@]}"
    fi
}
#############################################################################################
U_18()
{
    local output_mode=$1
    #변수 선언
    desc="접속 IP 및 포트 제한"
    detail=()
    total_result="양호"

    # iptables_rule 검사
    detail+=("iptables_rule")
    check=`iptables -L | awk -F 'Chain' '{print $1}' | awk -F 'target' '{print $1}' | tr -d "\\\\n" | wc -w`

    if [ $check=0 ]; then
        detail+=("취약")
        detail+=("iptables 명령어를 통해 정책 추가")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}";then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_18" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_18" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_55()
{
    local output_mode=$1
    #변수 선언
    desc="hosts.lpd 파일 소유자 및 권한 설정"
    detail=()
    total_result="양호"

    # hostl.lpd 파일  검사
    detail+=("hostl.lpd")
    FILE=/etc/host.lpd

    if [ -e $FILE ]; then
        detail+=("취약")
        detail+=("host.lpd 파일 삭제")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}";then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_55" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_55" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_56()
{
    local output_mode=$1
    #변수 선언
    desc="UMASK 설정 관리"
    detail=()
    total_result="양호"

    # UMASK  검사
    detail+=("UMASK")

    if [ $? -eq 0 ]; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("UMASK값 022로 변경")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}";then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_56" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_56" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_57()
{
    local output_mode=$1
    # 변수 선언
    desc="홈디렉터리 소유자 및 권한 설정"
    detail=()
    total_result="양호"

   #detail+=("홈디렉터리 소유자 및 권한 검사")

    # 홈 디렉터리 소유자 및 권한 검사
    for dir in /home/*; do
        if [ -d "$dir" ]; then
            owner=$(stat -c '%U' "$dir")
            permissions=$(stat -c '%A' "$dir")
            detail+=("홈디렉터리 소유자 검사$dir ")

            # 조건: 홈 디렉터리 소유자가 해당 사용자여야 하고, 쓰기 권한이 타 사용자에게 없어야 함
            if [[ "$owner" == "$(basename "$dir")" ]] && [[ $(stat -c '%a' "$dir") -eq 700 ]]; then
                detail+=("양호")
                detail+=("-")
            else
                detail+=("취약")
                detail+=("사용자별 홈 디렉터리 소유주를 해당 계정으로 변경하고, 타 사용자의 쓰기 권한 제거")
            fi
        fi
    done

    # 홈 디렉터리가 없을 경우 추가 취약점 표시
    if [ -z "$(ls -A /home/)" ]; then
        detail+=("취약")
        detail+=("홈 디렉터리가 없습니다.")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_57" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_57" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_58()
{
    local output_mode=$1
    #변수 선언
    desc="홈디렉토리로 지정한 디렉토리의 존재 관리"
    detail=()
    total_result="양호"

    detail+=("홈디렉터리 존재")

    if [ -z $HOMEDIR ]; then
        detail+=("취약")
        detail+=("홈디렉터리 설정 또는 계정 삭제")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}";then
        total_result="취약"
    fi

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_58" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_58" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_59()
{
    local output_mode=$1
    # 변수 선언
    desc="숨겨진 파일 및 디렉터리 검색 및 제거"
    detail=()
    total_result="양호"

    detail+=("불필요하거나 의심스러운 숨겨진 파일 검사")

    # 숨겨진 파일 및 디렉터리 검색
    suspicious_files=$(find /home -name ".*" -type f -o -type d -print 2>/dev/null)

    if [ -z "$suspicious_files" ]; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("불법적이거나 의심스러운 파일을 삭제함")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_59" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_59" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_42()
{
    local output_mode=$1
    # 변수 선언
    desc="최신 보안패치 및 벤더 권고사항 적용"
    detail=()
    total_result="양호"

    detail+=("패치 상태")

    # 시스템이 최신 상태인지 확인 (Rocky/CentOS/RHEL의 경우 dnf 사용)
    if command -v dnf >/dev/null 2>&1; then
        # dnf를 사용하여 업데이트가 있는지 확인
        updates=$(dnf check-update --security | grep -E '^(RHSA|CVE)')
    elif command -v yum >/dev/null 2>&1; then
        # yum 기반 시스템에서 업데이트 확인
        updates=$(yum check-update --security | grep -E '^(RHSA|CVE)')
    elif command -v apt >/dev/null 2>&1; then
        # Debian/Ubuntu 시스템에서 apt를 사용하여 업데이트 확인
        apt update >/dev/null 2>&1
        updates=$(apt list --upgradable 2>/dev/null | grep -i security)
    else
        echo "지원되지 않는 패키지 관리자입니다."
        return
    fi

    # 보안 업데이트가 있는지 확인
    if [ -z "$updates" ]; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("O/S 관리자, 서비스 개발자가 패치 적용에 따른 서비스 영향정도를 파악하여 적용한다")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_42" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_42" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_43()
{
    local output_mode=$1
    # 변수 선언
    desc="로그의 정기적 검토 및 보고"
    detail=()
    total_result="양호"

    detail+=("로그 상태")

    # 로그 파일이 있는지 확인 (예: /var/log/syslog 또는 /var/log/messages 등)
    log_files=("/var/log/syslog" "/var/log/messages" "/var/log/auth.log")

    log_found=false
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            # 로그 파일이 있으면 검토가 이루어졌는지 확인
            last_log_check=$(stat -c %Y "$log_file")  # 마지막 수정 시간을 확인
            current_time=$(date +%s)
            time_diff=$(( (current_time - last_log_check) / 86400 ))  # 일 단위 시간차 계산

            # 로그가 최근 7일 내에 기록되었으면 양호로 판단
            if [ "$time_diff" -le 7 ]; then
                log_found=true
                detail+=("양호")
                detail+=("-")
                break
            fi
        fi
    done

    if [ "$log_found" = false ]; then
        detail+=("취약")
        detail+=("로그 기록 검토 및 분석을 시행하여 리포트를 작성하고 정기적으로 보고함")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_43" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_43" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_72()
{
    local output_mode=$1
    # 변수 선언
    desc="정책에 따른 시스템 로깅 설정"
    detail=()
    total_result="양호"

    detail+=("로그 기록 정책")

    # 로그 설정 파일이 있는지 확인
    log_conf_file="/etc/rsyslog.conf"
    if [ ! -f "$log_conf_file" ]; then
        log_conf_file="/etc/syslog.conf"
    fi

    if [ -f "$log_conf_file" ]; then
        # 로그 설정 파일에서 필요한 정책이 설정되었는지 확인 (예: *.info 또는 authpriv.* 로그 레벨)
        log_policy_check=$(grep -E "^\*\.info|authpriv\.\*" "$log_conf_file")

        if [ -n "$log_policy_check" ]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            detail+=("로그 기록 정책을 수립하고, 정책에 따라 syslog.conf 파일을 설정")
        fi
    else
        detail+=("취약")
        detail+=("로그 설정 파일이 존재하지 않음. 로그 기록 정책을 수립하고 설정 필요")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_72" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_72" "$desc" "$total_result" "${detail[@]}"
    fi
}
#############################################################################################
U_01()
{
    local output_mode=$1
    # 점검 코드 실행
    Rootlogin=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')


    if [[ $Rootlogin == "no" ]]; then
        total_result="양호"
    else
        total_result="취약"
    fi

        result=${total_result}
        case ${result} in
                "양호")
                        res="양호" ;;
                "취약")
                        res="취약" ;;
        esac
        order=${result}
        case ${result} in
                "양호")
                        var=" 양호";;
                "취약")
                        var="원격ROOT 로그인 설정 확인 yes > no 수정" ;;
        esac

    # 결과값 변수에 저장
    desc="root 계정 원격접속 제한"
    detail_1="SSH"

    detail_1_result="$res"
    detail_1_order="$var"

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_01" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_01" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_02()
{
    local output_mode=$1
    # 점검 코드 실행
    password1=`cat /etc/security/pwquality.conf | grep minlen | awk  '{print $4}'`
    password2=`cat /etc/security/pwquality.conf | grep lcredit | awk '{print $4}'`
    password3=`cat /etc/security/pwquality.conf | grep ucredit | awk '{print $3}'`
    password4=`cat /etc/security/pwquality.conf | grep dcredit | awk '{print $4}'`
    password5=`cat /etc/security/pwquality.conf | grep ocredit | awk '{print $4}'`

    # 초기 설정 설명 변수
    minlen_desc="최소 패스워드 길이 설정"
    lcredit_desc="최소 소문자 요구"
    ucredit_desc="최소 대문자 요구"
    dcredit_desc="최소 숫자 요구"
    ocredit_desc="최소 특수문자 요구"

    # 결과값 변수에 저장
    desc="패스워드 복잡성 점검"

    # 기본 결과 설정
    total_result="취약"
    detail_1="패스워드 설정"
    detail_1_result="양호"
    detail_1_order="요구사항"
    total_result="취약"

    # 각 설정 확인 및 결과 저장
    if [[ $password1 != "8" ]]; then
        detail_1_result="취약"
    else
        detail_1_result="양호"
    fi

    # lcredit 확인
    if [[ $password2 != "-1" ]]; then
        lcredit_result="취약"
    else
        lcredit_result="양호: $lcredit_value ($lcredit_desc)"
    fi

    # ucredit 확인
    if [[ $password3 != "-1" ]]; then
        ucredit_result="취약"
    else
        ucredit_result="양호"
    fi

    # dcredit 확인
    if [[ $password4 != "-1" ]]; then
        dcredit_result="취약"
    else
        dcredit_result="양호: $dcredit_value ($dcredit_desc)"
    fi

    # ocredit 확인
    if [[ $password5 != "-1" ]]; then
        ocredit_result="취약"
    else
        ocredit_result="양호: $ocredit_value ($ocredit_desc)"
    fi
    # 함수 실행 예시
    

    if [[ "$output_mode" == "all" ]]; then
        result_print "U-02" "$desc" "$total_result"  \
                 "$minlen_desc" "$detail_1_result" "minlen : 최소 8자리 이상 설정" \
                 "$lcredit_desc" "$lcredit_result" "lcredit : 소문자 최소 1자리 이상 요구" \
                 "$ucredit_desc" "$ucredit_result" "ucredit : 대문자 최소 1자리 이상 요구" \
                 "$dcredit_desc" "$dcredit_result" "dcredit : 숫자 최소 1자리 이상 요구" \
                 "$ocredit_desc" "$ocredit_result" "ocredit : 특수문자 최소 1자리 이상 요구"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U-02" "$desc" "$total_result"  \
                 "$minlen_desc" "$detail_1_result" "minlen : 최소 8자리 이상 설정" \
                 "$lcredit_desc" "$lcredit_result" "lcredit : 소문자 최소 1자리 이상 요구" \
                 "$ucredit_desc" "$ucredit_result" "ucredit : 대문자 최소 1자리 이상 요구" \
                 "$dcredit_desc" "$dcredit_result" "dcredit : 숫자 최소 1자리 이상 요구" \
                 "$ocredit_desc" "$ocredit_result" "ocredit : 특수문자 최소 1자리 이상 요구"
    fi
}

U_03()
{
    local output_mode=$1
 #계정 잠금 임계값 설정
    desc="계정 잠금 임계값 설정 여부"
    detail_1="deny 설정"
    detail_1_order="계정 잠금 임계값이 10회 이하로 설정되어야 함"

    # pam_tally.so deny 값 추출
    pam_file="/etc/pam.d/system-auth"
    deny_value=$(grep -oP '(?<=pam_tally.so deny=)[0-9]+' $pam_file)


    if [[ "$output_mode" == "all" ]]; then
        # 판단 기준에 따라 결과 결정
        if [ -z "$deny_value" ]; then
            # deny 값이 설정되지 않았을 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "취약" " deny 값이 없음"

        elif [ "$deny_value" -le 10 ]; then
            # deny 값이 10 이하일 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "양호"

        else
            # deny 값이 10을 초과할 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "취약" "$detail_1_order"
        fi
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        # 판단 기준에 따라 결과 결정
        if [ -z "$deny_value" ]; then
            # deny 값이 설정되지 않았을 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "취약" " deny 값이 없음"

        elif [ "$deny_value" -le 10 ]; then
            # deny 값이 10 이하일 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "양호"

        else
            # deny 값이 10을 초과할 때
            result_print "U_03" "$desc" "$total_result" "$detail_1" "취약" "$detail_1_order"
        fi
    fi
}

U_04()
{
    local output_mode=$1
        # 점검 기준 설명
        passwd_file="/etc/passwd"
        shadow_file="/etc/shadow"
        if [ ! -f "$shadow_file" ]; then
            sha="취약"
    else
            sha="양호"
        fi
    case ${sha} in
            "취약")
                    detil_1="shadow 파일 유무"
                    ca="쉐도우, 패스워드의암호화가 안되어있다" ;;
            "양호")
                    detil_1="shadow 파일 유무"
                    ca="-" ;;
    esac
        desc="쉐도우 패스워드 사용 여부"
        requirement="$ca"
        shadow="$sha"
        detil_2="패스워드 암호화"
        while IFS=: read -r username password rest; do
            if [ "$password" != "x" ]; then
            pwa="취약"
    else
            pwa="양호"
            fi

    case ${pwa} in
            "취약")
                    pwas="취약"
                    req="쉐도우, 패스워드의 암호화가 안되어있다";;
            "양호")
                    pwas="양호"
                    req="-";;
    esac

        done < "$passwd_file"

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_04" "$desc" "$sha" "$detil_1" "$shadow" "$requirement" "$detil_2" "$pwas" "$req"
    elif [[ "$output_mode" == "vulnerable" && "$sha" == "취약" ]]; then
        result_print "U_04" "$desc" "$sha" "$detil_1" "$shadow" "$requirement" "$detil_2" "$pwas" "$req"
    fi
    
}

U_44()
{
    local output_mode=$1
    # root 이외의 UID가 '0' 금지
    desc="root 이외의 UID가 '0' 인계정체크"

    while IFS=: read -r username password uid gid info home shell; do
        if [ "$uid" -eq 0 ] && [ "$username" != "root" ]; then
            detail_1="취약"
    else
            detail_1="양호"
        fi
    case ${detail_1} in
            "취약")
                    detail_1_sourlt="$username : UID 확인";;
            "양호")
                    detail_1_sourlt="-";;
    esac
    done < /etc/passwd

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_44" "$desc" "$detail_1" "$desc" "$detail_1" "$detail_1_sourlt"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1" == "취약" ]]; then
        result_print "U_44" "$desc" "$detail_1" "$desc" "$detail_1" "$detail_1_sourlt"
    fi
    
}

U_45() 
{
    local output_mode=$1
    desc="root 계정 su 제한"
    group_name="wheel"
    group_info=$(getent group "$group_name")
    wg="su 그룹 확인"
    if [ -z "$group_info" ]; then
        wheel_g="취약"
        wheel_g_result="wheel 그룹이 없습니다."
    else
        wheel_g="양호"
        wheel_g_result="wheel 그룹이 존재합니다."
    fi

    su_p=""
    sp="su 명령어 권한"
    su_path=$(command -v su)  # su 명령어의 경로 확인
    if [ -z "$su_path" ]; then
        su_p="취약"
        su_p_result="su 명령어가 없습니다."
    else
        su_mode=$(stat -c "%a" "$su_path")  # su 명령어의 권한 확인
        if [ "$su_mode" -eq 4750 ]; then
            su_p="양호"
            su_p_result="su 명령어의 권한이 4750으로 설정되어 있습니다."
        else
            su_p="취약"
            su_p_result="su 명령어의 권한이 $su_mode (4750이 아님)으로 설정되어 있습니다."
        fi
    fi

    wm="su 그룹 사용자"
    if [ "$wheel_g" = "양호" ]; then
        wheel_users=$(getent group "$group_name" | awk -F: '{print $4}')  # wheel 그룹의 사용자 목록 확인
        if [ -n "$wheel_users" ]; then
            non_root_users=$(echo "$wheel_users" | grep -v "^root$")  # root 이외의 사용자 필터링
            if [ -n "$non_root_users" ]; then
                wheel_m="취약"
                wheel_m_result="wheel 그룹에 root 이외의 사용자가 있습니다: $non_root_users"
            else
                wheel_m="양호"
                wheel_m_result="-"
            fi
        else
            wheel_m="양호"
            wheel_m_result="wheel 그룹에 사용자가 없습니다."
        fi
    else
        wheel_m="점검 불가"
        wheel_m_result="wheel 그룹이 없으므로 확인할 수 없습니다."
    fi
    
    if [ "$wheel_g" = "취약" ] || [ "$su_p" = "취약" ] || [ "$wheel_m" = "취약" ]; then
            total_sourlt="취약"
    else
            total_sourlt="양호"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_45" "$desc" "$total_sourlt" "$wg" "$wheel_g" "$wheel_g_result" "$sp" "$su_p" "$su_p_result" "$wm" "$wheel_m" "$wheel_m_result"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_45" "$desc" "$total_sourlt" "$wg" "$wheel_g" "$wheel_g_result" "$sp" "$su_p" "$su_p_result" "$wm" "$wheel_m" "$wheel_m_result"
    fi
}

U_46()
{
    local output_mode=$1
    desc="패스워드 최소 길이 설정"
    paswd=`cat /etc/login.defs | grep -e "^PASS_MIN_LEN" | awk '{print $2}'`

    if [ -z "$paswd" ]; then
            detail_1_resoult="취약"
            detail_1_order="PASS_MIN_LEN 설정이 없습니다"

    elif  [ "$paswd" != 8 ]; then
            detail_1_resoult="취약"
            detail_1_order="최소길이 8자 미만"
    else
            detail_1_resoult="양호"
            detail_1_order="최소길이 8자 이상"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_46" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_46" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    fi
}

U_47()
{
    local output_mode=$1
    desc="패스워드 최대 사용일"
    paswd=`cat /etc/login.defs | grep -e "^PASS_MAX_DAYS" | awk '{print $2}'`

    if [ -z "$paswd" ]; then
            detail_1_resoult="취약"
            detail_1_order="PASS_MAX_DAYZ 설정이 없습니다"

    elif  [ "$paswd" -gt 90 ]; then
            detail_1_resoult="취약"
            detail_1_order="최대사용일 90일이상"
    else
            detail_1_resoult="양호"
            detail_1_order="최대 사용일 90일 이하"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_47" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_47" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    fi
}

U_48()
{
    local output_mode=$1
    desc="패스워드 최소 사용일"
    paswd=`cat /etc/login.defs | grep -e "^PASS_MIN_DAYS" | awk '{print $2}'`

    if [ -z "$paswd" ]; then
            detail_1_resoult="취약"
            detail_1_order="PASS_MAX_DAYZ 설정이 없습니다"

    elif  [ "$paswd" -lt 1 ]; then
            detail_1_resoult="취약"
            detail_1_order="최소사용일이 설정되어 있지 않음"
    else
            detail_1_resoult="양호"
            detail_1_order="최소사용일 1일 이상"
    fi

    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_48" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_48" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    fi
}

U_49()
{
    local output_mode=$1
 #불필요한 계정 삭제
    desc="불필요한 계정 존재 여부"

    # 시스템 계정 리스트 정의 (필요에 따라 추가/수정 가능)
    # 필요하지 않은 불필요한 계정을 여기에 추가할 수 있습니다.
    unnecessary_accounts=("games" "ftp" "nobody" "lp" "sync" "shutdown" "halt" "news" "uucp")

    # 불필요한 계정이 존재하는지 확인
    detected_accounts=()
    while IFS=: read -r username _ uid _; do
        # 사용자 UID가 1000 이상인 계정만 확인
        if [[ "$uid" -ge 1000 && " ${unnecessary_accounts[@]} " =~ " $username " ]]; then
            detected_accounts+=("$username")
        fi
    done < /etc/passwd

    # 결과 값 설정
    if [ ${#detected_accounts[@]} -eq 0 ]; then
        result="양호"
        detail_1="불필요한 계정이 존재하지 않습니다."
    else
        result="취약"
        detail_1="불필요한 계정이 존재합니다: ${detected_accounts[*]}"
    fi

    # 결과 출력
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_49" "$desc" "$result" "$desc" "$result" "$detail_1"
    elif [[ "$output_mode" == "vulnerable" && "$result" == "취약" ]]; then
        result_print "U_49" "$desc" "$result" "$desc" "$result" "$detail_1"
    fi
}

#############################################################################################

U_35()
{
    local output_mode=$1
    # 변수 선언
    desc="웹서비스 디렉터리 리스팅 제거"
    detail=()
    total_result="양호"

    detail+=("디렉터리 검색 기능 사용 여부")

    # Apache 설정 파일에서 'Options Indexes'가 있는지 확인
    if grep -q "Options Indexes" /etc/httpd/conf/httpd.conf; then
        detail+=("취약")
        detail+=("디렉터리 검색 기능 제거 필요")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_35" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_35" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_36()
{
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 웹 프로세스 권한 제한"
    detail=()
    total_result="양호"

    detail+=("Apache 데몬 root 권한으로 구동 여부")

    # Apache 데몬이 root 권한으로 실행되고 있는지 확인
    if ps aux | grep '[h]ttpd' | awk '{print $1}' | grep -q "root"; then
        detail+=("취약")
        detail+=("Apache 데몬을 root가 아닌 별도 계정으로 구동")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_36" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_36" "$desc" "$total_result" "${detail[@]}"
    fi
}
U_37()
{
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 상위 디렉터리 접근 금지"
    detail=()
    total_result="양호"

    detail+=("상위 디렉터리에 이동제한 설정 여부")

    # Apache 설정에서 상위 디렉터리 접근 금지 설정 확인 (예: 'AllowOverride None' 또는 'Options -Indexes' 확인)
    if grep -q "AllowOverride None" /etc/httpd/conf/httpd.conf || grep -q "Options -Indexes" /etc/httpd/conf/httpd.conf; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("상위 디렉터리 접근을 제한하기 위해 'AllowOverride None' 설정하십시오.")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_37" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_37" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_38()
{
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 불필요한 파일 제거"
    detail=()
    total_result="양호"

    detail+=("불필요한 파일 유무")

    # 불필요한 파일 점검 (예: Apache 설치 시 기본 제공되는 예제 파일)
    if find /var/www/html -type f \( -name "manual" -o -name "test.php" -o -name "*.bak" \) | grep -q .; then
        detail+=("취약")
        detail+=("불필요한 파일 및 디렉터리 제거")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_38" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_38" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_39()
{
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 링크 사용금지"
    detail=()
    total_result="양호"
    detail+=("심볼릭 링크, aliases 사용 제한 여부")

    # Apache 설정에서 심볼릭 링크 및 aliases 사용 여부 확인
    # 'Options -FollowSymLinks' 및 'Options -Indexes' 확인
    if grep -q "Options -FollowSymLinks" /etc/httpd/conf/httpd.conf || grep -q "Options -Indexes" /etc/httpd/conf/httpd.conf; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("심볼릭 링크 및 aliases 사용 제한")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_39" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_39" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_40() {
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 파일 업로드 및 다운로드 제한"
    detail=()
    total_result="양호"

    detail+=("파일 업로드 및 다운로드 제한 여부")

    # 웹 서버 설정 파일 경로 (Nginx나 Apache 서버에 맞게 설정 파일 경로 수정)
    apache_conf_file="/etc/httpd/conf/httpd.conf"
    nginx_conf_file="/etc/nginx/nginx.conf"

    if [ -f "$apache_conf_file" ]; then
        # Apache 웹 서버의 경우 파일 업로드 및 다운로드 제한 설정 확인
        upload_limit_check=$(grep -i "LimitRequestBody" "$apache_conf_file")
        if [ -n "$upload_limit_check" ]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            detail+=("파일 업로드 및 다운로드 용량 제한, 파일 사이즈 용량 제한 설정 필요 (Apache)")
        fi

    elif [ -f "$nginx_conf_file" ]; then
        # Nginx 웹 서버의 경우 파일 업로드 및 다운로드 제한 설정 확인
        upload_limit_check=$(grep -i "client_max_body_size" "$nginx_conf_file")
        if [ -n "$upload_limit_check" ]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            detail+=("파일 업로드 및 다운로드 용량 제한, 파일 사이즈 용량 제한 설정 필요 (Nginx)")
        fi

    else
        # 웹 서버 설정 파일이 없는 경우
        detail+=("취약")
        detail+=("웹 서버 설정 파일을 찾을 수 없습니다. 파일 업로드 및 다운로드 제한 설정 필요")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_40" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_40" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_41() {
    # 변수 선언
    local output_mode=$1
    desc="웹서비스 영역의 분리"
    detail=()
    total_result="양호"

    detail+=("DocumentRoot 디렉터리 경로")

    # Apache 또는 Nginx 웹 서버 설정 파일 확인
    apache_conf_file="/etc/httpd/conf/httpd.conf"
    nginx_conf_file="/etc/nginx/nginx.conf"

    # 기본 웹 루트 경로들 (잘못된 경로의 예시)
    default_roots=("/usr/local/apache/htdocs" "/usr/local/apache2/htdocs" "/var/www/html")

    if [ -f "$apache_conf_file" ]; then
        # Apache 서버에서 DocumentRoot 확인
        document_root=$(grep -i "DocumentRoot" "$apache_conf_file" | awk '{print $2}')
    elif [ -f "$nginx_conf_file" ]; then
        # Nginx 서버에서 root 디렉터리 확인
        document_root=$(grep -i "root" "$nginx_conf_file" | awk '{print $2}')
    else
        # 설정 파일이 없을 때
        detail+=("취약")
        detail+=("웹 서버 설정 파일을 찾을 수 없습니다.")
    fi

    # DocumentRoot 경로가 시스템 중요 디렉터리가 아닌지 확인
    if [[ " ${default_roots[@]} " =~ " ${document_root} " ]]; then
        detail+=("취약")
        detail+=("DocumentRoot가 기본 경로에 설정되어 있습니다. 시스템 중요 디렉터리 외의 경로에 웹서비스를 설치하세>요.")
    elif [ -n "$document_root" ]; then
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_41" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_41" "$desc" "$total_result" "${detail[@]}"
    fi
    
}

U_29()
{
    local output_mode=$1
    code="U_29"

    # 점검 코드 실행
    check=`cat -al /etc/inetd.conf 2>/dev/null | grep "tftp|talk|ntalk | '{print $1}'"`

    if [[ "$check" == "" ]]; then
        result="파일 없음"
        order="-"
    elif [[ "$check" == "#" ]]; then
        result="양호"
        order="-"
    else
        result="취약"
        order="tftp, talk, ntalk 주석 처리 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="tftp, talk 서비스 비활성화"
    total_result=$result
    detail_1="/etc/inetd.conf"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_30()
{
    local output_mode=$1
    code="U_30"

    # 점검 코드 실행
    check=`ps -ef | grep sendmail`

    if [[ "$check" == "" ]]; then
        result="양호"
        order="-"
    else
        result="취약"
        order="Sendmail 서비스 점검 필요"
    fi

    # 결과값 변수에 저장 ()
    desc="Sendmail 버전 점검"
    total_result=$result
    detail_1="Sendmail 서비스"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_31()
{
    local output_mode=$1
    code="U_31"

    # 점검 코드 실행
    check1=`ps -ef | grep sendmail | grep -v "grep" 2>/dev/null`
    check2=`cat /etc/mail/sendmail.cf 2>/dev/null| grep "R$\*" | grep "Relaying denied"`

    if [[ "$check1" == "" ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order1="SMTP 서비스 사용중"
    fi

    if [[ "$check2" == "" ]]; then
        result2="양호"
        order1="-"
    else
        result2="취약"
        order2="설정 필요"
    fi

    if [[ "$result1" == "취약" || "$result2" == "취약" ]]; then
        result="취약"
    else
        result="양호"
    fi

    # 결과값 변수에 저장 ()
    desc="스팸 메일 릴레이 제한"
    total_result=$result
    detail_1="STMP 서비스 유무"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="릴레이 방지 설정"
    detail_2_result=$result2
    detail_2_order=$order2

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_32()
{
    local output_mode=$1
    code="U_32"

    # 점검 코드 실행
    check1=`ps -ef | grep sendmail | grep -v "grep" 2>/dev/null`
    check2=`grep -v '^ *#' /etc/mail/sendamil.cf 2>/dev/null | grep PrivacyOptions`

    if [[ "$check1" == "" ]]; then
        result1="양호"
        order1="-"
    else
        result1="취약"
        order1="SMTP 서비스 사용중"
    fi

    if [[ "$check2" == "" ]]; then
        result2="양호"
        order1="-"
    else
        result2="취약"
        order2="일반 사용자의 Sendmail 실행 방시 설정 필요"
    fi

    if [[ "$result1" == "취약" || "$result2" == "취약" ]]; then
        result="취약"
    else
        result="양호"
    fi

    # 결과값 변수에 저장 ()
    desc="일반사용자의 Sendmail 실행 방지"
    total_result=$result
    detail_1="STMP 서비스 유무"
    detail_1_result=$result1
    detail_1_order=$order1
    detail_2="일반사용자의 Sendmail 실행 방지"
    detail_2_result=$result2
    detail_2_order=$order2

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order" "$detail_2" "$detail_2_result" "$detail_2_order"
    fi
}

U_33()
{
    local output_mode=$1
    code="U_33"

    # 점검 코드 실행
    check=`named -v 2>/dev/null`

    if [[ "$check" == "" ]]; then
        result="양호"
        order="-"
        detail_1="DNS 서비스 사용X"
    else
        detail_1="DNS 서비스 사용중"
        result="취약"
        order="DNS 보안 버전 패치 필요"
    fi

    # 결과값 변수에 저장 ()
    total_result=$result
    detail_1="Sendmail 서비스"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_34()
{
    local output_mode=$1
    code="U_34"

    # 점검 코드 실행
    check=`cat /etc/named.conf 2>/dev/null | grep 'allow-transfer'`

    if [[ "$check" == "" ]]; then
        result="양호"
        order="-"
    else
        result="취약"
        order="허가된 사용자에게만 허용 설정 필요"
    fi

    # 결과값 변수에 저장 ()
    total_result=$result
    desc="DNS Zone Transfer 설정"
    detail_1="DNS Zone Transfer"
    detail_1_result=$result
    detail_1_order=$order


    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "$code" "$desc" "$total_result" "$detail_1" "$detail_1_result" "$detail_1_order"
    fi
}

U_60()
{
    # 변수 선언
    local output_mode=$1
    desc="ssh 원격접속 허용"
    detail=()
    total_result="양호"

    ssh=$(is_on_service sshd)

    if [[ "$ssh" == "inactive" ]]; then
        detail+=("ssh 접속 허용")
        detail+=("취약")
        detail+=("필요 시 접속 허용")
    else
        detail+=("ssh 접속 허용")
        detail+=("양호")
        detail+=("필요 시 접속 허용")

    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_60" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_60" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_62()
{
    # 변수 선언
    local output_mode=$1
    desc="ftp 계정 쉘 점검"
    detail=()
    total_result="양호"


    if grep -q '^ftp:.*:/bin/false$' /etc/passwd; then
        detail+=("ftp 사용자 shell 점검")
        detail+=("양호")
        detail+=("-")
    else
        detail+=("ftp 사용자 shell 점검")
        detail+=("취약")
        detail+=("/bin/false 로 수정 필요")
    fi


    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_62" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_62" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_69(){
local output_mode=$1
desc="NFS 설정파일 접근권한"
nfs_path="/etc/exports"

if [ ! -f "$nfs_path" ]; then
    detail_1_resoult="취약"
    detail_1_order="NFS 접근제어 파일이 존재하지 않습니다."
else
    su_mode=$(stat -c "%a" "$nfs_path")
    if [ "$su_mode" -eq 644 ]; then
        detail_1_resoult="양호"
        detail_1_order="NFS 설정 파일의 권한이 644로 설정되어 있습니다."
    else
        detail_1_resoult="취약"
        detail_1_order="NFS 설정 파일의 권한이 644가 아닙니다 (현재 권한: $su_mode)."
    fi
fi


if [[ "$output_mode" == "all" ]]; then
        result_print "U_69" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_69" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order"
    fi
}


U_70(){
    local output_mode=$1
    desc="expn,vrfy 명령어 제한"

    smtp_service="postfix"  # 사용하는 SMTP 서비스에 따라 변경
    config_file="/etc/postfix/main.cf"  # 설정 파일 경로

    # SMTP 서비스 설치 여부 확인
    if ! systemctl status $smtp_service &>/dev/null; then
        detail_1_resoult="취약"
        detail_1_order="$smtp_service 서비스가 설치,실행되고 있지 않습니다."
    else
        detail_1_resoult="양호"
        detail_1_order="-"
fi
        # noexpn 옵션 확인
        noexpn=$(grep -E "noexpn" $config_file 2>/dev/null)
        if [[ -z $noexpn ]]; then
            detail_2_resoult="취약"
            detail_2_order="noexpn 설정이 없습니다"
        else
            detail_2_resoult="양호"
            detail_2_order="-"
        fi

        # novrfy 옵션 확인
        novrfy=$(grep -E "novrfy" $config_file 2>/dev/null)
        if [[ -z $novrfy ]]; then
            detail_3_resoult="취약"
            detail_3_order="novrfy 설정이 없습니다"
        else
            detail_3_resoult="양호"
            detail_3_order="-"
        fi

        # goaway 옵션 확인
        goaway=$(grep -E "goaway" $config_file 2>/dev/null)
        if [[ -z $goaway ]]; then
            detail_4_resoult="취약"
            detail_4_order="goaway 설정이 없습니다"
        else
            detail_4_resoult="양호"
            detail_4_order="-"
        fi


    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_70" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order" \
        "$desc" "$detail_2_resoult" "$detail_2_order" \
        "$desc" "$detail_3_resoult" "$detail_3_order" \
        "$desc" "$detail_4_resoult" "$detail_4_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_70" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order" \
        "$desc" "$detail_2_resoult" "$detail_2_order" \
        "$desc" "$detail_3_resoult" "$detail_3_order" \
        "$desc" "$detail_4_resoult" "$detail_4_order"
    fi
    
}


U_71(){
    local output_mode=$1
desc="Apache 웹 서비스 정보 숨김 "
apache=`cat /etc/httpd/conf/httpd.conf | grep -e "ServerTokens" | awk '{print $2}'`
apache2=`cat /etc/httpd/conf/httpd.conf | grep -e "ServerSignature" | awk '{print $2}'`


if [ -z "$apache" ]; then
        detail_1_resoult="취약"
        detail_1_order="ServerTokens 설정이 없습니다"

elif  [ "$apache" != "Prod" ]; then
        detail_1_resoult="취약"
        detail_1_order="ServerTokens 설정되어 있지 않음"
else
        detail_1_resoult="양호"
        detail_1_order="-"
fi

if [ -z "$apache2" ]; then
        detail_2_resoult="취약"
        detail_2_order="ServerSignature 설정이 없습니다"

elif  [ "$apache" != "off" ]; then
        detail_2_resoult="취약"
        detail_2_order="ServerSingnature 설정되어 있지 않음"
else
        detail_2_resoult="양호"
        detail_2_order="-"
fi



    if [[ "$output_mode" == "all" ]]; then
        result_print "U_71" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order" "$desc" "$detail_2_resoult" "$detail_2_order"
    elif [[ "$output_mode" == "vulnerable" && "$detail_1_resoult" == "취약" ]]; then
        result_print "U_71" "$desc" "$detail_1_resoult" "$desc" "$detail_1_resoult" "$detail_1_order" "$desc" "$detail_2_resoult" "$detail_2_order"
    fi
}

U_64() {
    # 변수 선언
    local output_mode=$1
    desc="ftpusers 파일 설정(FTP 서비스 root 계정 접근제한)"
    detail=()
    total_result="양호"

    detail+=("FTP 서비스 활성화 여부 및 root 계정 포함 여부")

    # FTP 서비스 활성화 여부 확인 (FTP 서비스가 활성화된 경우만 체크)
    if systemctl is-active --quiet vsftpd || systemctl is-active --quiet proftpd || systemctl is-active --quiet ftp; then
        # ftpusers 파일 경로 확인 (vsftpd, proftpd 등 사용 서비스에 따라 경로가 다를 수 있음)
        ftpusers_file="/etc/ftpusers"

        if [ -f "$ftpusers_file" ]; then
            # root 계정이 ftpusers 파일에 포함되어 있는지 확인
            if grep -q "^root" "$ftpusers_file"; then
                detail+=("양호")
                detail+=("-")
            else
                detail+=("취약")
                detail+=("FTP 접속 시 root 계정으로 직접 접속 할 수 없도록 설정파일 수정 (접속 차단 계정을 등록하는 ftpusers 파일에 root 계정 추가)")
            fi
        else
            detail+=("취약")
            detail+=("ftpusers 파일이 존재하지 않음")
        fi
    else
        detail+=("취약")
        detail+=("FTP 서비스가 활성화되지 않음")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_64" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_64" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_66() {
    # 변수 선언
    local output_mode=$1
    desc="SNMP 서비스 구동 점검"
    detail=()
    total_result="양호"

    detail+=("SNMP 서비스 사용 여부")

    # SNMP 서비스 상태 확인
    if systemctl is-active --quiet snmpd; then
        detail+=("양호")
        detail+=("-")
    else
        detail+=("취약")
        detail+=("SNMP 서비스를 사용하지 않는 경우 서비스 중지 후 시작 스크립트 변경")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_66" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_66" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_61() {
    local output_mode=$1

    # 변수 선언
    desc="FTP 서비스 확인"
    detail=()
    total_result="양호"

    detail+=("FTP 서비스 활성화 여부")

    # FTP 서비스 확인 (vsftpd 혹은 FTP 관련 서비스 확인)
    ftp_service=$(systemctl is-active vsftpd 2>/dev/null || systemctl is-active ftp 2>/dev/null)

    if [[ "$ftp_service" == "inactive" || "$ftp_service" == "unknown" ]]; then
        # FTP 서비스가 활성화되지 않았을 때
        detail+=("양호")
        detail+=("-")
    else
        # FTP 서비스가 활성화되어 있을 때
        detail+=("취약")
        detail+=("FTP 서비스를 비활성화하거나 필요 시 다른 보안된 전송 방법을 사용")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 함수 실행 예시
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_61" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_61" "$desc" "$total_result" "${detail[@]}"
    fi

}

U_63() {
    local output_mode=$1

    # 변수 선언
    desc="ftpusers 파일 소유자 및 권한 설정"
    detail=()
    total_result="양호"

    detail+=("ftpusers 파일 소유자 및 권한 상태")

    # 파일 경로 (주로 /etc/ftpusers 혹은 /etc/vsftpd/ftpusers)
    ftpusers_file="/etc/ftpusers"

    if [ -e "$ftpusers_file" ]; then
        # 파일 소유자 확인
        owner=$(stat -c '%U' "$ftpusers_file")
        # 파일 권한 확인
        permissions=$(stat -c '%a' "$ftpusers_file")

        # 소유자가 root이고 권한이 640 이하인지 확인
        if [[ "$owner" == "root" && "$permissions" -le 640 ]]; then
            detail+=("양호")
            detail+=("-")
        else
            detail+=("취약")
            detail+=("FTP 접근제어 파일의 소유자 및 권한 변경 (소유자 root, 권한 640 이하)")
        fi
    else
        detail+=("취약")
        detail+=("ftpusers 파일이 존재하지 않음. 파일을 생성하고 소유자와 권한을 설정하세요.")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_63" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_63" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_65() {
    local output_mode=$1

    # 변수 선언
    desc="at 서비스 권한 설정"
    detail=()
    total_result="양호"

    detail+=("at 명령어 일반 사용자 사용 여부 및 at 관련 파일 640 이하인지")

    # 관련 파일들
    at_allow_file="/etc/at.allow"
    at_deny_file="/etc/at.deny"

    # at.allow 파일이 존재하고, 권한이 올바른지 확인
    if [ -e "$at_allow_file" ]; then
        allow_owner=$(stat -c '%U' "$at_allow_file")
        allow_permissions=$(stat -c '%a' "$at_allow_file")

        if [[ "$allow_owner" != "root" || "$allow_permissions" -gt 640 ]]; then
            detail+=("취약")
            detail+=("at.allow 파일의 소유자 및 권한 변경 (소유자 root, 권한 640 이하)")
        fi
    fi

    # at.deny 파일이 존재하고, 권한이 올바른지 확인
    if [ -e "$at_deny_file" ]; then
        deny_owner=$(stat -c '%U' "$at_deny_file")
        deny_permissions=$(stat -c '%a' "$at_deny_file")

        if [[ "$deny_owner" != "root" || "$deny_permissions" -gt 640 ]]; then
            detail+=("취약")
            detail+=("at.deny 파일의 소유자 및 권한 변경 (소유자 root, 권한 640 이하)")
        fi
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_65" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_65" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_67() {
    local output_mode=$1

    # 변수 선언
    desc="SNMP 서비스 Community String의 복잡성 설정"
    detail=()
    total_result="양호"

    detail+=("SNMP Community 이름이 public, private 설정")

    # snmpd.conf 파일 위치
    snmp_conf_file="/etc/snmp/snmpd.conf"

    # 커뮤니티 이름 확인 (public/private 여부)
    if grep -qE "community\s+(public|private)" "$snmp_conf_file"  2>/dev/null; then
        detail+=("취약")
        detail+=("snmpd.conf 파일에서 커뮤니티명을 확인한 후 디폴트 커뮤니티명인 “public, private”을 추측하기 어려운 커뮤니티명으로 변경")
    else
        detail+=("양호")
        detail+=("-")
    fi

    # 최종 취약 여부 확인
    if is_in_array "취약" "${detail[@]}"; then
        total_result="취약"
    fi

    # 결과 출력
    if [[ "$output_mode" == "all" ]]; then
        result_print "U_67" "$desc" "$total_result" "${detail[@]}"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_67" "$desc" "$total_result" "${detail[@]}"
    fi
}

U_68(){
    local output_mode=$1
    desc="로그온 시 경고 메시지"
    wirnig="WARNING: UNAUTHORIZED ACCESS TO THIS SYSTEM IS PROHIBITED"
    motd=`cat /etc/motd`
    detail_order="경고메시지가 없습니다"
    if [ "$motd" != "$wirnig" ]; then
        total="취약"
    else
        total1="양호"
    fi

    # FTP 배너 확인
    ftp=$(grep "$waring" /etc/vsftpd/vsftpd.conf 2>/dev/null )
    detail_3="FTP 배너 메시지"
if [ -z "$ftp" ]; then
        total2="취약"
        detail_order="파일이 없습니다"

   elif [ "$ftp" != "$warning" ]; then
        total2="취약"
        detail_order="경고메시지가 없습니다"
    
else
        total2="양호"

    fi

    # SMTP 배너 확인
    smtp=$(grep "$waring" /etc/mail/sendmail.cf  2>/dev/null)
    detail_4="SMTP 배너 메시지"
if [ -z "$smtp" ]; then
        total3="취약"
        detail_order="파일이 없습니다"

    elif [ "$smtp" != "\"$warning\"" ]; then
        total3="취약"
         detail_order="경고메시지가 없습니다"

    else
        total3="양호"

    fi

    # DNS 배너 확인
    dns=$(grep "$warning" /etc/named.conf 2>/dev/null)
    detail_5="DNS 배너 메시지"
if [ -z "$dns" ]; then
        total4="취약"
        detail_order="파일이 없습니다"


    elif [ -z "$dns" ]; then
        total4="취약"
        detail_order="경고메시지가 없습니다"

    else
        total4="양호"

    fi

    if [[ "$output_mode" == "all" ]]; then
        result_print "U_68" "$desc" "$total" "$detail_1" "$total" "$detail_order" "$detail_2"  "$total1" "$detail_order" "$detail_3"  "$total2" "$detail_order" "$detail_4" "$total3" "$detail_order" "$detail_5" "$total4" "$detail_order"
    elif [[ "$output_mode" == "vulnerable" && "$total_result" == "취약" ]]; then
        result_print "U_68" "$desc" "$total" "$detail_1" "$total" "$detail_order" "$detail_2"  "$total1" "$detail_order" "$detail_3"  "$total2" "$detail_order" "$detail_4" "$total3" "$detail_order" "$detail_5" "$total4" "$detail_order"
    fi

}

#############################################################################################

# 메인 함수
main() {
    clear

    # Root 권한 확인
    check_root_user

    # 초기 변수 설정
    local output_mode=""
    local enable_logging=0   # 기본값: 로그 저장 안 함

    # 옵션 파싱
    a_flag=0
    m_flag=0
    while getopts ":am" opt; do
        case $opt in
            a)
                a_flag=1
                ;;
            m)
                m_flag=1
                ;;
            \?)
                echo "잘못된 옵션: -$OPTARG" >&2
                display_usage
                exit 1
                ;;
        esac
    done

    # 파싱된 옵션 뒤의 인자 처리
    shift $((OPTIND -1))

    # 상호 배타적 옵션 처리
    if [ $a_flag -eq 1 ] && [ $m_flag -eq 1 ]; then
        echo "옵션 -a와 -m은 동시에 사용할 수 없습니다." >&2
        display_usage
        exit 1
    elif [ $a_flag -eq 1 ]; then
        output_mode="all"
    elif [ $m_flag -eq 1 ]; then
        output_mode="vulnerable"
    else
        echo "옵션 -a 또는 -m 중 하나를 선택해야 합니다." >&2
        display_usage
        exit 1
    fi

    # 로그 저장 여부 처리
    if [ $# -gt 0 ]; then
        if [[ "$1" == "0" || "$1" == "1" ]]; then
            enable_logging=$1
        else
            echo "잘못된 로그 저장 인자: $1" >&2
            display_usage
            exit 1
        fi
    fi

    # 출력 대상 확인 (exec 이전에 수행)
    if [[ -t 1 ]]; then
        is_tty=1
    else
        is_tty=0
    fi

    # 로그 저장 설정
    if [ "$enable_logging" -eq 1 ]; then
        # 로그 파일 설정
        local log_file="system_check_$(date '+%Y%m%d_%H%M%S').log"
        # 모든 출력과 에러를 로그 파일에 저장하고 화면에도 출력
        exec > >(tee -a "$log_file") 2>&1
        echo "로그가 '$log_file'에 저장됩니다."
    fi

    # 출력 색상 설정 (exec 이후에도 적용)
    if [ "$is_tty" -eq 1 ]; then
        red="\e[31m"
        green="\e[32m"
        yellow="\e[33m"
        reset="\e[0m"  # 색상 초기화
    else
        red=""
        green=""
        yellow=""
        reset=""
    fi

    # 서버 정보 출력
    display_server_info

    # 시스템 점검 시작 메시지
    echo -e "\n${green}${plus_line}${reset}"
    echo -e "${yellow} 시스템 점검을 시작합니다...${reset}"
    echo -e "${green}${plus_line}${reset}\n"

    # 점검 함수 실행 (필요한 함수들을 여기에 추가하세요)
    # check_functions=(U_09 U_10 U_11 U_12 U_13 U_14 U_15 U_16 U_17 U_19 U_20 U_21 U_22 U_23 U_24 U_25 U_50 U_51 U_52 U_53 U_54 U_05 U_06 U_07 U_08 U_18 U_55 U_56 U_57 U_58 U_59 U_42 U_43 U_72 U_01 U_02 U_03 U_04 U_44 U_45 U_46 U_47 U_48 U_49 U_35 U_36 U_37 U_38 U_39 U_40 U_41 U_28 U_27 U_26)

    # for func in "${check_functions[@]}"; do
    #     if declare -f "$func" > /dev/null; then
    #         $func "$output_mode"
    #     else
    #         echo "함수 $func 이(가) 정의되어 있지 않습니다." >&2
    #     fi
    # done

    ## 모든 함수를 다 작성하면 위 코드 주석으로 하고 아래 코드를 주석 해제
    for num in {1..72}; do
        func="U_$(printf "%02d" "$num")"
        if declare -f "$func" > /dev/null; then
            $func "$output_mode"
        else
            echo "함수 $func 이(가) 정의되어 있지 않습니다." >&2
        fi
    done

    # 시스템 점검 완료 메시지
    echo -e "\n${green}${plus_line}${reset}"
    echo -e "${yellow} 시스템 점검이 완료되었습니다.${reset}"
    echo -e "${green}${plus_line}${reset}\n"
}

# 메인 함수 호출
main "$@"
