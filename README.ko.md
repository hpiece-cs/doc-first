# doc-first — 코드보다 문서가 먼저 닿는 워크플로우

> [English](README.md) · [한국어](README.ko.md)

문서 우선(Document-First) 구현 단계 규칙을 다중 AI CLI 환경에 적용하는 스킬. 코드 수정·구현·리팩토링 요청이 들어와도 즉시 소스를 건드리지 않고, `docs/src-notes/`에 사전 구현 문서를 먼저 작성·리뷰한 뒤에만 코드 작업을 진행하도록 강제합니다.

## 왜 필요한가

AI CLI(Claude Code, Codex, Copilot, Gemini, OpenCode 등)는 프롬프트 한 줄에 즉시 코드를 수정할 수 있다는 점이 강점이지만, 동시에 **가장 큰 위험원**이기도 합니다. "이 함수 좀 바꿔줘" 한 마디에 AI가 내부 추론을 거쳐 곧바로 파일을 편집해 버리면, 다음 문제들이 누적됩니다.

- **의도와 결과의 어긋남** — AI가 머릿속에서 정한 범위와 사용자가 기대한 범위가 일치하는지 검증할 기회가 없습니다.
- **암묵 결정의 코드화** — 시그니처 변경, 분기 추가 같은 결정이 리뷰 없이 코드에 박힙니다.
- **문서·구현의 영구적 디싱크** — 한 번 어긋난 뒤로는 어떤 문서도 신뢰할 수 없게 됩니다.
- **휘발성 컨텍스트 의존** — 다음 세션은 코드만 보고 "왜 이렇게 짰는지"를 영원히 알 수 없습니다.

doc-first는 이 패턴을 정면으로 차단합니다. **모든 코드 편집 요청에 대해, 코드보다 먼저 문서가 갱신되고 사용자 확인을 통과해야만** 실제 편집이 시작됩니다.

## doc-first만의 특징

다른 plan-first·spec-first 도구들과 결정적으로 구분되는 네 가지 설계 결정.

### 1. 모든 코드 편집이 트리거 — 입자도(granularity)가 가장 작다

`writing-plans`·BMAD·GSD 같은 메서드론은 **phase / story / feature** 단위에서 작동합니다. 즉 큰 작업에는 강력하지만, "이 함수 한 줄만 고쳐" 같은 작은 요청은 그물을 빠져나갑니다. 작은 변경의 누적이야말로 코드베이스가 망가지는 주된 경로입니다.

doc-first는 분량·긴급성과 무관하게 **편집이 발생할 가능성이 있는 모든 프롬프트**에 4단계 절차를 강제합니다. "한 줄짜리니까 생략" 같은 합리화는 Red Flag로 분류되어 바로 차단됩니다.

### 2. 4단계 미러링 + 경로 평탄화로 소스↔문서 1:1 매핑

```
src/services/auth/login.ts                   →  docs/src-notes/src/services/auth/login.ts.md
src/services/auth/oauth/google.ts            →  docs/src-notes/src/services/auth/oauth/google.ts.md
src/services/auth/oauth/providers/github.ts  →  docs/src-notes/src/services/auth/oauth/providers__github.ts.md
```

`docs/src-notes/` 아래 디렉토리 깊이를 기준으로 **4단계 폴더까지는 실제 디렉토리로 유지**하고, 5단계부터는 `/`를 `__`로 치환해 평탄화합니다. 문서가 한 폴더에 평면으로 쌓이지 않으면서도, 소스 경로 하나에 문서 경로 하나가 기계적으로 대응합니다.

이 매핑이 결정론적이려면 **문서화 대상 소스 루트가 명시**되어 있어야 합니다. doc-first는 `docs/src-notes/INDEX.md` 상단에 `src/`·`lib/`·`app/` 또는 `packages/<pkg>/src/` 같은 소스 루트 목록을 적고, 각 루트 안에서 동일한 규칙을 적용하도록 요구합니다.

