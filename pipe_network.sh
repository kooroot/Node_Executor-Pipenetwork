#!/bin/bash

# Pipe Network 설치 자동화 스크립트 (Linux/Ubuntu용)

# 색상 코드 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 로그 함수 정의
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 운영체제 확인
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "Linux 운영체제가 감지되었습니다."
    else
        log_error "지원되지 않는 운영체제입니다. Pipe Network는 Linux만 지원합니다."
        exit 1
    fi
}

# 필요한 패키지 설치
install_dependencies() {
    log_info "필요한 의존성 패키지를 설치합니다..."
    
    sudo apt update
    sudo apt install -y curl screen
    
    # screen 설치 확인
    if ! command -v screen &> /dev/null; then
        log_error "screen 설치에 실패했습니다."
        exit 1
    else
        log_success "screen 설치가 완료되었습니다."
    fi
    
    log_success "의존성 패키지 설치가 완료되었습니다."
}

# 시스템 요구사항 확인
check_system_requirements() {
    log_info "시스템 요구사항을 확인합니다..."
    
    # 메모리 확인 (최소 4GB)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ $TOTAL_MEM -lt 4000 ]; then
        log_warning "시스템 메모리가 4GB 미만입니다 ($TOTAL_MEM MB). Pipe Network는 최소 4GB RAM을 권장합니다."
        read -p "$(echo -e "${YELLOW}계속 진행하시겠습니까? (y/n) [n]: ${NC}")" CONTINUE
        CONTINUE=${CONTINUE:-n}
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            log_info "설치를 중단합니다."
            exit 0
        fi
    else
        log_success "메모리 요구사항을 충족합니다: $TOTAL_MEM MB"
    fi
    
    # 디스크 공간 확인 (최소 100GB 권장)
    INSTALL_DIR="$HOME/pipe_network"
    AVAILABLE_SPACE=$(df -BG $HOME | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $AVAILABLE_SPACE -lt 100 ]; then
        log_warning "가용 디스크 공간이 100GB 미만입니다 (약 ${AVAILABLE_SPACE}GB). 최소 100GB, 권장 200-500GB입니다."
        read -p "$(echo -e "${YELLOW}계속 진행하시겠습니까? (y/n) [n]: ${NC}")" CONTINUE
        CONTINUE=${CONTINUE:-n}
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            log_info "설치를 중단합니다."
            exit 0
        fi
    else
        log_success "디스크 공간 요구사항을 충족합니다: 약 ${AVAILABLE_SPACE}GB 사용 가능"
    fi
}

# 사용자 입력 받기
get_user_input() {
    # 기본값 설정
    DEFAULT_RAM=8
    DEFAULT_MAX_DISK=500
    DEFAULT_CACHE_DIR="/data"
    
    # RAM 입력 받기
    read -p "$(echo -e "${BLUE}RAM 용량(GB)을 입력하세요 [기본값: ${DEFAULT_RAM}]: ${NC}")" RAM
    RAM=${RAM:-$DEFAULT_RAM}
    
    # 최대 디스크 용량 입력 받기
    read -p "$(echo -e "${BLUE}최대 디스크 사용량(GB)을 입력하세요 [기본값: ${DEFAULT_MAX_DISK}]: ${NC}")" MAX_DISK
    MAX_DISK=${MAX_DISK:-$DEFAULT_MAX_DISK}
    
    # 캐시 디렉토리 입력 받기
    read -p "$(echo -e "${BLUE}캐시 디렉토리 위치를 입력하세요 [기본값: ${DEFAULT_CACHE_DIR}]: ${NC}")" CACHE_DIR
    CACHE_DIR=${CACHE_DIR:-$DEFAULT_CACHE_DIR}
    
    # Solana 퍼블릭 키 입력 받기 (필수)
    while true; do
        read -p "$(echo -e "${BLUE}Solana 퍼블릭 키를 입력하세요 (필수): ${NC}")" PUBKEY
        if [[ -z "$PUBKEY" ]]; then
            log_error "Solana 퍼블릭 키는 필수 입력값입니다."
        else
            break
        fi
    done
    
    # 레퍼럴 코드 입력 받기 (필수)
    while true; do
        read -p "$(echo -e "${BLUE}레퍼럴 코드를 입력하세요 (필수): ${NC}")" REFERRAL_CODE
        if [[ -z "$REFERRAL_CODE" ]]; then
            log_error "레퍼럴 코드는 필수 입력값입니다."
        else
            break
        fi
    done
}

