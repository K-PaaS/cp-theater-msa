#!/bin/bash

# Theater MSA - 전체 클러스터 통합 배포 스크립트
# CTX1(NaverCloud) + CTX2(NHN Cloud) 멀티클라우드 배포

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수들
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 컨텍스트 존재 확인
check_contexts() {
    log_info "클러스터 컨텍스트 확인 중..."
    
    if ! kubectl config get-contexts ctx1 >/dev/null 2>&1; then
        log_error "ctx1 컨텍스트를 찾을 수 없습니다."
        log_info "다음 명령어로 컨텍스트를 설정하세요:"
        echo "  kubectl config rename-context <your-ctx1-context> ctx1"
        exit 1
    fi
    
    if ! kubectl config get-contexts ctx2 >/dev/null 2>&1; then
        log_error "ctx2 컨텍스트를 찾을 수 없습니다."
        log_info "다음 명령어로 컨텍스트를 설정하세요:"
        echo "  kubectl config rename-context <your-ctx2-context> ctx2"
        exit 1
    fi
    
    log_success "CTX1, CTX2 컨텍스트 확인 완료"
}

# 노드 라벨 확인
check_node_labels() {
    log_info "각 클러스터 노드 라벨 확인 중..."
    
    # CTX1 노드 확인
    local ctx1_nodes=$(kubectl get nodes -l cluster-name=ctx1 --context=ctx1 --no-headers 2>/dev/null | wc -l)
    if [ $ctx1_nodes -eq 0 ]; then
        log_error "CTX1에 cluster-name=ctx1 라벨이 설정된 노드를 찾을 수 없습니다."
        log_info "CTX1 노드 라벨링 명령어:"
        kubectl get nodes --context=ctx1 --no-headers | awk '{print "kubectl label nodes " $1 " cluster-name=ctx1 --context=ctx1"}'
        exit 1
    fi
    
    # CTX2 노드 확인
    local ctx2_nodes=$(kubectl get nodes -l cluster-name=ctx2 --context=ctx2 --no-headers 2>/dev/null | wc -l)
    if [ $ctx2_nodes -eq 0 ]; then
        log_error "CTX2에 cluster-name=ctx2 라벨이 설정된 노드를 찾을 수 없습니다."
        log_info "CTX2 노드 라벨링 명령어:"
        kubectl get nodes --context=ctx2 --no-headers | awk '{print "kubectl label nodes " $1 " cluster-name=ctx2 --context=ctx2"}'
        exit 1
    fi
    
    log_success "CTX1: $ctx1_nodes개 노드, CTX2: $ctx2_nodes개 노드 확인"
}

# DOMAIN 설정 확인
setup_domain() {
    if [ -z "$DOMAIN" ]; then
        log_warning "DOMAIN 환경변수가 설정되지 않았습니다."
        read -p "DOMAIN을 입력하세요 (예: 27.96.156.180.nip.io): " DOMAIN
        export DOMAIN
    fi
    
    log_info "사용할 도메인: $DOMAIN"
    log_info "Theater MSA URL: https://theater.$DOMAIN"
    
    # update-deployment-images.sh 실행 여부 확인
    log_warning "Harbor Registry 이미지 태그 업데이트를 실행하시겠습니까?"
    read -p "이미지 태그를 $DOMAIN으로 업데이트? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        log_info "이미지 태그 업데이트 중..."
        ./update-deployment-images.sh $DOMAIN
        log_success "이미지 태그 업데이트 완료"
    fi
}

# 배포 순서 안내
show_deployment_plan() {
    log_step "=== 멀티클라우드 배포 계획 ==="
    echo
    echo "📋 배포 순서:"
    echo "  1️⃣  CTX1 (NaverCloud Platform)"
    echo "      - User Service (CTX1 전용) + API Gateway"
    echo "      - Movie Service (CTX1 전용)"
    echo "      - Booking Service (CTX1 전용)"
    echo "      - Redis Service (멀티클러스터 접근)"
    echo "      - Istio 트래픽 관리"
    echo "      - 외부 접근 Gateway"
    echo
    echo "  2️⃣  CTX2 (NHN Cloud NKS)"
    echo "      - User Service (CTX2 전용)"
    echo "      - Movie Service (CTX2 전용)"
    echo "      - Booking Service (CTX2 전용)"
    echo "      - Istio 트래픽 관리"
    echo "      - Redis 실제 배포 + 멀티클러스터 연결"
    echo
    echo "  3️⃣  검증 및 테스트"
    echo "      - 서비스 상태 확인"
    echo "      - 트래픽 분산 테스트"
    echo "      - 멀티클러스터 통신 확인"
    echo
}

