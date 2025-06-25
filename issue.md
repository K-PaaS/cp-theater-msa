# K-PaaS Theater MSA 샘플 - Issue 해결 기록

## Issue #1: Harbor Registry 인증서 문제로 인한 ImagePullBackOff

### 발생 일시
2025-06-22 07:00 ~ 08:00 (KST)

### 문제 상황
CTX1 클러스터에서 Movie Service deployment만 ImagePullBackOff 오류가 지속적으로 발생하여 Pod가 Running 상태로 전환되지 않음.

### 오류 메시지
```
Failed to pull image "harbor.27.96.156.180.nip.io/theater-msa/movie-service:latest": 
failed to pull and unpack image: failed to resolve reference: failed to do request: 
Head "https://harbor.27.96.156.180.nip.io/v2/theater-msa/movie-service/manifests/latest": 
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

### 증상 분석
1. **User Service**: `suslmk-node-w-3f53` 노드에서 정상 실행 ✅
2. **Movie Service**: `suslmk-node-w-77b1` 노드에서 x509 인증서 오류 ❌
3. **Booking Service**: `suslmk-node-w-3f53` 노드에서 정상 실행 ✅
4. **동일한 Harbor 이미지**를 사용하는데도 노드별로 다른 결과

### 원인 분석

#### 1. Harbor Registry 설정
- Harbor는 public repository이지만 **HTTPS 연결** 사용
- **Self-signed 인증서** 또는 **사설 CA**로 서명된 인증서 사용
- Public repo ≠ 신뢰할 수 있는 TLS 인증서

#### 2. 노드별 인증서 설정 차이
- **정상 노드들** (`suslmk-node-w-3f51`, `suslmk-node-w-3f52`, `suslmk-node-w-3f53`): Harbor CA 인증서 설치됨
- **문제 노드** (`suslmk-node-w-77b1`): **추가된 노드로 Harbor CA 인증서 미설치**

#### 3. 클러스터 배포 과정
- 클러스터 초기 배포시 각 노드에 Harbor CA 인증서를 수동으로 추가
- `suslmk-node-w-77b1`은 나중에 추가된 노드로 이 과정이 누락됨

### 해결 과정

#### 1단계: 문제 노드 식별
```bash
kubectl describe pod movie-service-ctx1-xxx -n theater-msa --context=ctx1
# Node: suslmk-node-w-77b1 에서 x509 오류 확인
```

#### 2단계: 노드 상태 확인
```bash
kubectl get nodes --context=ctx1
# suslmk-node-w-77b1 노드가 NotReady 상태로 확인
```

#### 3단계: 문제 노드 제거 후 재배포
```bash
# 사용자가 문제 노드 중단
kubectl delete deployment movie-service-ctx1 -n theater-msa --context=ctx1
kubectl apply -f movie-service-ctx1.yaml --context=ctx1
```

#### 4단계: 정상 노드에서 재스케줄링 확인
```bash
kubectl get pods -n theater-msa --context=ctx1 -o wide
# movie-service-ctx1-xxx 가 suslmk-node-w-3f53 노드에서 Running 상태 확인
```

### 최종 해결 결과
✅ 모든 CTX1 서비스가 정상 실행됨:
- API Gateway: 2/2 Running (`suslmk-node-w-3f51`)
- User Service CTX1: 2/2 Running (`suslmk-node-w-3f53`)
- Movie Service CTX1: 2/2 Running (`suslmk-node-w-3f53`)
- Booking Service CTX1: 2/2 Running (`suslmk-node-w-3f53`)
- Redis Proxy: 2/2 Running (`suslmk-node-w-3f53`)

### 예방 대책

#### 1. 새 노드 추가시 체크리스트
- [ ] Harbor CA 인증서 설치 확인
- [ ] Insecure registry 설정 확인 (필요시)
- [ ] Harbor registry 연결 테스트
- [ ] 샘플 이미지 풀 테스트

#### 2. 자동화 개선 방안
```bash
# Harbor CA 인증서 자동 설치 스크립트 예시
#!/bin/bash
# 새 노드에 Harbor CA 인증서 설치
scp harbor-ca.crt root@$NEW_NODE:/etc/docker/certs.d/harbor.27.96.156.180.nip.io/
systemctl restart docker
```

#### 3. 노드 라벨링 개선
```yaml
# deployment yaml에 nodeSelector 추가 권장
spec:
  template:
    spec:
      nodeSelector:
        cluster-name: ctx1
        harbor-certified: "true"  # Harbor 인증서 설치된 노드만 선택
```

#### 4. 모니터링 개선
- Harbor registry 연결 상태 모니터링
- 노드별 이미지 풀 성공률 추적
- 새 노드 추가시 알림 및 검증 프로세스

### 관련 파일
- `/Users/suslmk/workspace/msa-sample-smov/k8s/movie-service-ctx1.yaml`
- Harbor Registry: `harbor.27.96.156.180.nip.io`

### 참고 명령어
```bash
# Harbor 연결 테스트
curl -I https://harbor.27.96.156.180.nip.io/v2/

# 노드별 이미지 풀 테스트
kubectl run test-image --image=harbor.27.96.156.180.nip.io/theater-msa/user-service:latest --rm -it --restart=Never

# 인증서 확인
openssl s_client -connect harbor.27.96.156.180.nip.io:443 -servername harbor.27.96.156.180.nip.io
```

---

**작성자**: Claude Code Assistant  
**해결 완료**: 2025-06-22 08:00 (KST)  
**상태**: ✅ 해결됨