# Pipe Network 다운로드 및 초기 설정 (screen 실행 전)
download_pipe_network() {
    log_info "Pipe Network 설치를 시작합니다..."
    
    # 작업 디렉토리 생성
    INSTALL_DIR="$HOME/pipe_network"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    log_info "설치 디렉토리: $INSTALL_DIR"
    
    # pop 바이너리 다운로드
    log_info "pop 바이너리를 다운로드합니다..."
    curl -L -o pop "https://dl.pipecdn.app/v0.2.8/pop" || {
        log_error "바이너리 다운로드에 실패했습니다."
        exit 1
    }
    
    # 바이너리 파일 존재 확인
    if [[ ! -f "./pop" ]]; then
        log_error "pop 바이너리 다운로드에 실패했습니다."
        exit 1
    fi
    
    # 실행 권한 부여
    chmod +x pop
    
    # 바이너리 실행 가능 여부 확인
    if ! file ./pop | grep -q "executable"; then
        log_error "다운로드한 바이너리가 실행 가능한 형식이 아닙니다."
        exit 1
    fi
    
    # 다운로드 캐시 디렉토리 생성
    log_info "다운로드 캐시 디렉토리를 생성합니다..."
    mkdir -p download_cache
    
    # 캐시 디렉토리 생성
    if [[ ! -d "$CACHE_DIR" ]]; then
        log_info "캐시 디렉토리가 존재하지 않습니다. 생성을 시도합니다..."
        mkdir -p "$CACHE_DIR" || sudo mkdir -p "$CACHE_DIR" || {
            log_error "캐시 디렉토리 생성에 실패했습니다."
            log_info "다른 캐시 디렉토리를 지정해 주세요."
            exit 1
        }
    fi
    
    # 캐시 디렉토리 권한 확인
    if [[ ! -w "$CACHE_DIR" ]]; then
        log_error "캐시 디렉토리에 쓰기 권한이 없습니다: $CACHE_DIR"
        log_info "권한을 수정하거나 다른 디렉토리를 지정해 주세요."
        exit 1
    fi
    
    log_success "캐시 디렉토리 설정 완료: $CACHE_DIR"
    
    # pop 실행 테스트
    log_info "pop 바이너리 실행 테스트 중..."
    if ! ./pop --help &>/dev/null; then
        log_error "pop 바이너리 실행 테스트에 실패했습니다."
        exit 1
    fi
    log_success "pop 바이너리 실행 테스트 성공!"
    
    # 기존 node_info.json 파일이 있다면 백업
    if [[ -f "node_info.json" ]]; then
        log_info "기존 node_info.json 파일을 백업합니다..."
        mv node_info.json node_info.json.bak
    fi
    
    log_success "Pipe Network 다운로드 및 초기 설정이 완료되었습니다!"
}