이 규약은 단순한 네이밍 규칙처럼 보이지만, 실제로는 **문서 발견 가능성(discoverability)을 결정론적으로 만드는 장치**입니다.

- AI는 어떤 파일을 수정하든 대응 문서 위치를 추론 없이 즉시 알 수 있습니다.
- 문서가 없다는 사실 자체가 "사전 문서가 누락되었다"는 신호가 됩니다.
- grep 한 번으로 전체 소스 트리에 대한 문서 커버리지를 확인할 수 있습니다.

다른 도구들의 자유 형식 plan 파일과 다르게, doc-first의 문서 트리는 **소스 트리의 구조적 거울**입니다.

더불어 `docs/src-notes/INDEX.md`가 프로젝트 전체 소스 파일과 대응 문서를 단일 표로 정리해, AI/사람 모두 한 번의 조회로 전체 커버리지를 파악할 수 있습니다.

### 3. 4층 docs 구조 — 역할이 절대 겹치지 않는다

| 디렉토리 | 역할 |
|---|---|
| `docs/spec-notes/` | 표준·가이드·공통 자산 (불변에 가까운 기준) |
| `docs/src-notes/` | 폴더·파일 단위 사전 구현 문서 (코드와 동기화) |
| `docs/flow-notes/` | 흐름·구조·아키텍처 (관점 전용) |
| `docs/test-notes/` | 단계·회차별 테스트 (시간축 기록) |

각 디렉토리는 명시적으로 **역할 중복 금지** 원칙을 따릅니다. "공통 자산이면 인라인 복사 금지, 링크로만 참조" 같은 규칙이 강제되므로, 동일 정보가 여러 문서에 흩어져 진실 공방이 일어나는 일을 구조적으로 차단합니다.

### 4. 승인 범위 한정 + 즉시 중단·재승인

대부분의 plan-first 도구는 "계획 따로, 실행 따로"라 실행 도중 범위가 늘어나도 알아차리기 어렵습니다. doc-first는 구현 중에도 다음을 감시합니다.

- 문서에 없는 파일·폴더의 신규 생성·수정
- 함수·변수 시그니처 변경
- 분기·제어 흐름의 추가·삭제·변경
- 외부 의존성·`spec-notes`·`flow-notes`에 영향 가는 변경

하나라도 발생하면 **즉시 중단 → 문서 갱신 → 재확인 → 재개**. "조금만 더 손대면 깔끔해지니까 같이 고치자"는 흔한 함정을 명시적으로 막습니다.

## 비교 — 비슷해 보이지만 다른 도구들

| 도구 | 작동 단위 | 산출물의 영속성 | 소스↔문서 매핑 | 모든 코드 편집 차단 |
|---|---|---|---|---|
| **doc-first** | 파일·폴더 | 영속 (코드와 동기화) | 결정론적 1:1 | ✅ |
| superpowers:writing-plans | 작업 (multi-step) | 일회성 plan 파일 | 없음 | ❌ |
| GSD plan-phase | phase | phase 종료 후 archive | 느슨함 | ❌ |
| BMAD create-prd 등 | 제품·스토리 | 영속 (상위 레벨) | 없음 | ❌ |
| TDD | 함수·기능 | 테스트 코드 | 테스트 코드 자체가 매핑 | ❌ |

doc-first는 **가장 작은 입자도에서 가장 강한 강제력을 가집니다.** 다른 도구들과 경쟁하는 게 아니라, 이들이 커버하지 않는 층위를 보강합니다.

## 어떤 팀·작업에 유효한가

**유효한 상황**
- 다인 협업 또는 AI 에이전트와의 장기 협업 — 휘발성 컨텍스트 의존을 끊고 싶을 때
- 핵심 비즈니스 로직·인증·결제·데이터 정합성 코드 — 작은 수정이 큰 사고로 이어지는 영역
- 브라운필드 코드베이스 — "왜 이렇게 짰는지" 추적이 항상 부족한 환경
- 다중 AI CLI를 병행 사용 — 도구별로 일관된 절차가 필요할 때

