#!/bin/bash

# Theater MSA - CTX2 클러스터 배포 스크립트
# NHN Cloud NKS 클러스터용 (Movie Service + Booking Service)

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 현재 컨텍스트 확인
check_context() {
    local current_context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    if [ "$current_context" != "ctx2" ]; then
        log_warning "현재 컨텍스트가 ctx2가 아닙니다: $current_context"
        log_info "ctx2 컨텍스트로 전환합니다..."
        kubectl config use-context ctx2
        if [ $? -ne 0 ]; then
            log_error "ctx2 컨텍스트로 전환할 수 없습니다. 컨텍스트가 설정되어 있는지 확인하세요."
            exit 1
        fi
    fi
    log_success "CTX2 컨텍스트 확인 완료"
}

# 노드 라벨 확인
check_node_labels() {
    log_info "노드 라벨 확인 중..."
    local ctx2_nodes=$(kubectl get nodes -l cluster-name=ctx2 --no-headers | wc -l)
    if [ $ctx2_nodes -eq 0 ]; then
        log_error "cluster-name=ctx2 라벨이 설정된 노드를 찾을 수 없습니다."
        log_info "다음 명령어로 노드에 라벨을 설정하세요:"
        kubectl get nodes --no-headers | awk '{print "kubectl label nodes " $1 " cluster-name=ctx2"}'
        exit 1
    fi
    log_success "CTX2 노드 $ctx2_nodes개 확인됨"
}

# 이미지 확인
check_images() {
    log_info "Harbor 이미지 접근성 확인 중..."
    
    # DOMAIN 환경변수 확인
    if [ -z "$DOMAIN" ]; then
        log_warning "DOMAIN 환경변수가 설정되지 않았습니다."
        read -p "DOMAIN을 입력하세요 (예: 27.96.156.180.nip.io): " DOMAIN
        export DOMAIN
    fi
    
    log_info "사용할 도메인: $DOMAIN"
    log_info "Harbor Registry: harbor.$DOMAIN"
    
    # 이미지 존재 여부는 배포 시 확인되므로 여기서는 경고만 표시
    log_warning "배포 전 다음 명령어로 이미지를 빌드했는지 확인하세요:"
    echo "  ./build-images.sh $DOMAIN"
}

# CTX2 전용 리소스 배포
deploy_ctx2_resources() {
    log_info "=== CTX2 클러스터 리소스 배포 시작 ==="
    
    # 1. 기본 네임스페이스 및 권한 설정
    log_info "1. 기본 네임스페이스 및 권한 설정..."
    kubectl apply -f namespace.yaml
    kubectl apply -f rbac.yaml
    
    # 2. Redis (공유 - preferredAffinity로 배치, 실제로는 ctx1에 있을 것)
    log_info "2. Redis 배포 (공유 서비스)..."
    kubectl apply -f redis.yaml
    
    # 3. User Service (CTX2 전용)
    log_info "3. User Service 배포..."
    kubectl apply -f user-service-ctx2.yaml
    
    # 4. Movie Service (CTX2 전용)
    log_info "4. Movie Service 배포..."
    kubectl apply -f movie-service-ctx2.yaml
    
    # 5. Booking Service (CTX2 전용)
    log_info "5. Booking Service 배포..."
    kubectl apply -f booking-service-ctx2.yaml
    
    # 6. Istio 트래픽 관리 (DestinationRule & VirtualService)
    log_info "6. Istio DestinationRule 배포..."
    kubectl apply -f istio-destinationrules.yaml
    
    log_info "7. Istio VirtualService 배포..."
    kubectl apply -f istio-virtualservices.yaml
    
    log_success "CTX2 리소스 배포 완료!"
    
    log_info "참고: API Gateway와 외부 VirtualService는 CTX1에서만 배포됩니다."
}

# 배포 상태 확인
check_deployment_status() {
    log_info "=== 배포 상태 확인 ==="
    
    # Pod 상태 확인
    log_info "Pod 상태 확인 중..."
    kubectl get pods -n theater-msa -o wide
    
    echo
    
    # 서비스 확인
    log_info "서비스 확인 중..."
    kubectl get svc -n theater-msa
    
    echo
    
    # Istio 리소스 확인
    log_info "Istio 리소스 확인 중..."
    kubectl get destinationrules,virtualservices -n theater-msa
    
    echo
    
    # 사이드카 주입 확인
    log_info "Istio 사이드카 주입 확인..."
    kubectl get pods -n theater-msa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | column -t
    
    echo
    
    # 실패한 Pod 확인
    local failed_pods=$(kubectl get pods -n theater-msa --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ $failed_pods -gt 0 ]; then
        log_warning "실패한 Pod가 있습니다:"
        kubectl get pods -n theater-msa --field-selector=status.phase!=Running
        
        echo
        log_info "문제 해결을 위해 다음 명령어를 실행하세요:"
        echo "  kubectl describe pod <pod-name> -n theater-msa"
        echo "  kubectl logs <pod-name> -n theater-msa"
    else
        log_success "모든 Pod가 정상 실행 중입니다!"
    fi
}

