# Practice 폴더 - Self-contained Fault Injection 시나리오

## 개요
이 디렉토리는 K-PaaS Theater MSA 샘플의 Fault Injection 교육 시나리오들을 포함합니다. 각 시나리오는 **Self-contained** 구조로 설계되어 외부 의존성 없이 독립적으로 실행 가능합니다.

## 🎯 Self-contained 아키텍처의 장점

### 1. **완전한 독립성**
- 각 시나리오 디렉토리가 실행에 필요한 모든 파일 포함
- 외부 파일 참조나 path dependency 없음
- 다른 환경으로 복사하여 즉시 실행 가능

### 2. **예측 가능한 동작**
- DestinationRule 충돌 완전 해결
- 시나리오 적용 전 기존 리소스 자동 정리
- 100% 일관된 실행 결과 보장

### 3. **교육 효과 극대화**
- 각 시나리오를 독립적 학습 모듈로 활용
- 단계별 진행 및 개별 검증 가능
- 실무 패턴과 동일한 구조로 실용성 확보

## 📁 시나리오 구조

```
practice/
├── 01-initial/               # ✅ 기본 설정 (Round Robin + 기본 트래픽)
│   ├── destinationrules.yaml     # 기본 Round Robin 로드밸런싱
│   ├── virtualservices.yaml      # 기본 트래픽 분산 (70:30, 30:70, 50:50)
│   └── kustomization.yaml        # 통합 배포 설정
├── 02-circuit-breaker/       # ✅ Circuit Breaker (완전 독립)
│   ├── destinationrules.yaml     # Circuit Breaker 정책
│   ├── virtualservices.yaml      # 기본 트래픽 분산 (로컬 복사본)
│   └── kustomization.yaml        # Self-contained 구성
├── 03-delay-fault/          # ✅ 지연 장애 (완전 독립)
│   ├── destinationrules.yaml     # Circuit Breaker 포함
│   ├── virtualservices.yaml      # Movie Service 3초 지연
│   └── kustomization.yaml        # 완전 독립적 구성
├── 04-error-fault/          # ✅ 오류 장애 (완전 독립)
│   ├── destinationrules.yaml     # Circuit Breaker 포함
│   ├── virtualservices.yaml      # User Service 30% HTTP 500 오류
│   └── kustomization.yaml        # 완전 독립적 구성
├── 05-block-fault/          # ✅ 차단 장애 (완전 독립)
│   ├── destinationrules.yaml     # Circuit Breaker 포함
│   ├── virtualservices.yaml      # Booking Service CTX2 차단
│   └── kustomization.yaml        # 완전 독립적 구성
├── 99-scenarios/            # ✅ 복합 장애 (완전 독립)
│   ├── destinationrules.yaml     # Circuit Breaker 포함
│   ├── multi-service-fault.yaml  # 모든 서비스 동시 장애
│   └── kustomization.yaml        # 복합 장애 통합 구성
└── fault-injection-demo.sh  # 🛠️ 통합 관리 스크립트
```

## 🚀 사용법

### 기본 명령어
```bash
# 권한 설정 (최초 1회)
chmod +x fault-injection-demo.sh

# 도움말 확인
./fault-injection-demo.sh --help

# 환경 상태 확인
./fault-injection-demo.sh status
```

### 권장 학습 순서
```bash
# 1. 초기 상태로 복원 (기존 DR 정리 + 기본 설정 적용)
./fault-injection-demo.sh reset

# 2. Circuit Breaker 설정 적용
./fault-injection-demo.sh setup

# 3. 각 장애 시나리오 순차 실습
./fault-injection-demo.sh delay    # Movie Service 지연 장애
./fault-injection-demo.sh error    # User Service 오류 장애  
./fault-injection-demo.sh block    # Booking Service 차단 장애

# 4. 복합 장애 시나리오 (고급)
./fault-injection-demo.sh chaos    # 모든 서비스 동시 장애

# 5. 완전 복구
./fault-injection-demo.sh reset
```

### 개별 시나리오 직접 실행
```bash
# Self-contained 구조로 어디서든 실행 가능
kubectl apply -k 01-initial/        # 기본 설정
kubectl apply -k 02-circuit-breaker/ # Circuit Breaker
kubectl apply -k 03-delay-fault/    # 지연 장애
kubectl apply -k 04-error-fault/    # 오류 장애
kubectl apply -k 05-block-fault/    # 차단 장애
kubectl apply -k 99-scenarios/      # 복합 장애
```

## 🔧 핵심 개선사항

