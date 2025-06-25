#!/bin/bash

# Theater MSA 샘플 배포 일괄 삭제 스크립트
# Usage: ./cleanup.sh [--all|--ctx1|--ctx2]
# Options:
#   --all: 모든 클러스터에서 삭제 (ctx1, ctx2) - 기본값
#   --ctx1: CTX1 클러스터에서만 삭제
#   --ctx2: CTX2 클러스터에서만 삭제
#   --current: 현재 컨텍스트에서만 삭제

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
get_current_context() {
    kubectl config current-context 2>/dev/null || echo "unknown"
}

# 네임스페이스 존재 확인
namespace_exists() {
    local context=$1
    kubectl get namespace theater-msa --context=$context >/dev/null 2>&1
}

# 리소스 존재 확인
check_resources() {
    local context=$1
    local has_resources=false
    
    log_info "컨텍스트 $context에서 리소스 확인 중..."
    
    if ! namespace_exists $context; then
        log_warning "네임스페이스 theater-msa가 존재하지 않습니다."
        return 1
    fi
    
    # Pod 확인
    local pods=$(kubectl get pods -n theater-msa --context=$context --no-headers 2>/dev/null | wc -l)
    if [ $pods -gt 0 ]; then
        log_info "발견된 Pod: $pods개"
        has_resources=true
    fi
    
    # 서비스 확인
    local services=$(kubectl get services -n theater-msa --context=$context --no-headers 2>/dev/null | wc -l)
    if [ $services -gt 0 ]; then
        log_info "발견된 Service: $services개"
        has_resources=true
    fi
    
    # DestinationRule 확인
    local drs=$(kubectl get destinationrules -n theater-msa --context=$context --no-headers 2>/dev/null | wc -l)
    if [ $drs -gt 0 ]; then
        log_info "발견된 DestinationRule: $drs개"
        has_resources=true
    fi
    
    # VirtualService 확인
    local vss=$(kubectl get virtualservices -n theater-msa --context=$context --no-headers 2>/dev/null | wc -l)
    if [ $vss -gt 0 ]; then
        log_info "발견된 VirtualService: $vss개"
        has_resources=true
    fi
    
    # 외부 VirtualService 확인 (istio-system)
    local external_vs=$(kubectl get virtualservices -n istio-system theater-msa --context=$context --no-headers 2>/dev/null | wc -l)
    if [ $external_vs -gt 0 ]; then
        log_info "발견된 외부 VirtualService: $external_vs개"
        has_resources=true
    fi
    
    if [ "$has_resources" = true ]; then
        return 0
    else
        log_info "삭제할 리소스가 없습니다."
        return 1
    fi
}

# 단일 컨텍스트에서 리소스 삭제
cleanup_context() {
    local context=$1
    
    log_info "=== 컨텍스트 $context에서 리소스 삭제 시작 ==="
    
    # 리소스 존재 확인
    if ! check_resources $context; then
        return 0
    fi
    
    # 확인 메시지
    echo
    log_warning "다음 컨텍스트에서 Theater MSA 리소스를 삭제합니다: $context"
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "삭제가 취소되었습니다."
        return 0
    fi
    
    # Kustomize를 사용한 일괄 삭제 시도
    log_info "Kustomize를 사용한 일괄 삭제 시도 중..."
    if kubectl delete -k . --context=$context --ignore-not-found=true >/dev/null 2>&1; then
        log_success "Kustomize를 통한 일괄 삭제 완료"
    else
        log_warning "Kustomize 삭제 실패, 개별 리소스 삭제로 전환"
        
        # 개별 리소스 삭제
        log_info "개별 리소스 삭제 중..."
        
        # 외부 VirtualService 삭제 (istio-system)
        kubectl delete virtualservice theater-msa -n istio-system --context=$context --ignore-not-found=true
        
        # VirtualService 삭제
        kubectl delete virtualservices --all -n theater-msa --context=$context --ignore-not-found=true
        
        # DestinationRule 삭제
        kubectl delete destinationrules --all -n theater-msa --context=$context --ignore-not-found=true
        
        # Deployment 삭제
        kubectl delete deployments --all -n theater-msa --context=$context --ignore-not-found=true
        
        # Service 삭제
        kubectl delete services --all -n theater-msa --context=$context --ignore-not-found=true
        
        # ConfigMap 삭제
        kubectl delete configmaps --all -n theater-msa --context=$context --ignore-not-found=true
        
        # ServiceAccount 및 RBAC 삭제
        kubectl delete serviceaccounts --all -n theater-msa --context=$context --ignore-not-found=true
        kubectl delete clusterrolebindings api-gateway-cluster-access --context=$context --ignore-not-found=true
        kubectl delete clusterroles api-gateway-cluster-role --context=$context --ignore-not-found=true
    fi
    
    # Pod 강제 종료 대기
    log_info "Pod 종료 대기 중..."
    kubectl wait --for=delete pods --all -n theater-msa --context=$context --timeout=60s >/dev/null 2>&1 || true
    
    # 네임스페이스 삭제
    log_info "네임스페이스 theater-msa 삭제 중..."
    kubectl delete namespace theater-msa --context=$context --ignore-not-found=true
    
    # 삭제 완료 확인
    log_info "삭제 완료 확인 중..."
    sleep 3
    
    if namespace_exists $context; then
        log_warning "네임스페이스가 아직 삭제되지 않았습니다. (Finalizer 처리 중일 수 있음)"
    else
        log_success "컨텍스트 $context에서 모든 리소스 삭제 완료!"
    fi
}