# CTX1 배포
deploy_ctx1() {
    log_step "1️⃣ CTX1 클러스터 배포 시작"
    echo "================================================"
    
    if [ -x "deploy-ctx1.sh" ]; then
        ./deploy-ctx1.sh
    else
        log_error "deploy-ctx1.sh 스크립트를 찾을 수 없거나 실행 권한이 없습니다."
        exit 1
    fi
    
    log_success "CTX1 배포 완료"
}

# CTX2 배포
deploy_ctx2() {
    log_step "2️⃣ CTX2 클러스터 배포 시작"
    echo "================================================"
    
    if [ -x "deploy-ctx2.sh" ]; then
        ./deploy-ctx2.sh
    else
        log_error "deploy-ctx2.sh 스크립트를 찾을 수 없거나 실행 권한이 없습니다."
        exit 1
    fi
    
    log_success "CTX2 배포 완료"
}

# 멀티클러스터 검증
verify_multicluster_deployment() {
    log_step "3️⃣ 멀티클러스터 배포 검증"
    echo "================================================"
    
    # CTX1 상태 확인
    log_info "CTX1 클러스터 상태:"
    kubectl get pods -n theater-msa -o wide --context=ctx1
    
    echo
    
    # CTX2 상태 확인
    log_info "CTX2 클러스터 상태:"
    kubectl get pods -n theater-msa -o wide --context=ctx2
    
    echo
    
    # VirtualService 트래픽 분산 확인
    log_info "트래픽 분산 설정:"
    echo "CTX1:"
    kubectl get vs -n theater-msa --context=ctx1 -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[-1].route[*].weight 2>/dev/null || true
    echo "CTX2:"
    kubectl get vs -n theater-msa --context=ctx2 -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[-1].route[*].weight 2>/dev/null || true
    
    echo
    
    # 외부 접근 확인
    log_info "외부 접근 VirtualService 확인:"
    kubectl get vs -n istio-system theater-msa --context=ctx1 -o wide 2>/dev/null || log_warning "외부 VirtualService를 찾을 수 없습니다."
}

# 접근 정보 및 테스트 가이드
show_final_info() {
    log_step "🎉 멀티클라우드 배포 완료!"
    echo "================================================"
    
    echo "🌐 접근 정보:"
    echo "  Theater MSA: https://theater.$DOMAIN"
    echo "  API 엔드포인트:"
    echo "    - 사용자: https://theater.$DOMAIN/users/"
    echo "    - 영화: https://theater.$DOMAIN/movies/"
    echo "    - 예약: https://theater.$DOMAIN/bookings/"
    
    echo
    echo "🧪 트래픽 분산 테스트:"
    echo "  # 일반 요청 (가중치 분산)"
    echo "  curl -k https://theater.$DOMAIN/users/"
    echo "  curl -k https://theater.$DOMAIN/movies/"
    echo "  curl -k https://theater.$DOMAIN/bookings/"
    echo
    echo "  # 카나리 배포 테스트"
    echo "  curl -k -H 'x-canary: true' https://theater.$DOMAIN/users/"
    echo
    echo "  # 연속 요청으로 분산 확인"
    echo "  for i in {1..10}; do curl -k -s https://theater.$DOMAIN/users/ | head -1; done"
    
    echo
    echo "📊 모니터링 명령어:"
    echo "  # 각 클러스터 Pod 상태"
    echo "  kubectl get pods -n theater-msa --context=ctx1 -o wide"
    echo "  kubectl get pods -n theater-msa --context=ctx2 -o wide"
    echo
    echo "  # Istio 트래픽 분산 상태"
    echo "  kubectl get vs,dr -n theater-msa --context=ctx1"
    echo "  kubectl get vs,dr -n theater-msa --context=ctx2"
    echo
    echo "  # 멀티클러스터 엔드포인트"
    echo "  istioctl proxy-config endpoints deployment/user-service.theater-msa --context=ctx1"
    
    echo
    echo "🔧 트래픽 비율 조정 예시:"
    echo "  # User Service 트래픽을 90:10으로 변경"
    echo "  kubectl patch vs user-service-vs -n theater-msa --context=ctx1 --type='merge' -p='"
    echo "  {"
    echo "    \"spec\": {"
    echo "      \"http\": [{"
    echo "        \"route\": ["
    echo "          {\"destination\": {\"host\": \"user-service\", \"subset\": \"ctx1\"}, \"weight\": 90},"
    echo "          {\"destination\": {\"host\": \"user-service\", \"subset\": \"ctx2\"}, \"weight\": 10}"
    echo "        ]"
    echo "      }]"
    echo "    }"
    echo "  }'"
    
    echo
    echo "🆘 문제 해결:"
    echo "  # Pod 상세 정보"
    echo "  kubectl describe pod <pod-name> -n theater-msa --context=<ctx1|ctx2>"
    echo
    echo "  # 로그 확인"
    echo "  kubectl logs -l app=<service-name> -n theater-msa --context=<ctx1|ctx2>"
    echo
    echo "  # 정리 (필요시)"
    echo "  ./cleanup.sh --all"
}

