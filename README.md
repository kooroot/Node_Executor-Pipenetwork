# Node_Executor-Pipenetwork Node Setup(Linux)

이 저장소에는 **리눅스(Ubuntu 계열)** 환경에서 **Pipe Network Node** 설치와 설정을 자동화하는 스크립트(`pipe_network.sh`)가 포함되어 있습니다.

아래 스크립트는 다음 과정을 한 번에 처리합니다:
1. **OS 감지** - Linux 환경을 자동으로 인식
2. **시스템 요구사항 확인** - RAM 및 디스크 공간 확인
3. **의존성 패키지** 설치 (curl, screen)
4. **Pipe Network 바이너리** 다운로드 및 설정
5. **Screen 세션** 생성 및 백그라운드 실행
6. **레퍼럴 코드** 적용 및 상태 확인

---

## 설치 및 실행 방법

1. 스크립트를 다운로드
   ```bash
   wget https://raw.githubusercontent.com/kooroot/Node_Executor-PipeNetwork/main/pipe_network.sh
   ```

2. 실행 권한을 부여
   ```bash
   chmod +x pipe_network.sh
   ```

3. 스크립트를 실행 (대화형 모드)
   ```bash
   ./pipe_network.sh
   ```
   - 실행 중 필요한 설정값을 입력하라는 메시지가 표시됩니다.
   - 설치 과정에서 `sudo` 암호 입력이 필요할 수 있습니다.
   - 램 설정 (엔터), 디스크 설정(엔터), 디렉터리 설정(엔터), 솔라나 주소 설정(필수), 레퍼럴코드(`562376fb35f3a167`) 설정(필수)
   - 총 5가지의 입력이 존재합니다.

4. 노드 작동 확인
   - `screen -r pipe_network` 명령으로 실행 중인 세션 확인
   - 세션에서 빠져나오려면 `Ctrl+A` 누른 후 `D` 키를 누르세요.

첫 실행시 레퍼럴 코드(`562376fb35f3a167`)가 반드시 필요합니다. 첫번째 Node를 실행 후 `./pop --gen-referral-route` 명령어를 통해 레퍼럴 코드를 생성하고 셀퍼럴이 가능합니다.\

---

## 지원 환경 및 하드웨어 요구사항

### 운영 체제
- **Ubuntu** (18.04 LTS 이상 권장) 및 기타 리눅스 배포판

### 하드웨어 요구사항
- **최소 4GB RAM** (8GB 이상 권장)
- **최소 100GB 여유 디스크 공간** (200-500GB 권장)
- **24/7 인터넷 연결**

---

## 설치 세부 과정

1. 운영체제 감지 및 시스템 요구사항 확인
2. 필수 의존성 패키지 설치 (curl, screen)
3. 사용자 입력 받기 (RAM, 디스크, 캐시 디렉토리, Solana 퍼블릭 키, 레퍼럴 코드)
4. Pipe Network 바이너리 다운로드 및 설정
5. Screen 세션 생성 및 Pipe Network 실행

### 주요 설정

- **RAM 용량**: 노드가 사용할 RAM 용량(GB)
- **최대 디스크 사용량**: 노드가 사용할 최대 디스크 공간(GB)
- **캐시 디렉토리**: 캐시 파일이 저장될 디렉토리 경로
- **Solana 퍼블릭 키**: 보상을 받을 Solana 지갑 주소
- **레퍼럴 코드**: 노드 등록 시 사용할 레퍼럴 코드

---

## Screen 세션 관리

- **세션 접속**: `screen -r pipe_network`
- **세션 분리**: `Ctrl+A, D` (세션을 종료하지 않고 빠져나옴)
- **세션 종료**: `screen -S pipe_network -X quit`
- **세션 목록 확인**: `screen -ls`

---

## 포인트 및 레퍼럴 확인

- **포인트 확인**: 
  ```bash
  cd ~/pipe_network && ./pop --points-route
  ```

- **레퍼럴 생성**: 
  ```bash
  cd ~/pipe_network && ./pop --gen-referral-route
  ```

---

## 문제 해결

- **캐시 디렉토리 권한 문제**: 지정한 캐시 디렉토리에 쓰기 권한이 없는 경우, 사용자의 홈 디렉토리 내 디렉토리를 지정하세요.
  
- **레퍼럴 코드 적용 오류**: 서버 오류(500 Internal Server Error)가 발생할 경우 스크립트가 자동으로 최대 5회까지 재시도합니다.

- **세션 실행 실패**: Screen 세션이 생성되지 않은 경우 수동으로 다음 명령을 실행하세요:
  ```bash
  cd ~/pipe_network && sudo ./pop --signup-by-referral-route YOUR_REFERRAL_CODE && sudo ./pop --ram 8 --max-disk 500 --cache-dir /data --pubKey YOUR_SOLANA_PUBKEY
  ```

- **바이너리 실행 오류**: 현재 Pipe Network는 Linux 환경만 공식 지원합니다. 다른 운영체제에서는 실행되지 않을 수 있습니다.

---

## 문의 / 이슈

- **Pipe Network** 자체 문의: [공식 웹사이트](https://www.pipecdn.app/) 또는 커뮤니티
- **스크립트** 관련 문의나 버그 제보: 본 저장소의 [Issues](../../issues) 탭에 등록해주세요.
- 텔레그램 채널: [Telegram 공지방](https://t.me/web3_laborer)