# screen 세션 생성 및 Pipe Network 실행
create_screen_and_run() {
    SESSION_NAME="pipe_network"
    
    # 현재 디렉토리 확인
    CURRENT_DIR=$(pwd)
    log_info "현재 디렉토리: $CURRENT_DIR"
    
    # 이미 존재하는 screen 세션 확인 및 종료
    if screen -list | grep -q "$SESSION_NAME"; then
        log_warning "이미 '$SESSION_NAME' 세션이 존재합니다. 기존 세션을 종료합니다."
        screen -S "$SESSION_NAME" -X quit
        sleep 2
    fi
    
    log_info "새로운 screen 세션을 생성합니다..."
    
    # 단계별 실행을 위한 스크립트 생성
    STEP_SCRIPT="$CURRENT_DIR/pipe_network_steps.sh"
    
    cat > "$STEP_SCRIPT" << EOF
#!/bin/bash

# 색상 코드 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\${BLUE}[INFO]\${NC} Pipe Network 단계별 설치를 시작합니다..."
cd $CURRENT_DIR

# 레퍼럴 코드 사용 함수 (재시도 로직 포함)
apply_referral_code() {
    local max_attempts=5
    local attempt=1
    local success=false
    local output=""
    
    while [ \$attempt -le \$max_attempts ] && [ "\$success" != "true" ]; do
        echo -e "\${BLUE}[INFO]\${NC} 레퍼럴 코드 적용 시도 (\$attempt/\$max_attempts): $REFERRAL_CODE"
        
        # 명령 실행 및 출력 캡처
        output=\$(sudo ./pop --signup-by-referral-route "$REFERRAL_CODE" 2>&1)
        echo "\$output"
        
        # 성공 여부 확인 (200 OK가 있는지)
        if echo "\$output" | grep -q "status=200 OK"; then
            echo -e "\${GREEN}[SUCCESS]\${NC} 레퍼럴 코드 적용 성공! (200 OK)"
            success=true
        else
            # 500 에러 확인
            if echo "\$output" | grep -q "status=500"; then
                echo -e "\${YELLOW}[WARNING]\${NC} 서버 오류 발생 (500 Internal Server Error). 재시도 중..."
                sleep 3
            else
                # 기타 오류
                echo -e "\${RED}[ERROR]\${NC} 레퍼럴 코드 적용 실패. 오류 메시지 확인 후 재시도 중..."
                sleep 3
            fi
            attempt=\$((attempt+1))
        fi
    done
    
    # 최종 성공 여부 반환
    if [ "\$success" = "true" ]; then
        return 0
    else
        echo -e "\${RED}[ERROR]\${NC} \$max_attempts회 시도 후에도 레퍼럴 코드 적용에 실패했습니다."
        return 1
    fi
}

# 1단계: 레퍼럴 코드 사용
echo -e "\${BLUE}[INFO]\${NC} 1단계: 레퍼럴 코드를 사용합니다: $REFERRAL_CODE"
apply_referral_code
STEP1_STATUS=\$?

if [ \$STEP1_STATUS -eq 0 ]; then
    # 2단계: 주요 설정 적용
    echo -e "\${BLUE}[INFO]\${NC} 2단계: Pipe Network 설정을 적용합니다..."
    echo -e "\${BLUE}[INFO]\${NC} 설정: RAM=${RAM}GB, 디스크=${MAX_DISK}GB, 캐시=${CACHE_DIR}, 퍼블릭키=${PUBKEY}"
    sudo ./pop --ram "$RAM" --max-disk "$MAX_DISK" --cache-dir "$CACHE_DIR" --pubKey "$PUBKEY"
    STEP2_STATUS=\$?
    
    if [ \$STEP2_STATUS -eq 0 ]; then
        echo -e "\${GREEN}[SUCCESS]\${NC} 설정 적용 성공!"
        
        # 3단계: 상태 확인
        echo -e "\${BLUE}[INFO]\${NC} 3단계: Pipe Network 상태를 확인합니다..."
        ./pop --status
        echo -e "\${GREEN}[SUCCESS]\${NC} Pipe Network 설치 및 설정이 완료되었습니다!"
        
        # 4단계: 계속 실행
        echo -e "\${BLUE}[INFO]\${NC} Pipe Network가 백그라운드에서 실행 중입니다. 이 세션을 유지하세요."
        echo -e "\${BLUE}[INFO]\${NC} 세션에서 나가려면 Ctrl+A 누른 후 D 키를 누르세요."
        sudo ./pop
    else
        echo -e "\${RED}[ERROR]\${NC} 설정 적용에 실패했습니다."
        exit 1
    fi
else
    echo -e "\${RED}[ERROR]\${NC} 최대 시도 횟수 초과 후에도 레퍼럴 코드 적용에 실패했습니다."
    exit 1
fi

# 스크립트 종료 시 bash 쉘 실행
exec bash
EOF
    
    # 스크립트에 실행 권한 부여
    chmod +x "$STEP_SCRIPT"
    
    # screen 세션 생성 및 스크립트 실행
    log_info "screen 세션에서 단계별 설치 스크립트를 실행합니다..."
    screen -dmS "$SESSION_NAME" "$STEP_SCRIPT"
    sleep 3
    
    # 세션이 정상적으로 생성됐는지 확인
    if screen -list | grep -q "$SESSION_NAME"; then
        log_success "screen 세션 '$SESSION_NAME'이(가) 성공적으로 생성되었습니다."
        log_info "현재 실행 중인 screen 세션 목록:"
        screen -list
    else
        log_error "screen 세션 생성에 실패했습니다."
        log_info "수동으로 다음 명령을 실행하여 Pipe Network를 시작할 수 있습니다:"
        log_info "cd $CURRENT_DIR && $STEP_SCRIPT"
        return 1
    fi
    
    log_success "Pipe Network가 screen 세션('$SESSION_NAME')에서 단계별로 실행 중입니다."
    log_info "세션에 접속하려면: screen -r $SESSION_NAME"
    log_info "세션에서 빠져나오려면: Ctrl+A 누른 후 D 키를 누르세요."
    log_info "screen 세션을 종료하려면: screen -S $SESSION_NAME -X quit"
    
    return 0
}