### 1. DestinationRule 충돌 해결
**Before (문제 상황):**
```bash
# 기존 deploy/ 디렉토리의 DR과 practice/ 시나리오 DR이 충돌
user-service-dr (deploy) + user-service-circuit-breaker (practice)
→ 동일한 subset 이름 (ctx1, ctx2) 사용
→ Istio 라우팅 혼란 및 예측 불가능한 동작
```

**After (해결됨):**
```bash
# 시나리오 적용 전 자동 정리
cleanup_existing_destinationrules() {
    # 기존 기본 DR 삭제
    # Circuit Breaker DR 삭제
    # 충돌 가능성 완전 제거
}
```

### 2. Self-contained 구조 구축
**Before (외부 의존성):**
```yaml
# practice/02-circuit-breaker/kustomization.yaml
resources:
- destinationrules.yaml
- ../01-initial/virtualservices.yaml  # 🚫 외부 파일 참조
```

**After (완전 독립):**
```yaml
# practice/02-circuit-breaker/kustomization.yaml
resources:
- destinationrules.yaml
- virtualservices.yaml  # ✅ 로컬 파일로 독립
```

### 3. 고급 관리 기능 추가
- **환경 검증**: 클러스터, 네임스페이스, 서비스 상태 사전 확인
- **시나리오별 롤백**: 개별 장애만 선택적 해제 가능
- **상태 모니터링**: 현재 적용된 설정 및 장애 상태 실시간 확인

## 📚 교육 시나리오별 세부 내용

### 01-initial: 기본 설정
- **목적**: Round Robin 로드밸런싱과 기본 트래픽 분산 이해
- **설정**: User(70:30), Movie(30:70), Booking(50:50)
- **학습 포인트**: Istio DestinationRule과 VirtualService 기본 개념

### 02-circuit-breaker: Circuit Breaker 교육
- **목적**: 자동 장애 격리 및 복구 메커니즘 학습
- **설정**: Connection Pool 제한, Outlier Detection 활성화
- **학습 포인트**: 연속 실패 감지 → 30초 격리 → 자동 복구 과정

### 03-delay-fault: 지연 장애 시뮬레이션
- **대상**: Movie Service CTX2
- **설정**: 70% 요청에 3초 지연 주입
- **학습 포인트**: 네트워크 지연, 데이터베이스 성능 저하 시나리오

### 04-error-fault: HTTP 오류 시뮬레이션  
- **대상**: User Service
- **설정**: 30% 확률 HTTP 500 오류, x-circuit-test 헤더로 90% 오류
- **학습 포인트**: 서비스 장애 상황 및 Circuit Breaker 트리거

### 05-block-fault: 클러스터 차단 시뮬레이션
- **대상**: Booking Service CTX2
- **설정**: 100% 트래픽을 CTX1으로 라우팅
- **학습 포인트**: 전체 클러스터 장애 시 트래픽 우회

### 99-scenarios: 복합 장애 (고급)
- **대상**: 모든 서비스
- **설정**: User(30% 오류) + Movie(지연) + Booking(차단) 동시 적용
- **학습 포인트**: 다중 서비스 장애 상황 및 시스템 회복력

## 🛡️ 안전 기능

### 1. 자동 충돌 방지
```bash
# 모든 시나리오 적용 전 자동 실행
cleanup_existing_destinationrules()
```

### 2. 환경 검증
```bash
# 실행 전 환경 상태 확인
validate_environment()
```

### 3. 롤백 기능
```bash
# 개별 시나리오 롤백
rollback_scenario("delay")
rollback_scenario("error")  
rollback_scenario("block")
```

### 4. 상태 모니터링
```bash
# 현재 설정 및 장애 상태 확인
./fault-injection-demo.sh status
```

## 🔍 문제 해결

### 일반적인 문제들
```bash
# 1. 시나리오 적용 실패
./fault-injection-demo.sh status  # 환경 상태 확인

# 2. DestinationRule 충돌
./fault-injection-demo.sh reset   # 완전 초기화

# 3. 네임스페이스 문제
kubectl get namespace theater-msa # 네임스페이스 존재 확인

# 4. 서비스 상태 확인
kubectl get pods -n theater-msa   # Pod 상태 확인
```

### 고급 디버깅
```bash
# Istio 설정 확인
kubectl get vs,dr -n theater-msa

# Envoy 프록시 설정 확인  
istioctl proxy-config cluster deployment/user-service.theater-msa

# 트래픽 분산 실시간 확인
kubectl get vs -n theater-msa -o yaml | grep -A 10 weight
```