**부적합한 상황**
- 일회성 스크립트, 학습용 코드, 프로토타입 폐기 예정 코드
- 읽기·탐색·순수 문서 작업 (skill description의 SKIP 조건에 해당)

## 한 줄 요약

> **AI에게 "코드를 고쳐달라"가 아니라 "고치기 전에 문서부터 갱신하고 보여달라"고 시키는 일을, 매번 사람이 입력하지 않아도 되도록 만든 스킬.**

## 핵심 원칙 (요약)

1. **문서 우선** — 4단계 절차: 범위 정리 → `docs/src-notes/` 선반영 → 사용자 확인 → 리뷰 후 구현
2. **승인 범위 한정** — 리뷰에서 승인된 범위만 구현. 이탈 시 즉시 중단·재승인·재개

자세한 규칙은 [`dist/SKILL.md`](dist/SKILL.md) 참고. 한국어 원본은 개발 저장소의 `core/SKILL.md`에 있습니다.

## 지원 플랫폼

| 플랫폼 | 설치 경로 | 상태 |
|---|---|---|
| Claude Code | `~/.claude/skills/doc-first/SKILL.md` | ✅ 지원 |
| Codex CLI | `${CODEX_HOME:-~/.codex}/skills/doc-first/SKILL.md` | ✅ 지원 |
| Copilot CLI | `~/.copilot/skills/doc-first/SKILL.md` | ✅ 지원 |
| Gemini CLI | `~/.gemini/extensions/doc-first/` (extension 패키지) | ✅ 지원 |
| OpenCode | `~/.config/opencode/skills/doc-first/SKILL.md` + `/doc-first` command | ✅ 지원 |

## 설치

플랫폼에 맞는 방법을 **하나만** 고릅니다. 같은 플랫폼에 두 방법을 겹쳐 적용하면 Claude Code에서는 게이트 훅이 두 번 등록되어 거부 메시지가 중복 출력됩니다.

| 플랫폼 | 권장 설치 방법 |
|---|---|
| Claude Code | 플러그인 (`/plugin marketplace add`) — 스킬과 게이트 훅이 함께 등록 |
| Gemini CLI | 저장소를 받아 `./install.sh --target=gemini` — 스킬과 게이트 훅이 함께 등록. 확장(`gemini extensions install`)은 스킬만 설치 |
| Codex CLI, Copilot CLI, OpenCode | 저장소를 받아 `./install.sh` |

### Claude Code: 플러그인으로 설치

```
/plugin marketplace add hpiece-cs/doc-first
/plugin install doc-first@doc-first
```

이 저장소 자체가 마켓플레이스이자 플러그인입니다. 스킬, PreToolUse 게이트 훅, SessionStart 훅(커밋 검사 자동 설치)이 플러그인 범위에서 함께 등록되며 `~/.claude/settings.json`은 건드리지 않습니다.

```
claude plugin update doc-first@doc-first    # 업데이트 (재시작 후 적용)
/plugin uninstall doc-first@doc-first       # 제거
```

### Gemini CLI: 확장으로 설치

```
gemini extensions install https://github.com/hpiece-cs/doc-first
```