# 도움말 표시
show_help() {
    echo -e "${BLUE}Pipe Network 설치 자동화 스크립트 사용법 (Linux 전용)${NC}"
    echo ""
    echo "기본 실행 (대화형 모드):"
    echo "  ./pipe_network_setup.sh"
    echo ""
    echo "인자 설명:"
    echo "  --ram <값>              : RAM 용량(GB) 설정 (기본값: 8)"
    echo "  --max-disk <값>         : 최대 디스크 사용량(GB) 설정 (기본값: 500)"
    echo "  --cache-dir <경로>      : 캐시 디렉토리 위치 설정 (기본값: /data)"
    echo "  --pubkey <키>           : Solana 퍼블릭 키 설정 (필수)"
    echo "  --referral <코드>       : 레퍼럴 코드 설정 (필수)"
    echo "  --help                  : 도움말 표시"
    echo ""
    echo "예시:"
    echo "  ./pipe_network_setup.sh --ram 16 --max-disk 1000 --cache-dir /mnt/data --pubkey YOUR_PUBKEY --referral REFERRAL_CODE"
    echo ""
    echo "시스템 요구사항:"
    echo "  - Linux 운영체제"
    echo "  - 최소 4GB RAM (권장: 8GB 이상)"
    echo "  - 최소 100GB 여유 디스크 공간 (권장: 200-500GB)"
    echo "  - 24/7 인터넷 연결"
    echo ""
}

# 명령줄 인자 파싱
parse_arguments() {
    # 기본값 설정
    RAM=8
    MAX_DISK=500
    CACHE_DIR="/data"
    PUBKEY=""
    REFERRAL_CODE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ram)
                RAM="$2"
                shift 2
                ;;
            --max-disk)
                MAX_DISK="$2"
                shift 2
                ;;
            --cache-dir)
                CACHE_DIR="$2"
                shift 2
                ;;
            --pubkey)
                PUBKEY="$2"
                shift 2
                ;;
            --referral)
                REFERRAL_CODE="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 필수 인자 확인
    if [[ -z "$PUBKEY" ]]; then
        log_error "Solana 퍼블릭 키(--pubkey)는 필수 입력값입니다."
        show_help
        exit 1
    fi
    
    if [[ -z "$REFERRAL_CODE" ]]; then
        log_error "레퍼럴 코드(--referral)는 필수 입력값입니다."
        show_help
        exit 1
    fi
}

# 메인 함수
main() {
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Pipe Network 설치 자동화 스크립트 (Linux)  ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    
    # 운영체제 감지
    detect_os
    
    # 시스템 요구사항 확인
    check_system_requirements
    
    # 의존성 패키지 설치
    install_dependencies
    
    # 인자가 없으면 대화형 모드로 실행
    if [[ $# -eq 0 ]]; then
        get_user_input
    else
        parse_arguments "$@"
    fi
    
    # Pipe Network 다운로드 및 초기 설정
    download_pipe_network
    
    # screen 세션 생성 후 Pipe Network 실행
    create_screen_and_run
    
    # 마무리 메시지
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}    설치가 성공적으로 완료되었습니다    ${NC}"
    echo -e "${BLUE}    screen 세션명: pipe_network    ${NC}"
    echo -e "${BLUE}    접속 명령어: screen -r pipe_network    ${NC}"
    echo -e "${GREEN}=========================================${NC}"
}

# 스크립트 실행
main "$@"