# 메인 함수
main() {
    log_info "Theater MSA - 멀티클라우드 통합 배포 스크립트"
    echo "====================================================="
    log_info "CTX1 (NaverCloud) + CTX2 (NHN Cloud) Istio 서비스메시 배포"
    echo
    
    # 사전 확인
    check_contexts
    check_node_labels
    setup_domain
    
    echo
    
    # 배포 계획 표시
    show_deployment_plan
    
    # 배포 확인
    log_warning "멀티클라우드 Theater MSA를 배포하시겠습니까?"
    read -p "계속하려면 'y'를 입력하세요 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 취소되었습니다."
        exit 0
    fi
    
    echo
    
    # 순차 배포 실행
    deploy_ctx1
    
    echo
    log_info "CTX1 배포 완료. CTX2 배포를 시작합니다..."
    sleep 5
    
    deploy_ctx2
    
    echo
    log_info "두 클러스터 배포 완료. 검증을 시작합니다..."
    sleep 5
    
    verify_multicluster_deployment
    
    echo
    
    # 최종 정보 표시
    show_final_info
    
    echo
    log_success "🎉 멀티클라우드 Istio 서비스메시 배포 완료!"
    log_info "이제 NaverCloud와 NHN Cloud 간 투명한 서비스 통신이 가능합니다."
}

# 도움말
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "멀티클라우드 통합 배포 스크립트"
    echo
    echo "사용법: $0"
    echo
    echo "환경변수:"
    echo "  DOMAIN    Harbor Registry 도메인 (예: 27.96.156.180.nip.io)"
    echo
    echo "사전 요구사항:"
    echo "  - kubectl 컨텍스트 'ctx1', 'ctx2' 설정"
    echo "  - 각 클러스터 노드에 'cluster-name=ctx1/ctx2' 라벨 설정"
    echo "  - Istio와 EASTWESTGATEWAY 사전 구성"
    echo "  - Harbor Registry에 이미지 업로드 완료"
    echo
    echo "배포 구조:"
    echo "  CTX1 (NaverCloud):"
    echo "    - User Service (CTX1 전용) + API Gateway"
    echo "    - Movie Service (CTX1 전용)"
    echo "    - Booking Service (CTX1 전용)"
    echo "    - Redis Service (멀티클러스터 접근)"
    echo "    - 외부 접근 Gateway"
    echo
    echo "  CTX2 (NHN Cloud):"
    echo "    - User Service (CTX2 전용)"
    echo "    - Movie Service (CTX2 전용)"
    echo "    - Booking Service (CTX2 전용)"
    echo "    - Redis 실제 배포 + 멀티클러스터 서비스 디스커버리"
    echo
    echo "관련 스크립트:"
    echo "  ./deploy-ctx1.sh     CTX1만 배포"
    echo "  ./deploy-ctx2.sh     CTX2만 배포"
    echo "  ./cleanup.sh --all   전체 정리"
    exit 0
fi

# 스크립트 실행
main "$@"