저장소 루트의 `gemini-extension.json`과 `GEMINI.md`, `skills/doc-first/`가 확장으로 인식됩니다. 업데이트는 `gemini extensions update doc-first`, 제거는 `gemini extensions uninstall doc-first`입니다. 이 방법은 스킬 본문만 설치하며 [편집 게이트](#편집-게이트-승인-전-코드-편집-차단)는 등록하지 않습니다. 게이트까지 쓰려면 아래의 `./install.sh --target=gemini`를 대신 사용합니다.

### 모든 플랫폼: 저장소를 받아 install.sh 실행

```bash
git clone https://github.com/hpiece-cs/doc-first.git
cd doc-first
./install.sh
```

인자 없이 실행하면 홈 디렉토리에서 `~/.claude/skills`, `${CODEX_HOME:-~/.codex}/skills`, `~/.copilot/skills`, `~/.gemini/extensions`, `~/.config/opencode` 중 **존재하는 모든 플랫폼**을 감지하여 설치합니다. 업데이트는 `git pull` 후 `./install.sh`를 다시 실행합니다.

#### 특정 플랫폼만 설치

```bash
./install.sh --target=claude-code
./install.sh --target=codex
./install.sh --target=copilot
./install.sh --target=gemini
./install.sh --target=opencode
```

#### 모든 플랫폼에 설치

```bash
./install.sh --target=all
```

#### 미리보기 (dry run)

```bash
./install.sh --dry-run
./install.sh --target=claude-code --dry-run
```

#### 제거

```bash
./install.sh --uninstall
./install.sh --uninstall --target=copilot
./install.sh --uninstall --target=opencode
```

#### 플랫폼별 설치 동작

- `claude-code`, `codex`, `copilot` — SKILL.md를 평면 구조(`<dest>/SKILL.md`)로 복사하고 조건부 상세 참조를 `<dest>/references/`로 함께 복사
- 모든 대상 — 편집 게이트와 커밋 검사 도구를 `~/.local/share/doc-first/bin/`에 복사하고, 대상마다 게이트 훅을 등록 ([편집 게이트](#편집-게이트-승인-전-코드-편집-차단), [커밋 검사](#커밋-검사-문서-현행화) 참고)
- `claude-code` — 게이트 훅(PreToolUse Write|Edit)과 SessionStart 훅을 `~/.claude/settings.json`에 등록 (`jq` 필요, 없으면 훅만 생략)
- `gemini` — `gemini-extension.json`·`GEMINI.md` + SKILL.md를 extension 패키지 구조(`<dest>/skills/doc-first/SKILL.md`)로 배치하고 references도 함께 복사
- `opencode` — SKILL.md를 `~/.config/opencode/skills/doc-first/SKILL.md`로 복사하고, references와 수동 호출용 `/doc-first` command를 함께 배치

## 동작 방식

1. 각 플랫폼의 스킬 디스커버리는 SKILL.md 상단의 YAML frontmatter (`name`, `description`)를 읽어 시스템 프롬프트에 메타데이터로 로드
2. 사용자가 코드 수정·구현 요청을 보내면 description의 트리거 키워드와 매칭되어 본문이 활성화
3. 활성화 후엔 4단계 절차에 따라 `docs/src-notes/` 선반영 → 사용자 확인 → 코드 작업

OpenCode는 native skill tool로 `doc-first`를 필요 시 로드할 수 있으며, 명시 호출이 필요할 때는 `/doc-first <요청>` command를 사용할 수 있습니다.

읽기·탐색·문서 전용 작업에는 트리거되지 않습니다 (description의 SKIP 조건).

## 편집 게이트 (승인 전 코드 편집 차단)

스킬 본문과 함께 편집 게이트가 설치되어, doc-first 절차가 완료되지 않은 세션에서 AI 도구가 소스 파일을 고치려 하면 그 직전에 차단하고 절차를 안내합니다. 게이트는 현재 작업 디렉토리에서 상위로 올라가며 `docs/src-notes/`를 가진 첫 디렉토리를 doc-first 프로젝트로 판정하므로, 그 폴더가 없는 프로젝트에서는 아무 동작도 하지 않습니다. 문서·테스트·설정 파일은 게이트 대상이 아닙니다. 절차 완료 후 게이트가 안내하는 sentinel 파일을 생성하면 해당 세션 동안 게이트가 해제됩니다.

다섯 도구가 같은 게이트 스크립트(`~/.local/share/doc-first/bin/pre-tool-use.sh`)를 쓰므로 판정 규칙이 같습니다. 도구마다 등록 위치만 다릅니다.

| 도구 | 가로채는 편집 동작 | 등록 위치 |
|---|---|---|
| Claude Code | `Write`, `Edit` | `~/.claude/settings.json` (플러그인은 `hooks/hooks.json`) |
| Gemini CLI | `write_file`, `replace` | `~/.gemini/settings.json` |
| Copilot CLI | `create`, `edit`, `str_replace_editor`, `apply_patch` | `~/.copilot/hooks/doc-first.json` |
| Codex CLI | `apply_patch` | `~/.codex/hooks.json` |
| OpenCode | `write`, `edit`, `apply_patch` | `~/.config/opencode/plugins/doc-first-gate.js` |

- 게이트는 `jq`가 필요합니다. 없으면 게이트만 꺼지고 도구는 정상 동작합니다
- Codex CLI는 `apply_patch`에 대한 훅 거부가 무시되는 상류 버그([openai/codex#27833](https://github.com/openai/codex/issues/27833))가 열려 있습니다. 훅은 등록되지만 버그가 닫히기 전까지는 실제로 막지 못합니다
- 셸 명령(`sed -i`, 리다이렉션 등)으로 파일을 고치는 경우는 어느 도구에서도 막지 못합니다. 편집 도구 호출만 가로챕니다
- 이전 버전에서 설치한 경우 `git pull` 후 `./install.sh`를 다시 실행하면 게이트가 새 위치로 옮겨지고 다른 도구에도 등록됩니다

## 커밋 검사 (문서 현행화)

기존 소스를 고칠 때 doc-first 문서는 먼저 **수정 리뷰 형식**(변경 후 본문 + 🟢🟠🔴 표시)으로 바뀌고, 구현이 끝나면 표시를 지워 최신 설명서로 돌아가야 합니다. 커밋 검사는 이 마지막 단계를 빠뜨리지 않게 합니다.

- 소스를 커밋할 때, 그 소스의 문서(`docs/src-notes/INDEX.md` 기준)에 수정 리뷰 표시가 남아 있으면 **커밋이 중단**되고 정리 명령이 안내됩니다
- 정리: `~/.local/share/doc-first/bin/review-clean.sh <문서>` → `git add <문서>` → 다시 커밋
- 구현 도중의 중간 커밋은 커밋 메시지에 `[wip]`를 넣으면 경고만 하고 통과합니다
- git 훅으로 동작하므로 터미널, IDE, Git GUI 등 어떤 프로그램으로 커밋해도 같습니다

### 저장소에 커밋 검사 켜기

| 사용 환경 | 방법 |
|---|---|
| Claude Code | 자동. doc-first 저장소에서 세션을 시작하면 설치됩니다 |
| Codex, Copilot, Gemini CLI, OpenCode, AI 없이 작업 | 설치 후 한 번 `./install.sh --git-hooks=<저장소들이 있는 폴더>` 실행. doc-first 저장소를 새로 받으면 다시 실행 |
| Gemini CLI 확장으로 설치한 경우 | `~/.gemini/extensions/doc-first/install.sh --git-hooks=<폴더>` |

```bash
./install.sh --git-hooks=~/Work               # ~/Work 아래 doc-first 저장소에 설치
./install.sh --git-hooks=~/Work --uninstall   # 제거 (기존 commit-msg 훅은 복원)
```

- 이미 `commit-msg` 훅이 있으면 지우지 않고 먼저 실행되도록 이어 붙입니다
- husky처럼 `core.hooksPath`를 쓰는 저장소는 자동으로 고치지 않고, 그 훅에 넣을 한 줄을 안내합니다
- 전역 git 설정은 바꾸지 않습니다. doc-first가 아닌 저장소에는 영향이 없습니다
- `perl`이 필요합니다(macOS·Linux·Git for Windows 기본 포함)

### 한계

커밋 검사는 **각 PC의 git 훅**으로만 동작합니다. 다음 경우는 막지 못합니다.

- `git commit --no-verify`로 훅을 건너뛴 커밋
- 커밋 검사 훅이 설치되지 않은 PC·저장소에서 한 커밋
- 서버 쪽 검사(푸시 거절, CI)는 제공하지 않습니다

## 라이선스

MIT