# 컨텍스트 존재 확인
check_context_exists() {
    local context=$1
    if ! kubectl config get-contexts $context >/dev/null 2>&1; then
        log_warning "$context 컨텍스트를 찾을 수 없습니다."
        return 1
    fi
    return 0
}

# 모든 클러스터에서 삭제
cleanup_all_clusters() {
    log_info "=== 모든 클러스터에서 삭제 (ctx1, ctx2) ==="
    
    local ctx1_exists=false
    local ctx2_exists=false
    
    # 컨텍스트 존재 확인
    if check_context_exists "ctx1"; then
        ctx1_exists=true
    fi
    
    if check_context_exists "ctx2"; then
        ctx2_exists=true
    fi
    
    if [ "$ctx1_exists" = false ] && [ "$ctx2_exists" = false ]; then
        log_error "ctx1, ctx2 컨텍스트를 모두 찾을 수 없습니다."
        log_info "다음 명령어로 컨텍스트를 설정하세요:"
        echo "  kubectl config rename-context <your-ctx1-context> ctx1"
        echo "  kubectl config rename-context <your-ctx2-context> ctx2"
        exit 1
    fi
    
    # 전체 삭제 확인
    echo
    log_warning "양쪽 클러스터(CTX1, CTX2)에서 Theater MSA 리소스를 모두 삭제합니다."
    log_warning "이 작업은 되돌릴 수 없습니다!"
    read -p "정말로 계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "삭제가 취소되었습니다."
        exit 0
    fi
    
    # CTX1에서 삭제
    if [ "$ctx1_exists" = true ]; then
        echo
        log_info "--- CTX1 클러스터 삭제 시작 ---"
        cleanup_context "ctx1"
        log_success "CTX1 삭제 완료"
    fi
    
    # CTX2에서 삭제
    if [ "$ctx2_exists" = true ]; then
        echo
        log_info "--- CTX2 클러스터 삭제 시작 ---"
        cleanup_context "ctx2"
        log_success "CTX2 삭제 완료"
    fi
    
    echo
    log_success "=== 모든 클러스터 삭제 완료 ==="
}

# 메인 함수
main() {
    log_info "Theater MSA 샘플 배포 일괄 삭제 스크립트"
    echo "================================================="
    
    # 파라미터 확인
    case "$1" in
        "--all"|"")
            # 기본값: 모든 클러스터에서 삭제
            log_info "모든 클러스터에서 삭제 (ctx1, ctx2)"
            cleanup_all_clusters
            ;;
        "--ctx1")
            log_info "CTX1 클러스터에서만 삭제"
            if check_context_exists "ctx1"; then
                cleanup_context "ctx1"
            else
                exit 1
            fi
            ;;
        "--ctx2")
            log_info "CTX2 클러스터에서만 삭제"
            if check_context_exists "ctx2"; then
                cleanup_context "ctx2"
            else
                exit 1
            fi
            ;;
        "--current")
            # 현재 컨텍스트에서만 삭제
            local current_context=$(get_current_context)
            log_info "현재 컨텍스트에서 삭제: $current_context"
            
            if [ "$current_context" = "unknown" ]; then
                log_error "kubectl 컨텍스트를 확인할 수 없습니다."
                exit 1
            fi
            
            cleanup_context "$current_context"
            ;;
        "--help"|"-h")
            echo "사용법: $0 [옵션]"
            echo
            echo "옵션:"
            echo "  --all      모든 클러스터(ctx1, ctx2)에서 삭제 (기본값)"
            echo "  --ctx1     CTX1 클러스터에서만 삭제"
            echo "  --ctx2     CTX2 클러스터에서만 삭제"
            echo "  --current  현재 컨텍스트에서만 삭제"
            echo "  --help     이 도움말 표시"
            echo
            echo "예시:"
            echo "  $0                # 모든 클러스터에서 삭제"
            echo "  $0 --all          # 모든 클러스터에서 삭제"
            echo "  $0 --ctx1         # CTX1에서만 삭제"
            echo "  $0 --ctx2         # CTX2에서만 삭제"
            echo "  $0 --current      # 현재 컨텍스트에서만 삭제"
            exit 0
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "사용법: $0 [--all|--ctx1|--ctx2|--current|--help]"
            exit 1
            ;;
    esac
    
    echo
    log_success "=== 삭제 작업 완료 ==="
    log_info "남은 리소스 확인을 위해 다음 명령어를 실행하세요:"
    echo "  # CTX1 확인"
    echo "  kubectl get all,vs,dr -n theater-msa --context=ctx1"
    echo "  kubectl get vs -n istio-system theater-msa --context=ctx1"
    echo
    echo "  # CTX2 확인"
    echo "  kubectl get all,vs,dr -n theater-msa --context=ctx2"
    echo
    echo "  # 네임스페이스 확인"
    echo "  kubectl get namespace theater-msa --context=ctx1"
    echo "  kubectl get namespace theater-msa --context=ctx2"
}

# 스크립트 실행
main "$@"