# 클러스터 간 연결 확인
check_multicluster_connectivity() {
    log_info "=== 멀티클러스터 연결 확인 ==="
    
    # EASTWESTGATEWAY 확인
    log_info "EASTWESTGATEWAY 상태 확인..."
    kubectl get svc istio-eastwestgateway -n istio-system 2>/dev/null || log_warning "EASTWESTGATEWAY를 찾을 수 없습니다."
    
    echo
    
    # 서비스 엔드포인트 확인 (멀티클러스터 디스커버리)
    log_info "멀티클러스터 서비스 엔드포인트 확인..."
    if kubectl get pods -n theater-msa -l app=user-service --no-headers | head -1 >/dev/null 2>&1; then
        local test_pod=$(kubectl get pods -n theater-msa -l app=user-service --no-headers | head -1 | awk '{print $1}')
        if [ -n "$test_pod" ]; then
            log_info "User Service Pod에서 멀티클러스터 엔드포인트 확인:"
            kubectl exec $test_pod -n theater-msa -c user-service -- nslookup user-service.theater-msa.svc.cluster.local 2>/dev/null || log_warning "DNS 조회 실패"
        fi
    fi
    
    echo
    
    # VirtualService 트래픽 분산 설정 확인
    log_info "VirtualService 트래픽 분산 설정:"
    kubectl get vs -n theater-msa -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[-1].route[*].weight 2>/dev/null || log_warning "VirtualService 정보를 가져올 수 없습니다."
}

# CTX2 특화 정보 표시
show_ctx2_info() {
    log_info "=== CTX2 클러스터 정보 ==="
    
    echo "🎭 CTX2 주요 서비스:"
    echo "  - Movie Service (CTX2 전용 - VirtualService로 트래픽 분산)"
    echo "  - Booking Service (CTX2 전용 - VirtualService로 트래픽 분산)"
    echo "  - User Service (CTX2 전용 - VirtualService로 트래픽 분산)"
    
    echo
    echo "📊 트래픽 분산 (VirtualService 설정):"
    echo "  eastwest-gateway를 통한 크로스 클러스터 트래픽 분산"
    echo "  실제 비율은 VirtualService 설정에 따라 동적 조정"
    
    echo
    echo "🔍 모니터링 명령어:"
    echo "  kubectl get pods -n theater-msa -l cluster=ctx2"
    echo "  kubectl logs -l app=movie-service -n theater-msa"
    echo "  kubectl top pods -n theater-msa"
    
    echo
    echo "🌐 외부 접근:"
    echo "  CTX1의 API Gateway를 통해 접근"
    if [ -n "$DOMAIN" ]; then
        echo "  https://theater.$DOMAIN"
    fi
}

# 메인 함수
main() {
    log_info "Theater MSA - CTX2 클러스터 배포 스크립트"
    echo "=================================================="
    log_info "CTX2 배포 구성: Movie Service + Booking Service + 공유 서비스"
    echo
    
    # 사전 확인
    check_context
    check_node_labels
    check_images
    
    echo
    
    # 배포 확인
    log_warning "CTX2 클러스터에 Theater MSA를 배포하시겠습니까?"
    read -p "계속하려면 'y'를 입력하세요 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 취소되었습니다."
        exit 0
    fi
    
    # 배포 실행
    deploy_ctx2_resources
    
    echo
    
    # 배포 완료 대기
    log_info "Pod 시작 대기 중... (30초)"
    sleep 30
    
    # 상태 확인
    check_deployment_status
    
    echo
    
    # 멀티클러스터 연결 확인
    check_multicluster_connectivity
    
    echo
    
    # CTX2 정보 표시
    show_ctx2_info
    
    echo
    log_success "=== CTX2 배포 완료 ==="
    log_info "이제 두 클러스터 간 Istio 멀티클라우드 서비스메시가 구성되었습니다!"
    
    echo
    log_info "전체 시스템 확인을 위해 다음 명령어를 실행하세요:"
    echo "  ./check-multicluster.sh  # (생성 예정)"
}

# 도움말
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "CTX2 클러스터 배포 스크립트"
    echo
    echo "사용법: $0"
    echo
    echo "환경변수:"
    echo "  DOMAIN    Harbor Registry 도메인 (예: 27.96.156.180.nip.io)"
    echo
    echo "사전 요구사항:"
    echo "  - kubectl 컨텍스트 'ctx2' 설정"
    echo "  - 노드에 'cluster-name=ctx2' 라벨 설정"
    echo "  - Harbor Registry에 이미지 업로드 완료"
    echo "  - CTX1 클러스터 배포 완료 권장"
    echo
    echo "배포되는 서비스:"
    echo "  - User Service (CTX2 전용)"
    echo "  - Movie Service (CTX2 전용)"
    echo "  - Booking Service (CTX2 전용)"
    echo "  - Redis (공유)"
    echo "  - Istio DestinationRule & VirtualService"
    echo
    echo "주의사항:"
    echo "  - API Gateway는 CTX1에서만 배포됩니다"
    echo "  - EASTWESTGATEWAY가 사전 구성되어 있어야 합니다"
    exit 0
fi

# 스크립트 실행
main "$@"